import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/settings_provider.dart';

enum ConnectionStateStatus { closed, waiting, connected }

class ConnectionStatusCard extends ConsumerWidget {
  const ConnectionStatusCard({super.key});

  ConnectionStateStatus _getConnectionStatus(bool enabled, String? activeId) {
    if (!enabled) return ConnectionStateStatus.closed;
    return activeId != null ? ConnectionStateStatus.connected : ConnectionStateStatus.waiting;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final activeProxy = ref.watch(activeProxyProvider);
    final status = _getConnectionStatus(settings.enabled, activeProxy?.id);

    Color color;
    IconData icon;
    String title;
    String subtitle;

    switch (status) {
      case ConnectionStateStatus.closed:
        color = Colors.grey;
        icon = Icons.shield_outlined;
        title = 'Proxy Disconnected';
        subtitle = 'Toggle proxy manager to enable connection';
        break;
      case ConnectionStateStatus.waiting:
        color = Colors.orange;
        icon = Icons.hourglass_top;
        title = 'Waiting for Proxy';
        subtitle = 'Select an active proxy from your list';
        break;
      case ConnectionStateStatus.connected:
        color = Colors.green;
        icon = Icons.verified_user_outlined;
        title = 'Proxy Connected';
        subtitle = '${activeProxy!.protocol.name.toUpperCase()} • ${activeProxy.host}:${activeProxy.port}';
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Spacer(),
                      Switch(
                        value: settings.enabled,
                        onChanged: (val) {
                          ref.read(settingsProvider.notifier).toggleEnabled();
                        },
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
