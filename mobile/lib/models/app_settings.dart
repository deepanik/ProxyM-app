import 'proxy_entry.dart';
import 'bypass_rule.dart';
import 'rotation_config.dart';
import 'auto_detect_config.dart';

class AppSettings {
  final bool enabled;
  final int rotationIntervalMinutes;
  final String? activeProxyId;
  final List<ProxyEntry> proxies;
  final List<BypassRule> bypassRules;
  final String theme;
  final RotationConfig rotation;
  final AutoDetectConfig autoDetect;

  const AppSettings({
    this.enabled = false,
    this.rotationIntervalMinutes = 1,
    this.activeProxyId,
    this.proxies = const [],
    this.bypassRules = const [],
    this.theme = 'dark',
    this.rotation = const RotationConfig(),
    this.autoDetect = const AutoDetectConfig(),
  });

  static const defaultSettings = AppSettings();

  ProxyEntry? get activeProxy {
    if (activeProxyId == null) return null;
    return proxies.where((p) => p.id == activeProxyId).firstOrNull;
  }

  AppSettings copyWith({
    bool? enabled,
    int? rotationIntervalMinutes,
    String? activeProxyId,
    List<ProxyEntry>? proxies,
    List<BypassRule>? bypassRules,
    String? theme,
    RotationConfig? rotation,
    AutoDetectConfig? autoDetect,
    bool clearActiveProxy = false,
  }) =>
      AppSettings(
        enabled: enabled ?? this.enabled,
        rotationIntervalMinutes: rotationIntervalMinutes ?? this.rotationIntervalMinutes,
        activeProxyId: clearActiveProxy ? null : (activeProxyId ?? this.activeProxyId),
        proxies: proxies ?? this.proxies,
        bypassRules: bypassRules ?? this.bypassRules,
        theme: theme ?? this.theme,
        rotation: rotation ?? this.rotation,
        autoDetect: autoDetect ?? this.autoDetect,
      );

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        enabled: j['enabled'] as bool? ?? false,
        rotationIntervalMinutes: j['rotationIntervalMinutes'] as int? ?? 1,
        activeProxyId: j['activeProxyId'] as String?,
        proxies: (j['proxies'] as List<dynamic>?)
                ?.map((e) => ProxyEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        bypassRules: (j['bypassRules'] as List<dynamic>?)
                ?.map((e) => BypassRule.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        theme: j['theme'] as String? ?? 'dark',
        rotation: j['rotation'] != null
            ? RotationConfig.fromJson(j['rotation'] as Map<String, dynamic>)
            : const RotationConfig(),
        autoDetect: j['autoDetect'] != null
            ? AutoDetectConfig.fromJson(j['autoDetect'] as Map<String, dynamic>)
            : const AutoDetectConfig(),
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'rotationIntervalMinutes': rotationIntervalMinutes,
        'activeProxyId': activeProxyId,
        'proxies': proxies.map((p) => p.toJson()).toList(),
        'bypassRules': bypassRules.map((b) => b.toJson()).toList(),
        'theme': theme,
        'rotation': rotation.toJson(),
        'autoDetect': autoDetect.toJson(),
      };
}
