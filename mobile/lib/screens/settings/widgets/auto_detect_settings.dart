import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/auto_detect_provider.dart';
import '../../../models/auto_detect_config.dart';

class AutoDetectSettingsWidget extends ConsumerStatefulWidget {
  const AutoDetectSettingsWidget({super.key});

  @override
  ConsumerState<AutoDetectSettingsWidget> createState() => _AutoDetectSettingsWidgetState();
}

class _AutoDetectSettingsWidgetState extends ConsumerState<AutoDetectSettingsWidget> {
  int _completed = 0;
  int _total = 0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final autoDetect = settings.autoDetect;
    final isScanning = ref.watch(autoDetectProvider);

    void updateAutoDetect(AutoDetectConfig newConfig) {
      ref.read(settingsProvider.notifier).update(autoDetect: newConfig);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.radar, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Auto-Detection System',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Switch(
                  value: autoDetect.enabled,
                  onChanged: (val) {
                    updateAutoDetect(autoDetect.copyWith(enabled: val));
                  },
                ),
              ],
            ),
            if (autoDetect.enabled) ...[
              const SizedBox(height: 12),

              // Scan Now Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isScanning
                      ? null
                      : () {
                          ref.read(autoDetectProvider.notifier).scanAll(
                            onProgress: (c, t) {
                              if (mounted) {
                                setState(() {
                                  _completed = c;
                                  _total = t;
                                });
                              }
                            },
                          );
                        },
                  icon: isScanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(
                    isScanning
                        ? 'Scanning ($_completed / $_total)...'
                        : 'Scan All Proxies Now',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Detection Criteria', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dead Proxies', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Flag unreachable or timed out proxies', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: autoDetect.deadProxy,
                onChanged: (v) => updateAutoDetect(autoDetect.copyWith(deadProxy: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Slow Proxies', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Flag proxies exceeding latency threshold', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: autoDetect.slowProxy,
                onChanged: (v) => updateAutoDetect(autoDetect.copyWith(slowProxy: v)),
              ),

              // Slow Threshold Slider
              if (autoDetect.slowProxy) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Slow Threshold:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      Text('${autoDetect.slowThresholdMs} ms', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Slider(
                  min: 500,
                  max: 10000,
                  divisions: 19,
                  value: autoDetect.slowThresholdMs.toDouble(),
                  onChanged: (v) => updateAutoDetect(autoDetect.copyWith(slowThresholdMs: v.round())),
                ),
              ],

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Captcha-Heavy', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Flag proxies triggering Cloudflare / Captchas', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: autoDetect.captchaProxy,
                onChanged: (v) => updateAutoDetect(autoDetect.copyWith(captchaProxy: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Blocked Proxies', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Flag proxies returning 403 Forbidden / Access Denied', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: autoDetect.blockedProxy,
                onChanged: (v) => updateAutoDetect(autoDetect.copyWith(blockedProxy: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Expired Credentials', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Flag 407 Proxy Auth Required errors', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: autoDetect.expiredCredentials,
                onChanged: (v) => updateAutoDetect(autoDetect.copyWith(expiredCredentials: v)),
              ),

              const Divider(height: 24),
              const Text('Auto Actions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-Remove Dead', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Automatically delete dead proxies after scan', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: autoDetect.autoRemoveDead,
                onChanged: (v) => updateAutoDetect(autoDetect.copyWith(autoRemoveDead: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-Skip Flagged', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Excludes bad proxies from rotation automatically', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: autoDetect.autoSkipFlagged,
                onChanged: (v) => updateAutoDetect(autoDetect.copyWith(autoSkipFlagged: v)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
