import 'dart:io';

import 'package:flutter/material.dart';

import 'home/home_screen.dart';
import 'settings/settings_screen.dart';
import 'subscription/subscription_screen.dart';
import 'theme/app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    SubscriptionScreen(),
    SettingsScreen(),
  ];

  bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Desktop: side navigation rail for wide screens
    if (_isDesktop && width > 800) {
      return Scaffold(
        body: Row(
          children: [
            // Side rail
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.primary.withValues(alpha: 0.2),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                        ),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          size: 20, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text('Tunnex',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted)),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Главная'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.cloud_outlined),
                  selectedIcon: Icon(Icons.cloud),
                  label: Text('Подписки'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Настройки'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, color: AppColors.surfaceLight),
            // Content
            Expanded(
              child: ClipRect(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile: bottom navigation
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Подписки',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}
