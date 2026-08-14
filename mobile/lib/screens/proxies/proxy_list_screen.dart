import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/proxy_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/proxy_entry.dart';

class ProxyListScreen extends ConsumerWidget {
  const ProxyListScreen({super.key});

  Color _getProtocolColor(ProxyProtocol protocol) {
    switch (protocol) {
      case ProxyProtocol.http:
        return Colors.blue;
      case ProxyProtocol.https:
        return Colors.green;
      case ProxyProtocol.socks4:
        return Colors.orange;
      case ProxyProtocol.socks5:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxies = ref.watch(proxyProvider);
    final activeProxy = ref.watch(activeProxyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Proxies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All',
            onPressed: proxies.isEmpty
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear All Proxies?'),
                        content: const Text('Are you sure you want to remove all proxies?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              ref.read(proxyProvider.notifier).clearAllProxies();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Groups',
            onPressed: () => context.push('/proxies/groups'),
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Import',
            onPressed: () => context.push('/proxies/import'),
          ),
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: 'Bulk Test',
            onPressed: () => context.push('/proxies/bulk-test'),
          ),
        ],
      ),
      body: proxies.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No proxies added yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: proxies.length,
              itemBuilder: (context, index) {
                final proxy = proxies[index];
                final isActive = activeProxy?.id == proxy.id;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isActive
                        ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    onTap: () {
                      ref.read(proxyProvider.notifier).setActive(proxy.id);
                    },
                    leading: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          backgroundColor: _getProtocolColor(proxy.protocol).withValues(alpha: 0.15),
                          child: Icon(Icons.public, color: _getProtocolColor(proxy.protocol)),
                        ),
                        if (isActive)
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${proxy.host}:${proxy.port}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            proxy.protocol.name.toUpperCase(),
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          backgroundColor: _getProtocolColor(proxy.protocol),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        if (proxy.username != null) ...[
                          const Icon(Icons.lock, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(proxy.username!, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          'Status: ${proxy.testResult?.status.name ?? "untested"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          tooltip: 'Test Proxy',
                          onPressed: () => context.push('/proxies/test/${proxy.id}'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          tooltip: 'Remove',
                          onPressed: () {
                            ref.read(proxyProvider.notifier).removeProxy(proxy.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/proxies/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
