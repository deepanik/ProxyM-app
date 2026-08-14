import '../models/proxy_entry.dart';

/// Full display format: `protocol://[user:****@]host:port`
String formatProxyDisplay(ProxyEntry p) {
  final auth = p.username != null
      ? (p.password != null ? '${p.username}:****@' : '${p.username}@')
      : '';
  return '${p.protocol.name}://$auth${p.host}:${p.port}';
}

/// Short format: `host:port`
String formatProxyShort(ProxyEntry p) => '${p.host}:${p.port}';
