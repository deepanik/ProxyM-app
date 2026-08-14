import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/proxy_entry.dart';
import '../utils/proxy_parser.dart';
import 'settings_provider.dart';

final proxyProvider = NotifierProvider<ProxyNotifier, List<ProxyEntry>>(() {
  return ProxyNotifier();
});

class ProxyNotifier extends Notifier<List<ProxyEntry>> {
  final _apiService = ApiService();

  @override
  List<ProxyEntry> build() {
    // Watch settingsProvider so proxy list automatically stays in sync with local storage
    final settings = ref.watch(settingsProvider);
    return settings.proxies;
  }

  Future<void> fetchProxies() async {
    try {
      final response = await _apiService.client.get('/proxies');
      final List<dynamic> data = response.data;
      if (data.isEmpty) return; // keep local list if server returned empty

      final list = data.map((item) {
        if (item is Map<String, dynamic>) {
          if (item.containsKey('host') && item.containsKey('port')) {
            return ProxyEntry.fromJson(item);
          }
          final host = item['ip_address'] as String? ?? item['host'] as String? ?? '';
          final port = int.tryParse(item['port'].toString()) ?? 80;
          final user = item['username'] as String?;
          final pass = item['password'] as String?;
          final authStr = user != null ? (pass != null ? '$user:$pass@' : '$user@') : '';

          return ProxyEntry(
            id: (item['id'] ?? generateProxyId()).toString(),
            protocol: ProxyProtocol.http,
            host: host,
            port: port,
            username: user,
            password: pass,
            raw: '$authStr$host:$port',
            addedAt: DateTime.now().millisecondsSinceEpoch,
            testResult: item['status'] != null
                ? ProxyTestResult(
                    testedAt: DateTime.now().millisecondsSinceEpoch,
                    status: item['status'] == 'ok' ? ProxyTestStatus.ok : ProxyTestStatus.untested,
                    flags: const ProxyFlags.allFalse(),
                  )
                : null,
          );
        }
        throw const FormatException('Invalid proxy data item');
      }).toList();

      ref.read(settingsProvider.notifier).update(proxies: list);
    } catch (e) {
      print('Fetch proxies notice: $e');
    }
  }

  Future<void> addProxy(String rawProxy) async {
    final parsed = parseProxyUri(rawProxy);

    // 1. Instantly save to local state & SharedPreferences
    final currentList = ref.read(settingsProvider).proxies;
    final updatedList = [...currentList, parsed];
    await ref.read(settingsProvider.notifier).update(proxies: updatedList);

    // 2. Sync to backend asynchronously
    try {
      final response = await _apiService.client.post('/proxies', data: {
        'raw_proxy': rawProxy,
        'protocol': parsed.protocol.name,
        'host': parsed.host,
        'port': parsed.port,
        'username': parsed.username,
        'password': parsed.password,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data.containsKey('id')) {
          final serverId = data['id'].toString();
          final syncedList = ref.read(settingsProvider).proxies.map((p) {
            return p.id == parsed.id ? p.copyWith(id: serverId) : p;
          }).toList();
          ref.read(settingsProvider.notifier).update(proxies: syncedList);
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        // Rollback local addition if server rejects due to limit
        ref.read(settingsProvider.notifier).update(
              proxies: ref.read(settingsProvider).proxies.where((p) => p.id != parsed.id).toList(),
            );
        throw e.response?.data['message'] ?? 'Proxy limit reached';
      }
    } catch (_) {}
  }

  Future<void> removeProxy(String id) async {
    try {
      await _apiService.client.delete('/proxies/$id');
    } catch (e) {
      print('Delete backend notice: $e');
    }

    final settings = ref.read(settingsProvider);
    final updatedList = settings.proxies.where((p) => p.id != id).toList();
    final isCurrentActive = settings.activeProxyId == id;

    await ref.read(settingsProvider.notifier).update(
          proxies: updatedList,
          clearActiveProxy: isCurrentActive,
        );
  }

  Future<void> clearAllProxies() async {
    await ref.read(settingsProvider.notifier).update(
          proxies: [],
          clearActiveProxy: true,
        );
  }

  void setActive(String id) {
    ref.read(settingsProvider.notifier).setActiveProxy(id);
  }

  void updateEntry(ProxyEntry updated) {
    final list = ref.read(settingsProvider).proxies.map((p) => p.id == updated.id ? updated : p).toList();
    ref.read(settingsProvider.notifier).update(proxies: list);
  }

  Future<Map<String, dynamic>?> testProxy(String id) async {
    try {
      final response = await _apiService.client.post('/proxies/$id/test');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print('Test error: $e');
    }
    return {'status': 'ok'};
  }
}
