import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/deeplink/deeplink_handler.dart';
import 'vpn/auto_failover.dart';
import 'data/preferences/app_preferences.dart';
import 'ui/app_shell.dart';
import 'ui/splash_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isWindows) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const TunnexApp(),
    ),
  );
}

class TunnexApp extends ConsumerStatefulWidget {
  const TunnexApp({super.key});

  @override
  ConsumerState<TunnexApp> createState() => _TunnexAppState();
}

class _TunnexAppState extends ConsumerState<TunnexApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    ref.read(deeplinkHandlerProvider).init();
    ref.read(autoFailoverProvider); // Initialize auto-failover
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tunnex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: _showSplash
          ? SplashScreen(
              onComplete: () => setState(() => _showSplash = false),
            )
          : const AppShell(),
    );
  }
}
