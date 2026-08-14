import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/settings_provider.dart';
import 'widgets/rotation_settings.dart';
import 'widgets/auto_detect_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.theme == 'dark';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const RotationSettingsWidget(),
          const AutoDetectSettingsWidget(),
          SwitchListTile(
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Dark Mode'),
            subtitle: Text(isDark ? 'Dark theme enabled' : 'Light theme enabled'),
            value: isDark,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).toggleTheme();
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Bypass Rules'),
            subtitle: const Text('Manage rules for hostnames, CIDR & IPs'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/bypass'),
          ),
          ListTile(
            leading: const Icon(Icons.star, color: Colors.amber),
            title: const Text('Upgrade to Premium'),
            subtitle: const Text('Unlock all features'),
            onTap: () => context.push('/settings/premium'),
          ),
          const ListTile(
            leading: Icon(Icons.person),
            title: Text('Account Profile'),
            subtitle: Text('Manage your account'),
          ),
        ],
      ),
    );
  }
}
