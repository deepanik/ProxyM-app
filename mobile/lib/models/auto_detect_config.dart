class AutoDetectConfig {
  final bool enabled;
  final bool deadProxy;
  final bool slowProxy;
  final int slowThresholdMs;
  final bool captchaProxy;
  final bool blockedProxy;
  final bool expiredCredentials;
  final bool autoRemoveDead;
  final bool autoSkipFlagged;

  const AutoDetectConfig({
    this.enabled = true,
    this.deadProxy = true,
    this.slowProxy = true,
    this.slowThresholdMs = 3000,
    this.captchaProxy = true,
    this.blockedProxy = true,
    this.expiredCredentials = true,
    this.autoRemoveDead = false,
    this.autoSkipFlagged = true,
  });

  static const defaultConfig = AutoDetectConfig();

  AutoDetectConfig copyWith({
    bool? enabled,
    bool? deadProxy,
    bool? slowProxy,
    int? slowThresholdMs,
    bool? captchaProxy,
    bool? blockedProxy,
    bool? expiredCredentials,
    bool? autoRemoveDead,
    bool? autoSkipFlagged,
  }) =>
      AutoDetectConfig(
        enabled: enabled ?? this.enabled,
        deadProxy: deadProxy ?? this.deadProxy,
        slowProxy: slowProxy ?? this.slowProxy,
        slowThresholdMs: slowThresholdMs ?? this.slowThresholdMs,
        captchaProxy: captchaProxy ?? this.captchaProxy,
        blockedProxy: blockedProxy ?? this.blockedProxy,
        expiredCredentials: expiredCredentials ?? this.expiredCredentials,
        autoRemoveDead: autoRemoveDead ?? this.autoRemoveDead,
        autoSkipFlagged: autoSkipFlagged ?? this.autoSkipFlagged,
      );

  factory AutoDetectConfig.fromJson(Map<String, dynamic> j) => AutoDetectConfig(
        enabled: j['enabled'] as bool? ?? true,
        deadProxy: j['deadProxy'] as bool? ?? true,
        slowProxy: j['slowProxy'] as bool? ?? true,
        slowThresholdMs: j['slowThresholdMs'] as int? ?? 3000,
        captchaProxy: j['captchaProxy'] as bool? ?? true,
        blockedProxy: j['blockedProxy'] as bool? ?? true,
        expiredCredentials: j['expiredCredentials'] as bool? ?? true,
        autoRemoveDead: j['autoRemoveDead'] as bool? ?? false,
        autoSkipFlagged: j['autoSkipFlagged'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'deadProxy': deadProxy,
        'slowProxy': slowProxy,
        'slowThresholdMs': slowThresholdMs,
        'captchaProxy': captchaProxy,
        'blockedProxy': blockedProxy,
        'expiredCredentials': expiredCredentials,
        'autoRemoveDead': autoRemoveDead,
        'autoSkipFlagged': autoSkipFlagged,
      };
}
