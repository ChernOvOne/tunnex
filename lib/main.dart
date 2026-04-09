import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'core/deeplink/deeplink_handler.dart';
import 'vpn/auto_failover.dart';
import 'vpn/vpn_service.dart';
import 'data/preferences/app_preferences.dart';
import 'ui/app_shell.dart';
import 'ui/splash_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    windowManager.setTitle('Tunnex VPN');
    windowManager.setMinimumSize(const Size(900, 600));
    windowManager.setSize(const Size(1000, 700));
  } else {
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

class _TunnexAppState extends ConsumerState<TunnexApp> with WindowListener {
  bool _showSplash = true;
  final SystemTray _tray = SystemTray();

  @override
  void initState() {
    super.initState();
    ref.read(deeplinkHandlerProvider).init();
    ref.read(autoFailoverProvider);

    if (Platform.isWindows) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
      _initTray();
    }
  }

  Future<void> _initTray() async {
    await _tray.initSystemTray(
      title: 'Tunnex VPN',
      iconPath: 'assets/icons/logo.png',
      toolTip: 'Tunnex VPN — Отключено',
    );

    await _tray.setContextMenu([
      MenuItem(label: 'Показать', onClicked: () async {
        await windowManager.show();
        await windowManager.focus();
      }),
      MenuSeparator(),
      MenuItem(label: 'Выход', onClicked: () async {
        final vpn = ref.read(vpnStateProvider.notifier);
        await vpn.disconnect();
        await windowManager.setPreventClose(false);
        await windowManager.close();
        exit(0);
      }),
    ]);

    _tray.registerSystemTrayEventHandler((eventName) {
      if (eventName == 'click' || eventName == 'double-click') {
        windowManager.show();
        windowManager.focus();
      } else if (eventName == 'right-click') {
        _tray.popUpContextMenu();
      }
    });

    // Update tray tooltip based on VPN state
    ref.listen(vpnStateProvider, (prev, next) {
      final status = switch (next) {
        VpnState.connected => 'Подключено',
        VpnState.connecting => 'Подключение...',
        VpnState.disconnecting => 'Отключение...',
        VpnState.disconnected => 'Отключено',
      };
      _tray.setToolTip('Tunnex VPN — $status');
    });
  }

  @override
  void onWindowClose() async {
    // Check if user wants to minimize to tray or really exit
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      // User clicked X — minimize to tray
      await windowManager.hide();
    }
  }

  @override
  void onWindowEvent(String eventName) {
    // Allow system shutdown/restart
    if (eventName == 'close') {
      // Don't block — let system close
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
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
