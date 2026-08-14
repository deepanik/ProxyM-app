import '../models/bypass_rule.dart';

final _cidrRegex = RegExp(r'^[\d.]+/\d{1,2}$');
final _ipRegex = RegExp(r'^[\d.]+$');

/// Detect the type of a bypass pattern.
BypassType detectBypassType(String pattern) {
  if (pattern == '<local>') return BypassType.local;
  if (pattern.startsWith('*.')) return BypassType.wildcard;
  if (_cidrRegex.hasMatch(pattern)) return BypassType.cidr;
  if (_ipRegex.hasMatch(pattern)) return BypassType.ip;
  return BypassType.hostname;
}

/// Validate a bypass rule pattern. Returns null if valid, error message if invalid.
String? validateBypassRule(String pattern) {
  final trimmed = pattern.trim();
  if (trimmed.isEmpty) return 'Pattern cannot be empty';
  if (trimmed.contains(' ')) return 'Pattern cannot contain spaces';
  if (trimmed == '<local>') return null; // valid

  final type = detectBypassType(trimmed);

  switch (type) {
    case BypassType.wildcard:
      // Must be *.something
      if (trimmed.length <= 2) return 'Wildcard pattern too short';
      final domain = trimmed.substring(2);
      if (domain.isEmpty || domain.startsWith('.')) return 'Invalid wildcard pattern';
      break;
    case BypassType.cidr:
      final parts = trimmed.split('/');
      final mask = int.tryParse(parts[1]);
      if (mask == null || mask < 0 || mask > 32) return 'CIDR mask must be 0-32';
      final octets = parts[0].split('.');
      if (octets.length != 4) return 'Invalid IP in CIDR';
      for (final o in octets) {
        final n = int.tryParse(o);
        if (n == null || n < 0 || n > 255) return 'Invalid octet: $o';
      }
      break;
    case BypassType.ip:
      final octets = trimmed.split('.');
      if (octets.length != 4) return 'IP must have 4 octets';
      for (final o in octets) {
        final n = int.tryParse(o);
        if (n == null || n < 0 || n > 255) return 'Invalid octet: $o';
      }
      break;
    case BypassType.hostname:
    case BypassType.local:
      break;
  }
  return null;
}

/// Generate a unique ID for a bypass rule.
String generateBypassId() =>
    'bypass_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 10000)}';
