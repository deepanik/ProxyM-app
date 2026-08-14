import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'widgets/connection_status_card.dart';
import 'widgets/proxy_info_panel.dart';
import '../../providers/rotation_provider.dart';
import '../../providers/settings_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ProxyM Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Notifications',
            onPressed: () => context.push('/home/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.support_agent),
            tooltip: 'Support',
            onPressed: () => context.push('/home/support'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const ConnectionStatusCard(),
          const ProxyInfoPanel(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/proxies/add'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Proxy'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/proxies/bulk-test'),
                        icon: const Icon(Icons.speed),
                        label: const Text('Bulk Test'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: !settings.enabled || settings.proxies.isEmpty
                        ? null
                        : () {
                            ref.read(rotationProvider.notifier).rotateNow();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Rotated to next proxy')),
                            );
                          },
                    icon: const Icon(Icons.autorenew),
                    label: const Text('Rotate Proxy Now'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
