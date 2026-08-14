import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:pool/pool.dart';
import '../models/proxy_entry.dart';

class ProxyTestService {
  static const _testUrls = {
    'https': 'https://httpbin.org/get',
    'dns': 'https://dns.google/resolve?name=example.com&type=A',
    'speed': 'https://speed.cloudflare.com/__down?bytes=100000',
    'geo': 'https://ipwho.is/',
  };

  static const _captchaSignatures = [
    'captcha',
    'cf-chl',
    'challenge',
    'are you human',
    'ddos-guard',
    'datadome',
    'recaptcha',
  ];

  static const _blockedSignatures = [
    'access denied',
    '403 forbidden',
    'blocked',
    'unavailable',
    'restricted',
    'your ip has been',
  ];

  HttpClient _createProxiedClient(ProxyEntry proxy) {
    final client = HttpClient();

    client.findProxy = (uri) {
      final scheme = proxy.protocol == ProxyProtocol.socks5
          ? 'SOCKS5'
          : proxy.protocol == ProxyProtocol.socks4
              ? 'SOCKS4'
              : 'PROXY';
      return '$scheme ${proxy.host}:${proxy.port}';
    };

    if (proxy.username != null && proxy.username!.isNotEmpty) {
      client.addProxyCredentials(
        proxy.host,
        proxy.port,
        'basic',
        HttpClientBasicCredentials(proxy.username!, proxy.password ?? ''),
      );
    }

    client.connectionTimeout = const Duration(milliseconds: 8000);
    return client;
  }

  ProxyTestStatus _deriveStatus(ProxyFlags flags, int? latencyMs, int slowThresholdMs) {
    if (flags.dead) return ProxyTestStatus.dead;
    if (flags.credentialsExpired) return ProxyTestStatus.expired;
    if (flags.blocked || flags.captcha) return ProxyTestStatus.blocked;
    if (flags.dnsLeak) return ProxyTestStatus.leaked;
    if (latencyMs != null && latencyMs > slowThresholdMs) return ProxyTestStatus.slow;
    return ProxyTestStatus.ok;
  }

  /// Test a single proxy across connectivity, latency, DNS, download speed, SSL, captcha & blocked signatures.
  Future<ProxyTestResult> testProxy(ProxyEntry proxy, {int slowThresholdMs = 3000}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var flags = const ProxyFlags.allFalse();

    int? latencyMs;
    int? downloadKbps;
    int? dnsMs;
    bool? sslValid;
    String? country;
    String? ip;

    final client = _createProxiedClient(proxy);

    // 1. Connectivity & Latency check
    try {
      final sw = Stopwatch()..start();
      final req = await client.getUrl(Uri.parse(_testUrls['https']!));
      final res = await req.close();
      sw.stop();
      latencyMs = sw.elapsedMilliseconds;
      sslValid = res.statusCode == 200;

      if (res.statusCode == 407) {
        flags = flags.copyWith(credentialsExpired: true);
      } else if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final lower = body.toLowerCase();
        if (_captchaSignatures.any((s) => lower.contains(s))) {
          flags = flags.copyWith(captcha: true);
        }
        if (_blockedSignatures.any((s) => lower.contains(s))) {
          flags = flags.copyWith(blocked: true);
        }
      } else if (res.statusCode == 403 || res.statusCode >= 500) {
        flags = flags.copyWith(blocked: true);
      }
    } catch (_) {
      flags = flags.copyWith(dead: true);
    }

    if (flags.dead) {
      client.close();
      return ProxyTestResult(
        testedAt: now,
        status: ProxyTestStatus.dead,
        flags: flags,
      );
    }

    // 2. Slow threshold check
    if (latencyMs != null && latencyMs > slowThresholdMs) {
      flags = flags.copyWith(slow: true);
    }

    // 3. DNS latency check
    try {
      final sw = Stopwatch()..start();
      final req = await client.getUrl(Uri.parse(_testUrls['dns']!));
      final res = await req.close();
      sw.stop();
      if (res.statusCode == 200) {
        dnsMs = sw.elapsedMilliseconds;
      }
    } catch (_) {}

    // 4. Download speed test
    try {
      final sw = Stopwatch()..start();
      final req = await client.getUrl(Uri.parse(_testUrls['speed']!));
      final res = await req.close();
      final bytes = await res.fold<int>(0, (sum, chunk) => sum + chunk.length);
      sw.stop();
      final elapsedSec = sw.elapsedMilliseconds / 1000.0;
      if (elapsedSec > 0) {
        downloadKbps = ((bytes / 1024) / elapsedSec).round();
      }
    } catch (_) {}

    // 5. Geo IP & DNS leak check
    try {
      final req = await client.getUrl(Uri.parse(_testUrls['geo']!));
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final d = jsonDecode(body) as Map<String, dynamic>;
        ip = d['ip'] as String?;
        country = (d['country_code'] as String? ?? '').toUpperCase();
        if (ip == proxy.host) {
          flags = flags.copyWith(dnsLeak: true);
        }
      }
    } catch (_) {}

    client.close();

    final finalStatus = _deriveStatus(flags, latencyMs, slowThresholdMs);
    return ProxyTestResult(
      testedAt: now,
      latencyMs: latencyMs,
      downloadKbps: downloadKbps,
      dnsMs: dnsMs,
      sslValid: sslValid,
      country: country,
      ip: ip,
      status: finalStatus,
      flags: flags,
    );
  }

  /// Bulk test multiple proxies concurrently with max pool concurrency.
  Future<Map<String, ProxyTestResult>> testAll(
    List<ProxyEntry> proxies, {
    int maxConcurrency = 5,
    int slowThresholdMs = 3000,
    void Function(int completed, int total)? onProgress,
  }) async {
    final results = <String, ProxyTestResult>{};
    final pool = Pool(maxConcurrency);
    var completedCount = 0;

    await Future.wait(
      proxies.map((proxy) => pool.withResource(() async {
            final res = await testProxy(proxy, slowThresholdMs: slowThresholdMs);
            results[proxy.id] = res;
            completedCount++;
            onProgress?.call(completedCount, proxies.length);
          })),
    );

    return results;
  }
}
