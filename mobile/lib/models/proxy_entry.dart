enum ProxyProtocol { http, https, socks4, socks5 }

enum ProxyTestStatus { untested, ok, slow, dead, blocked, leaked, expired }

class ProxyFlags {
  final bool dead;
  final bool slow;
  final bool captcha;
  final bool blocked;
  final bool credentialsExpired;
  final bool dnsLeak;

  const ProxyFlags({
    this.dead = false,
    this.slow = false,
    this.captcha = false,
    this.blocked = false,
    this.credentialsExpired = false,
    this.dnsLeak = false,
  });

  const ProxyFlags.allFalse()
      : dead = false,
        slow = false,
        captcha = false,
        blocked = false,
        credentialsExpired = false,
        dnsLeak = false;

  ProxyFlags copyWith({
    bool? dead,
    bool? slow,
    bool? captcha,
    bool? blocked,
    bool? credentialsExpired,
    bool? dnsLeak,
  }) =>
      ProxyFlags(
        dead: dead ?? this.dead,
        slow: slow ?? this.slow,
        captcha: captcha ?? this.captcha,
        blocked: blocked ?? this.blocked,
        credentialsExpired: credentialsExpired ?? this.credentialsExpired,
        dnsLeak: dnsLeak ?? this.dnsLeak,
      );

  factory ProxyFlags.fromJson(Map<String, dynamic> j) => ProxyFlags(
        dead: j['dead'] as bool? ?? false,
        slow: j['slow'] as bool? ?? false,
        captcha: j['captcha'] as bool? ?? false,
        blocked: j['blocked'] as bool? ?? false,
        credentialsExpired: j['credentialsExpired'] as bool? ?? false,
        dnsLeak: j['dnsLeak'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'dead': dead,
        'slow': slow,
        'captcha': captcha,
        'blocked': blocked,
        'credentialsExpired': credentialsExpired,
        'dnsLeak': dnsLeak,
      };
}

class ProxyTestResult {
  final int testedAt;
  final int? latencyMs;
  final int? downloadKbps;
  final int? uploadKbps;
  final int? dnsMs;
  final bool? sslValid;
  final String? country;
  final String? ip;
  final ProxyTestStatus status;
  final ProxyFlags flags;

  const ProxyTestResult({
    required this.testedAt,
    this.latencyMs,
    this.downloadKbps,
    this.uploadKbps,
    this.dnsMs,
    this.sslValid,
    this.country,
    this.ip,
    required this.status,
    required this.flags,
  });

  factory ProxyTestResult.fromJson(Map<String, dynamic> j) => ProxyTestResult(
        testedAt: j['testedAt'] as int,
        latencyMs: j['latencyMs'] as int?,
        downloadKbps: j['downloadKbps'] as int?,
        uploadKbps: j['uploadKbps'] as int?,
        dnsMs: j['dnsMs'] as int?,
        sslValid: j['sslValid'] as bool?,
        country: j['country'] as String?,
        ip: j['ip'] as String?,
        status: ProxyTestStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => ProxyTestStatus.untested,
        ),
        flags: ProxyFlags.fromJson(j['flags'] as Map<String, dynamic>? ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'testedAt': testedAt,
        'latencyMs': latencyMs,
        'downloadKbps': downloadKbps,
        'uploadKbps': uploadKbps,
        'dnsMs': dnsMs,
        'sslValid': sslValid,
        'country': country,
        'ip': ip,
        'status': status.name,
        'flags': flags.toJson(),
      };
}

class ProxyEntry {
  final String id;
  final ProxyProtocol protocol;
  final String host;
  final int port;
  final String? username;
  final String? password;
  final String raw;
  final int addedAt;
  final int? lastUsed;
  final int? weight;
  final ProxyTestResult? testResult;

  const ProxyEntry({
    required this.id,
    required this.protocol,
    required this.host,
    required this.port,
    this.username,
    this.password,
    required this.raw,
    required this.addedAt,
    this.lastUsed,
    this.weight,
    this.testResult,
  });

  ProxyEntry copyWith({
    String? id,
    ProxyProtocol? protocol,
    String? host,
    int? port,
    String? username,
    String? password,
    String? raw,
    int? addedAt,
    int? lastUsed,
    int? weight,
    ProxyTestResult? testResult,
  }) =>
      ProxyEntry(
        id: id ?? this.id,
        protocol: protocol ?? this.protocol,
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        password: password ?? this.password,
        raw: raw ?? this.raw,
        addedAt: addedAt ?? this.addedAt,
        lastUsed: lastUsed ?? this.lastUsed,
        weight: weight ?? this.weight,
        testResult: testResult ?? this.testResult,
      );

  factory ProxyEntry.fromJson(Map<String, dynamic> j) => ProxyEntry(
        id: j['id'] as String,
        protocol: ProxyProtocol.values.firstWhere(
          (e) => e.name == j['protocol'],
          orElse: () => ProxyProtocol.http,
        ),
        host: j['host'] as String,
        port: j['port'] as int,
        username: j['username'] as String?,
        password: j['password'] as String?,
        raw: j['raw'] as String? ?? '',
        addedAt: j['addedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        lastUsed: j['lastUsed'] as int?,
        weight: j['weight'] as int?,
        testResult: j['testResult'] != null
            ? ProxyTestResult.fromJson(j['testResult'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'protocol': protocol.name,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'raw': raw,
        'addedAt': addedAt,
        'lastUsed': lastUsed,
        'weight': weight,
        'testResult': testResult?.toJson(),
      };
}
