enum RotationMode { roundRobin, random, weighted, sticky }

enum RotationTrigger { time, requests, tabChange, browserRestart }

class RotationConfig {
  final RotationMode mode;
  final RotationTrigger trigger;
  final int intervalMinutes;
  final int intervalRequests;
  final bool skipFailed;
  final int retryCount;
  final int cooldownMinutes;
  final int stickySessionMinutes;

  const RotationConfig({
    this.mode = RotationMode.roundRobin,
    this.trigger = RotationTrigger.time,
    this.intervalMinutes = 1,
    this.intervalRequests = 100,
    this.skipFailed = true,
    this.retryCount = 2,
    this.cooldownMinutes = 5,
    this.stickySessionMinutes = 30,
  });

  static const defaultConfig = RotationConfig();

  RotationConfig copyWith({
    RotationMode? mode,
    RotationTrigger? trigger,
    int? intervalMinutes,
    int? intervalRequests,
    bool? skipFailed,
    int? retryCount,
    int? cooldownMinutes,
    int? stickySessionMinutes,
  }) =>
      RotationConfig(
        mode: mode ?? this.mode,
        trigger: trigger ?? this.trigger,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        intervalRequests: intervalRequests ?? this.intervalRequests,
        skipFailed: skipFailed ?? this.skipFailed,
        retryCount: retryCount ?? this.retryCount,
        cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
        stickySessionMinutes: stickySessionMinutes ?? this.stickySessionMinutes,
      );

  factory RotationConfig.fromJson(Map<String, dynamic> j) => RotationConfig(
        mode: RotationMode.values.firstWhere(
          (e) => e.name == (j['mode'] as String?)?.replaceAll('-', ''),
          orElse: () {
            // Handle extension's kebab-case "round-robin" → roundRobin
            final raw = j['mode'] as String? ?? 'roundRobin';
            if (raw == 'round-robin') return RotationMode.roundRobin;
            return RotationMode.roundRobin;
          },
        ),
        trigger: RotationTrigger.values.firstWhere(
          (e) => e.name == (j['trigger'] as String?)?.replaceAll('-', ''),
          orElse: () {
            final raw = j['trigger'] as String? ?? 'time';
            if (raw == 'tab-change') return RotationTrigger.tabChange;
            if (raw == 'browser-restart') return RotationTrigger.browserRestart;
            return RotationTrigger.time;
          },
        ),
        intervalMinutes: j['intervalMinutes'] as int? ?? 1,
        intervalRequests: j['intervalRequests'] as int? ?? 100,
        skipFailed: j['skipFailed'] as bool? ?? true,
        retryCount: j['retryCount'] as int? ?? 2,
        cooldownMinutes: j['cooldownMinutes'] as int? ?? 5,
        stickySessionMinutes: j['stickySessionMinutes'] as int? ?? 30,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'trigger': trigger.name,
        'intervalMinutes': intervalMinutes,
        'intervalRequests': intervalRequests,
        'skipFailed': skipFailed,
        'retryCount': retryCount,
        'cooldownMinutes': cooldownMinutes,
        'stickySessionMinutes': stickySessionMinutes,
      };
}
