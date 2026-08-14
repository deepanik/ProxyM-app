import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/settings_provider.dart';
import '../../../models/rotation_config.dart';

class RotationSettingsWidget extends ConsumerWidget {
  const RotationSettingsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final rotation = settings.rotation;

    void updateRotation(RotationConfig newConfig) {
      ref.read(settingsProvider.notifier).update(rotation: newConfig);
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
                Icon(Icons.autorenew, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Smart Proxy Rotation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mode Selector
            const Text('Rotation Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Round Robin'),
                  selected: rotation.mode == RotationMode.roundRobin,
                  onSelected: (s) {
                    if (s) updateRotation(rotation.copyWith(mode: RotationMode.roundRobin));
                  },
                ),
                ChoiceChip(
                  label: const Text('Random'),
                  selected: rotation.mode == RotationMode.random,
                  onSelected: (s) {
                    if (s) updateRotation(rotation.copyWith(mode: RotationMode.random));
                  },
                ),
                ChoiceChip(
                  label: const Text('Weighted'),
                  selected: rotation.mode == RotationMode.weighted,
                  onSelected: (s) {
                    if (s) updateRotation(rotation.copyWith(mode: RotationMode.weighted));
                  },
                ),
                ChoiceChip(
                  label: const Text('Sticky'),
                  selected: rotation.mode == RotationMode.sticky,
                  onSelected: (s) {
                    if (s) updateRotation(rotation.copyWith(mode: RotationMode.sticky));
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Interval Input
            Row(
              children: [
                const Expanded(
                  child: Text('Interval (Minutes)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: rotation.intervalMinutes.toString()),
                    onSubmitted: (val) {
                      final n = int.tryParse(val);
                      if (n != null && n > 0) {
                        updateRotation(rotation.copyWith(intervalMinutes: n));
                      }
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sticky Session Duration (if sticky mode selected)
            if (rotation.mode == RotationMode.sticky) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text('Sticky Duration (Minutes)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: rotation.stickySessionMinutes.toString()),
                      onSubmitted: (val) {
                        final n = int.tryParse(val);
                        if (n != null && n > 0) {
                          updateRotation(rotation.copyWith(stickySessionMinutes: n));
                        }
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Cooldown Input
            Row(
              children: [
                const Expanded(
                  child: Text('Cooldown (Minutes)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: rotation.cooldownMinutes.toString()),
                    onSubmitted: (val) {
                      final n = int.tryParse(val);
                      if (n != null && n >= 0) {
                        updateRotation(rotation.copyWith(cooldownMinutes: n));
                      }
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Skip Failed Toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Skip Failed / Dead Proxies', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Exclude unreachable proxies during rotation', style: TextStyle(fontSize: 12, color: Colors.grey)),
              value: rotation.skipFailed,
              onChanged: (val) {
                updateRotation(rotation.copyWith(skipFailed: val));
              },
            ),
          ],
        ),
      ),
    );
  }
}
