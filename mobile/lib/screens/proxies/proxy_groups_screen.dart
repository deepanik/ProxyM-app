import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/proxy_provider.dart';

class ProxyGroupsScreen extends ConsumerWidget {
  const ProxyGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxies = ref.watch(proxyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Proxy Groups')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('All Proxies'),
            subtitle: Text('${proxies.length} proxies'),
            onTap: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
