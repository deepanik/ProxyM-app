import '../models/proxy_entry.dart';

class BulkParseResult {
  final List<ProxyEntry> proxies;
  final List<String> errors;

  const BulkParseResult({required this.proxies, required this.errors});
}

class ParseProxyOptions {
  final String defaultProtocol;
  const ParseProxyOptions({this.defaultProtocol = 'http'});
}

String generateProxyId() =>
    'proxy_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 10000)}';

ProxyProtocol _parseProtocol(String scheme) {
  final s = scheme.toLowerCase().replaceAll(':', '');
  switch (s) {
    case 'https':
      return ProxyProtocol.https;
    case 'socks4':
      return ProxyProtocol.socks4;
    case 'socks5':
      return ProxyProtocol.socks5;
    case 'http':
    default:
      return ProxyProtocol.http;
  }
}

int _parsePort(String portStr) {
  final port = int.tryParse(portStr);
  if (port == null || port < 1 || port > 65535) {
    throw FormatException('Port must be between 1 and 65535 (got "$portStr")');
  }
  return port;
}

String _decodeAuth(String val) {
  try {
    return Uri.decodeComponent(val);
  } catch (_) {
    return val;
  }
}

/// 1. Parse URI format: `protocol://[user:pass@]host:port`
ProxyEntry _parseUri(String raw, ParseProxyOptions options) {
  final uri = Uri.parse(raw);
  if (!uri.hasAuthority || uri.host.isEmpty) {
    throw const FormatException('Invalid URI structure: missing host');
  }
  if (!uri.hasPort) {
    throw const FormatException('URI missing port number');
  }

  final protocol = _parseProtocol(uri.scheme);
  String? username;
  String? password;

  if (uri.userInfo.isNotEmpty) {
    final parts = uri.userInfo.split(':');
    username = _decodeAuth(parts[0]);
    if (parts.length > 1) {
      password = _decodeAuth(parts.sublist(1).join(':'));
    }
  }

  return ProxyEntry(
    id: generateProxyId(),
    protocol: protocol,
    host: uri.host,
    port: uri.port,
    username: username?.isNotEmpty == true ? username : null,
    password: password?.isNotEmpty == true ? password : null,
    raw: raw.trim(),
    addedAt: DateTime.now().millisecondsSinceEpoch,
  );
}

/// 2. Parse host:port format
ProxyEntry _parseHostPort(String raw, ParseProxyOptions options) {
  final colonIdx = raw.lastIndexOf(':');
  if (colonIdx <= 0 || colonIdx == raw.length - 1) {
    throw FormatException('Expected host:port format (got "$raw")');
  }

  final host = raw.substring(0, colonIdx).trim();
  final portStr = raw.substring(colonIdx + 1).trim();

  if (host.isEmpty) throw const FormatException('Empty host');

  return ProxyEntry(
    id: generateProxyId(),
    protocol: _parseProtocol(options.defaultProtocol),
    host: host,
    port: _parsePort(portStr),
    raw: raw.trim(),
    addedAt: DateTime.now().millisecondsSinceEpoch,
  );
}

/// 3. Parse colon-quad format: `host:port:username:password`
ProxyEntry _parseColonQuad(String raw, ParseProxyOptions options) {
  final parts = raw.split(':');
  if (parts.length != 4) {
    throw FormatException('Expected host:port:user:pass (got "$raw")');
  }

  final host = parts[0].trim();
  final portStr = parts[1].trim();
  final username = parts[2].trim();
  final password = parts[3].trim();

  if (host.isEmpty) throw const FormatException('Empty host');
  if (username.isEmpty) throw const FormatException('Empty username');

  return ProxyEntry(
    id: generateProxyId(),
    protocol: _parseProtocol(options.defaultProtocol),
    host: host,
    port: _parsePort(portStr),
    username: username,
    password: password.isNotEmpty ? password : null,
    raw: raw.trim(),
    addedAt: DateTime.now().millisecondsSinceEpoch,
  );
}

/// 4. Parse auth@host:port format: `username:password@host:port`
ProxyEntry _parseAuthAtHostPort(String raw, ParseProxyOptions options) {
  final atIdx = raw.lastIndexOf('@');
  if (atIdx <= 0 || atIdx == raw.length - 1) {
    throw FormatException('Expected user:pass@host:port format (got "$raw")');
  }

  final authPart = raw.substring(0, atIdx);
  final hostPortPart = raw.substring(atIdx + 1);

  final authColon = authPart.indexOf(':');
  final username = authColon >= 0 ? authPart.substring(0, authColon) : authPart;
  final password = authColon >= 0 ? authPart.substring(authColon + 1) : null;

  final hpColon = hostPortPart.lastIndexOf(':');
  if (hpColon <= 0) throw const FormatException('Missing port in host:port part');

  final host = hostPortPart.substring(0, hpColon).trim();
  final portStr = hostPortPart.substring(hpColon + 1).trim();

  if (host.isEmpty) throw const FormatException('Empty host');

  return ProxyEntry(
    id: generateProxyId(),
    protocol: _parseProtocol(options.defaultProtocol),
    host: host,
    port: _parsePort(portStr),
    username: _decodeAuth(username),
    password: password != null ? _decodeAuth(password) : null,
    raw: raw.trim(),
    addedAt: DateTime.now().millisecondsSinceEpoch,
  );
}

/// Main auto-detect parser for single proxy input string.
ProxyEntry parseProxyUri(String rawInput, [ParseProxyOptions options = const ParseProxyOptions()]) {
  final input = rawInput.trim();
  if (input.isEmpty) {
    throw const FormatException('Proxy string cannot be empty');
  }

  // Scheme detection (http://, https://, socks4://, socks5://)
  if (RegExp(r'^[a-zA-Z0-9+-.]+://').hasMatch(input)) {
    return _parseUri(input, options);
  }

  // Check colon quad host:port:user:pass
  final colons = input.split(':').length - 1;
  if (colons == 3 && !input.contains('@')) {
    return _parseColonQuad(input, options);
  }

  // Check auth@host:port
  if (input.contains('@')) {
    return _parseAuthAtHostPort(input, options);
  }

  // Fallback to simple host:port
  return _parseHostPort(input, options);
}

/// Bulk parser for multi-line proxy text.
BulkParseResult parseBulkProxies(String text, [ParseProxyOptions options = const ParseProxyOptions()]) {
  final lines = text.split('\n');
  final proxies = <ProxyEntry>[];
  final errors = <String>[];

  for (var i = 0; i < lines.length; i++) {
    final lineNum = i + 1;
    final line = lines[i].trim();

    // Skip empty lines & comments
    if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
      continue;
    }

    try {
      final entry = parseProxyUri(line, options);
      proxies.add(entry);
    } catch (e) {
      final msg = e is FormatException ? e.message : e.toString();
      errors.add('Line $lineNum ("$line"): $msg');
    }
  }

  return BulkParseResult(proxies: proxies, errors: errors);
}
