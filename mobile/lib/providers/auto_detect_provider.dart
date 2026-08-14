import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/proxy_test_service.dart';
import '../models/proxy_entry.dart';
import 'settings_provider.dart';

final autoDetectProvider = NotifierProvider<AutoDetectNotifier, bool>(() {
  return AutoDetectNotifier();
});

class AutoDetectNotifier extends Notifier<bool> {
  @override
  bool build() => false; // returns true while scanning

  /// Run scan across all proxies, apply status flags, and perform auto-actions.
  Future<void> scanAll({void Function(int completed, int total)? onProgress}) async {
    if (state) return; // already scanning
    state = true;

    final settings = ref.read(settingsProvider);
    final autoDetectConfig = settings.autoDetect;
    if (!autoDetectConfig.enabled || settings.proxies.isEmpty) {
      state = false;
      return;
    }

    final testService = ProxyTestService();
    final results = await testService.testAll(
      settings.proxies,
      maxConcurrency: 5,
      slowThresholdMs: autoDetectConfig.slowThresholdMs,
      onProgress: onProgress,
    );

    var updatedProxies = settings.proxies.map((proxy) {
      final res = results[proxy.id];
      return res != null ? proxy.copyWith(testResult: res) : proxy;
    }).toList();

    // Perform auto-remove dead if enabled
    if (autoDetectConfig.autoRemoveDead) {
      updatedProxies = updatedProxies.where((p) {
        return p.testResult?.status != ProxyTestStatus.dead;
      }).toList();
    }

    await ref.read(settingsProvider.notifier).update(proxies: updatedProxies);
    state = false;
  }
}
