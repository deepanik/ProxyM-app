import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:go_router/go_router.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/proxies/proxy_list_screen.dart';
import 'screens/proxies/add_proxy_screen.dart';
import 'screens/proxies/proxy_test_screen.dart';
import 'screens/proxies/bulk_test_screen.dart';
import 'screens/proxies/proxy_groups_screen.dart';
import 'screens/proxies/import_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/premium_screen.dart';
import 'screens/bypass/bypass_rules_screen.dart';
import 'screens/communication/notifications_screen.dart';
import 'screens/communication/support_list_screen.dart';
import 'screens/communication/chat_screen.dart';
import 'providers/settings_provider.dart';
import 'utils/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.instance.getToken().then((token) {
      print("FCM Token: $token");
    });
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground notification: ${message.notification?.title}');
    });
  } catch (e) {
    print('Initialization failed: $e');
  }

  runApp(const ProviderScope(child: ProxyMApp()));
}

// Router
final _router = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/', builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/auth', builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/auth/register', builder: (c, s) => const RegisterScreen()),
    ShellRoute(
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        GoRoute(
          path: '/home', 
          builder: (c, s) => const HomeScreen(),
          routes: [
            GoRoute(path: 'notifications', builder: (c, s) => const NotificationsScreen()),
            GoRoute(
              path: 'support', 
              builder: (c, s) => const SupportListScreen(),
              routes: [
                GoRoute(path: 'chat', builder: (c, s) => ChatScreen(ticketId: s.extra as int)),
              ]
            ),
          ]
        ),
        GoRoute(
          path: '/proxies', 
          builder: (c, s) => const ProxyListScreen(),
          routes: [
            GoRoute(path: 'add', builder: (c, s) => const AddProxyScreen()),
            GoRoute(path: 'test/:id', builder: (c, s) => ProxyTestScreen(proxyId: s.pathParameters['id']!)),
            GoRoute(path: 'bulk-test', builder: (c, s) => const BulkTestScreen()),
            GoRoute(path: 'groups', builder: (c, s) => const ProxyGroupsScreen()),
            GoRoute(path: 'import', builder: (c, s) => const ImportScreen()),
          ]
        ),
        GoRoute(
          path: '/settings', 
          builder: (c, s) => const SettingsScreen(),
          routes: [
            GoRoute(path: 'premium', builder: (c, s) => const PremiumScreen()),
            GoRoute(path: 'bypass', builder: (c, s) => const BypassRulesScreen()),
          ]
        ),
      ],
    ),
  ],
);

class ProxyMApp extends ConsumerWidget {
  const ProxyMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.theme == 'dark';

    return MaterialApp.router(
      title: 'ProxyM',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
    );
  }
}
