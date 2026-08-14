import 'dart:convert';
import 'package:dio/dio.dart';

enum DnsMode { remoteProxy, dnsOverHttps, localSystem }

class DnsManager {
  final DnsMode mode;
  final Dio _dio = Dio();

  DnsManager({this.mode = DnsMode.remoteProxy});

  Future<String?> resolveHost(String hostname) async {
    if (mode == DnsMode.remoteProxy) {
      // Remote DNS resolution is handled directly by the Proxy server (SOCKS5 / HTTP CONNECT)
      return hostname;
    }

    if (mode == DnsMode.dnsOverHttps) {
      try {
        final response = await _dio.get(
          'https://dns.google/resolve',
          queryParameters: {'name': hostname, 'type': 'A'},
          options: Options(receiveTimeout: const Duration(seconds: 3)),
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data is String ? jsonDecode(response.data) : response.data;
          final answers = data['Answer'] as List<dynamic>?;
          if (answers != null && answers.isNotEmpty) {
            return answers.first['data'] as String?;
          }
        }
      } catch (_) {
        // Fallback to hostname on DoH lookup failure
      }
    }

    return hostname;
  }
}
