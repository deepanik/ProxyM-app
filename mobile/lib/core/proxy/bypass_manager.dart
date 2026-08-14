import '../../models/bypass_rule.dart';

class BypassManager {
  final List<BypassRule> _rules;

  BypassManager(this._rules);

  bool shouldBypass(String host) {
    if (host.isEmpty) return false;

    for (final rule in _rules) {
      if (_matchesRule(host, rule)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesRule(String targetHost, BypassRule rule) {
    final pattern = rule.pattern.trim().toLowerCase();
    final host = targetHost.trim().toLowerCase();

    switch (rule.type) {
      case BypassType.local:
        return host == 'localhost' ||
            host == '127.0.0.1' ||
            host == '::1' ||
            host.startsWith('192.168.') ||
            host.startsWith('10.') ||
            host.startsWith('172.16.');

      case BypassType.hostname:
        return host == pattern;

      case BypassType.wildcard:
        final prefix = pattern.replaceAll('*', '');
        return host.endsWith(prefix);

      case BypassType.ip:
        return host == pattern;

      case BypassType.cidr:
        return _matchCidr(host, pattern);
    }
  }

  bool _matchCidr(String host, String cidrPattern) {
    try {
      final parts = cidrPattern.split('/');
      if (parts.length != 2) return false;
      final cidrIp = parts[0];
      final prefixLen = int.tryParse(parts[1]) ?? 24;

      if (!host.contains('.')) return false; // Simple IPv4 check

      final hostIpNum = _ipToInt(host);
      final cidrIpNum = _ipToInt(cidrIp);
      final mask = (0xFFFFFFFF << (32 - prefixLen)) & 0xFFFFFFFF;

      return (hostIpNum & mask) == (cidrIpNum & mask);
    } catch (_) {
      return false;
    }
  }

  int _ipToInt(String ip) {
    final octets = ip.split('.').map(int.parse).toList();
    return (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
  }
}
