import 'dart:convert';
import 'package:dio/dio.dart';
import '../utils/country_flag.dart';

class GeoData {
  final String ip;
  final String country;
  final String countryCode;
  final String city;
  final String region;
  final String isp;
  final String timezone;
  final String flagEmoji;

  const GeoData({
    required this.ip,
    required this.country,
    required this.countryCode,
    required this.city,
    required this.region,
    required this.isp,
    required this.timezone,
    required this.flagEmoji,
  });

  factory GeoData.fromJson(Map<String, dynamic> j) => GeoData(
        ip: j['ip'] as String? ?? 'Unknown',
        country: j['country'] as String? ?? 'Unknown',
        countryCode: j['countryCode'] as String? ?? '',
        city: j['city'] as String? ?? 'Unknown',
        region: j['region'] as String? ?? '',
        isp: j['isp'] as String? ?? 'Unknown',
        timezone: j['timezone'] as String? ?? 'Unknown',
        flagEmoji: j['flagEmoji'] as String? ?? countryFlag(j['countryCode'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'country': country,
        'countryCode': countryCode,
        'city': city,
        'region': region,
        'isp': isp,
        'timezone': timezone,
        'flagEmoji': flagEmoji,
      };
}

class GeoService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
  ));

  /// Fetch geo info for a host or IP with 3-API fallback chain.
  static Future<GeoData> fetchGeoInfo(String host) async {
    final cleanHost = host.trim();
    if (cleanHost.isEmpty) throw Exception('Host cannot be empty');

    final apis = [
      () => _fetchFromIpWho(cleanHost),
      () => _fetchFromIpGuide(cleanHost),
      () => _fetchFromFreeIpApi(cleanHost),
    ];

    String lastError = 'All geo APIs failed';
    for (final api in apis) {
      try {
        return await api();
      } catch (e) {
        lastError = e.toString();
      }
    }
    throw Exception(lastError);
  }

  // 1. ipwho.is (Primary)
  static Future<GeoData> _fetchFromIpWho(String host) async {
    final res = await _dio.get('https://ipwho.is/${Uri.encodeComponent(host)}');
    final d = res.data is String ? jsonDecode(res.data) : res.data;
    if (d is Map<String, dynamic> && d['success'] == false) {
      throw Exception(d['message'] ?? 'ipwho.is request failed');
    }
    final cc = (d['country_code'] as String? ?? '').toUpperCase();
    return GeoData(
      ip: d['ip'] as String? ?? host,
      country: d['country'] as String? ?? 'Unknown',
      countryCode: cc,
      city: d['city'] as String? ?? 'Unknown',
      region: d['region'] as String? ?? '',
      isp: d['connection']?['isp'] as String? ?? d['connection']?['org'] as String? ?? 'Unknown',
      timezone: d['timezone']?['id'] as String? ?? 'Unknown',
      flagEmoji: countryFlag(cc),
    );
  }

  // 2. ip.guide (Fallback 1)
  static Future<GeoData> _fetchFromIpGuide(String host) async {
    final res = await _dio.get('https://ip.guide/${Uri.encodeComponent(host)}');
    final d = res.data is String ? jsonDecode(res.data) : res.data;
    final loc = d['location'] as Map<String, dynamic>? ?? {};
    final net = d['network'] as Map<String, dynamic>? ?? {};
    final cc = (loc['country'] as String? ?? '').toUpperCase();

    return GeoData(
      ip: d['ip'] as String? ?? host,
      country: loc['country_name'] as String? ?? loc['country'] as String? ?? 'Unknown',
      countryCode: cc,
      city: loc['city'] as String? ?? 'Unknown',
      region: loc['timezone'] as String? ?? '',
      isp: net['autonomous_system_organization'] as String? ?? 'Unknown',
      timezone: loc['timezone'] as String? ?? 'Unknown',
      flagEmoji: countryFlag(cc),
    );
  }

  // 3. freeipapi.com (Fallback 2)
  static Future<GeoData> _fetchFromFreeIpApi(String host) async {
    final res = await _dio.get('https://freeipapi.com/api/json/${Uri.encodeComponent(host)}');
    final d = res.data is String ? jsonDecode(res.data) : res.data;
    final cc = (d['countryCode'] as String? ?? '').toUpperCase();

    return GeoData(
      ip: d['ipAddress'] as String? ?? host,
      country: d['countryName'] as String? ?? 'Unknown',
      countryCode: cc,
      city: d['cityName'] as String? ?? 'Unknown',
      region: d['regionName'] as String? ?? '',
      isp: d['cityName'] as String? ?? 'Unknown',
      timezone: d['timeZone'] as String? ?? 'Unknown',
      flagEmoji: countryFlag(cc),
    );
  }
}
