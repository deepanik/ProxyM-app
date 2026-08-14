import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/proxy_entry.dart';
import '../models/bypass_rule.dart';
import '../models/rotation_config.dart';
import '../models/auto_detect_config.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../core/proxy/proxy_manager.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(() {
  return SettingsNotifier();
});

final activeProxyProvider = Provider<ProxyEntry?>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.enabled || settings.activeProxyId == null) return null;
  try {
    return settings.proxies.firstWhere((p) => p.id == settings.activeProxyId);
  } catch (_) {
    return null;
  }
});

final savingStateProvider = NotifierProvider<SavingStateNotifier, bool>(SavingStateNotifier.new);
final saveErrorProvider = NotifierProvider<SaveErrorNotifier, String?>(SaveErrorNotifier.new);

class SavingStateNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  @override
  set state(bool value) => super.state = value;
}

class SaveErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  @override
  set state(String? value) => super.state = value;
}

class SettingsNotifier extends Notifier<AppSettings> {
  final _apiService = ApiService();

  @override
  AppSettings build() {
    _loadCachedSettings();
    return AppSettings.defaultSettings;
  }

  Future<void> _loadCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(storageKey);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = AppSettings.fromJson(data);
      }
    } catch (e) {
      print('Failed to load cached settings: $e');
    }
  }

  Future<void> _persistLocally(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(settings.toJson()));
    } catch (e) {
      print('Failed to persist settings locally: $e');
    }
  }

  Future<void> update({
    bool? enabled,
    int? rotationIntervalMinutes,
    String? activeProxyId,
    bool clearActiveProxy = false,
    List<ProxyEntry>? proxies,
    List<BypassRule>? bypassRules,
    String? theme,
    RotationConfig? rotation,
    AutoDetectConfig? autoDetect,
  }) async {
    final newState = state.copyWith(
      enabled: enabled,
      rotationIntervalMinutes: rotationIntervalMinutes,
      activeProxyId: activeProxyId,
      clearActiveProxy: clearActiveProxy,
      proxies: proxies,
      bypassRules: bypassRules,
      theme: theme,
      rotation: rotation,
      autoDetect: autoDetect,
    );

    state = newState;
    await _persistLocally(newState);
    _handleVpnSync(newState);
    _syncToBackend(newState);
  }

  Future<void> _handleVpnSync(AppSettings newState) async {
    await ProxyManager.instance.updateConfig(
      enabled: newState.enabled,
      activeProxy: newState.activeProxy,
      bypassRules: newState.bypassRules,
    );
  }

  Future<void> _syncToBackend(AppSettings settings) async {
    ref.read(savingStateProvider.notifier).state = true;
    ref.read(saveErrorProvider.notifier).state = null;

    try {
      // Sync settings payload to backend if authenticated
      await _apiService.client.post('/settings', data: settings.toJson());
    } catch (_) {
      // Local state is single source of truth; ignore offline/unauth backend notice
    } finally {
      ref.read(savingStateProvider.notifier).state = false;
    }
  }

  Future<void> toggleEnabled() async {
    await update(enabled: !state.enabled);
  }

  Future<void> setActiveProxy(String? id) async {
    if (id == null) {
      await update(clearActiveProxy: true);
    } else {
      await update(activeProxyId: id);
    }
  }

  Future<void> toggleTheme() async {
    final nextTheme = state.theme == 'light' ? 'dark' : 'light';
    await update(theme: nextTheme);
  }
}
