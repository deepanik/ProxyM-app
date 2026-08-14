import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/settings_provider.dart';

class ShellScreen extends ConsumerWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaving = ref.watch(savingStateProvider);
    final errorMsg = ref.watch(saveErrorProvider);
    final currentIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: Column(
        children: [
          if (errorMsg != null)
            MaterialBanner(
              content: Text(errorMsg),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              actions: [
                TextButton(
                  onPressed: () {
                    ref.read(saveErrorProvider.notifier).state = null;
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          if (isSaving)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onItemTapped(index, context),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Proxies'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/proxies')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0; // default to Home
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/proxies');
        break;
      case 2:
        context.go('/settings');
        break;
    }
  }
}
