import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../../core/config/xray_config.dart';
import '../../core/config/xray_config_windows.dart';
import '../../core/model/server_config.dart';
import '../../core/ping/server_ping.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/preferences/app_preferences.dart';
import '../../data/providers.dart';
import '../../data/repository/server_repository.dart';
import '../../vpn/traffic_stats.dart';
import '../../vpn/vpn_service.dart';
import '../components/qr_scanner_screen.dart';
import '../components/qr_share_dialog.dart';
import '../components/connect_button.dart';
import '../components/server_card.dart';
import '../components/subscription_card.dart';
import '../theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  bool _isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width > 800;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpnState = ref.watch(vpnStateProvider);
    final activeSub = ref.watch(activeSubscriptionProvider);
    final servers = ref.watch(filteredServersProvider);
    final selectedId = ref.watch(selectedServerIdProvider);
    final selectedServer = ref.watch(selectedServerProvider);

    if (_isDesktop(context)) {
      return _buildDesktopLayout(context, ref, vpnState, activeSub, servers, selectedId, selectedServer);
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                  ),
                ),
                child: const Icon(Icons.shield_rounded,
                    size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text('Tunnex'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 26),
              onPressed: () => _showAddSubscriptionDialog(context, ref),
              tooltip: 'Добавить подписку',
            ),
          ],
        ),

        // Subscription card
        if (activeSub != null)
          SliverToBoxAdapter(
            child: SubscriptionCard(
              subscription: activeSub,
              isActive: true,
              onRefresh: () => _refreshSub(context, ref, activeSub.id),
              onShare: () => QrShareDialog.show(
                context,
                data: activeSub.url,
                title: activeSub.name,
              ),
            ),
          ),

        // Connect section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                // Status with animation
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Row(
                    key: ValueKey(vpnState),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (vpnState == VpnState.connecting || vpnState == VpnState.disconnecting)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                          ),
                        ),
                      if (vpnState == VpnState.connected)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.check_circle, size: 18, color: AppColors.success),
                        ),
                      Text(
                        _statusText(vpnState),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          color: vpnState == VpnState.connected
                              ? AppColors.success
                              : vpnState == VpnState.connecting
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Connect button
                ConnectButton(
                  isConnected: vpnState == VpnState.connected,
                  isConnecting: vpnState == VpnState.connecting ||
                      vpnState == VpnState.disconnecting,
                  onTap: () => _toggleVpn(context, ref, vpnState),
                ),
                const SizedBox(height: 16),

                // Selected server name
                if (selectedServer != null)
                  Column(
                    children: [
                      Text(
                        selectedServer.remarks.isNotEmpty
                            ? selectedServer.remarks
                            : '${selectedServer.address}:${selectedServer.port}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${selectedServer.protocol.displayName} • ${selectedServer.network}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'Сервер не выбран',
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ),

        // Speed display (when connected)
        if (vpnState == VpnState.connected)
          SliverToBoxAdapter(
            child: _TrafficDisplay(),
          ),

        // Server list header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Серверы (${servers.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    // Ping all
                    TextButton.icon(
                      onPressed: servers.isNotEmpty
                          ? () => _pingAll(context, ref, servers)
                          : null,
                      icon: const Icon(Icons.speed, size: 18),
                      label: const Text('Тест'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary),
                    ),
                    // Auto-select
                    TextButton.icon(
                      onPressed: servers.isNotEmpty
                          ? () => _autoSelect(context, ref, servers)
                          : null,
                      icon: const Icon(Icons.flash_on, size: 18),
                      label: const Text('Авто'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.accent),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Empty state
        if (servers.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.dns_outlined, size: 48, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'Нет серверов',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Добавьте подписку для начала работы',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final server = servers[index];
                return ServerCard(
                  server: server,
                  isSelected: server.id == selectedId,
                  onTap: () => _selectServer(context, ref, server.id),
                );
              },
              childCount: servers.length,
            ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  String _statusText(VpnState state) {
    switch (state) {
      case VpnState.disconnected:
        return 'ОТКЛЮЧЕНО';
      case VpnState.connecting:
        return 'ПОДКЛЮЧЕНИЕ...';
      case VpnState.connected:
        return 'ПОДКЛЮЧЕНО';
      case VpnState.disconnecting:
        return 'ОТКЛЮЧЕНИЕ...';
    }
  }

  void _toggleVpn(BuildContext context, WidgetRef ref, VpnState currentState) async {
    if (currentState == VpnState.connected ||
        currentState == VpnState.connecting) {
      ref.read(vpnStateProvider.notifier).disconnect();
      return;
    }

    final server = ref.read(selectedServerProvider);
    if (server == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите сервер для подключения'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Generate config FRESH — force reload SharedPreferences from disk
    final sp = await SharedPreferences.getInstance();
    await sp.reload();
    final prefs = ref.read(appPreferencesProvider);
    final splitMode = sp.getString('windows_split_mode') ?? 'all';
    final vpnDomains = sp.getStringList('vpn_domains') ?? prefs.vpnDomains;
    String winMode = prefs.windowsVpnMode;
    // Detect real network interface (Ethernet, Wi-Fi, WLAN etc.)
    String realIface = 'Ethernet';
    if (Platform.isWindows) {
      try {
        final r = await Process.run('powershell', ['-Command',
          "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
          "(Get-NetAdapter | Where-Object {"
          "(\$_.Status -eq 'Up') -and "
          "(\$_.Name -notlike 'tunnex*') -and "
          "(\$_.Name -notlike '*Clash*') -and "
          "(\$_.Name -notlike '*Tunnel*') -and "
          "(\$_.Name -notlike '*tun*') -and "
          "(\$_.InterfaceDescription -notlike '*Virtual*')"
          "} | Sort-Object LinkSpeed -Descending | Select-Object -First 1).Name"
        ], stdoutEncoding: const Utf8Codec(allowMalformed: true));
        final name = (r.stdout as String).trim();
        if (name.isNotEmpty) realIface = name;
        debugPrint('Detected interface: $realIface');
      } catch (_) {}
    }
    debugPrint('CONNECT: splitMode=$splitMode winMode=$winMode iface=$realIface domains=${vpnDomains.length}');
    final Map<String, dynamic> config;
    if (Platform.isWindows) {
      config = XrayConfigWindows.generate(
        server: server,
        dnsServer: prefs.dnsServer,
        splitMode: splitMode,
        vpnDomains: vpnDomains,
        mode: winMode == 'tun' ? WindowsVpnMode.tun : WindowsVpnMode.systemProxy,
        realInterface: realIface,
      );
    } else {
      config = XrayConfig.generate(
        server: server,
        dnsServer: prefs.dnsServer,
      );
    }

    try {
      await ref.read(vpnStateProvider.notifier).connect(
            jsonEncode(config),
            core: 'xray',
            splitBypass: prefs.splitTunnelBypassMode,
            splitApps: prefs.splitTunnelApps,
            windowsMode: winMode,
            serverName: server.remarks.isNotEmpty
                ? server.remarks
                : '${server.protocol.displayName} • ${server.address}',
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Ошибка: $e',
                    style: const TextStyle(color: AppColors.textPrimary),
                    maxLines: 3, overflow: TextOverflow.ellipsis)),
              ],
            ),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildDesktopLayout(BuildContext context, WidgetRef ref, VpnState vpnState, dynamic activeSub, List<ServerConfig> servers, String? selectedId, ServerConfig? selectedServer) {
    return Row(
      children: [
        // LEFT: Subscription + Servers list
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full subscription card (same as mobile)
              if (activeSub != null)
                SubscriptionCard(
                  subscription: activeSub,
                  isActive: true,
                  onRefresh: () => _refreshSub(context, ref, activeSub.id),
                  onShare: () => QrShareDialog.show(context, data: activeSub.url, title: activeSub.name),
                ),
              // Server list header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Text('Серверы (${servers.length})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.speed, size: 18, color: AppColors.textSecondary),
                      onPressed: servers.isNotEmpty ? () => _pingAll(context, ref, servers) : null,
                      tooltip: 'Тест пинга',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.flash_on, size: 18, color: AppColors.accent),
                      onPressed: servers.isNotEmpty ? () => _autoSelect(context, ref, servers) : null,
                      tooltip: 'Авто-выбор',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      onPressed: () => _showAddSubscriptionDialog(context, ref),
                      tooltip: 'Добавить подписку',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              // Servers
              Expanded(
                child: servers.isEmpty
                    ? const Center(child: Text('Добавьте подписку', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        itemCount: servers.length,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemBuilder: (context, index) {
                          final server = servers[index];
                          return _DesktopServerTile(
                            server: server,
                            isSelected: server.id == selectedId,
                            onTap: () => _selectServer(context, ref, server.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: AppColors.surfaceLight),
        // RIGHT: Connect button + server info
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Connect button
                ConnectButton(
                  isConnected: vpnState == VpnState.connected,
                  isConnecting: vpnState == VpnState.connecting || vpnState == VpnState.disconnecting,
                  onTap: () => _toggleVpn(context, ref, vpnState),
                ),
                const SizedBox(height: 16),
                // Server name
                if (selectedServer != null) ...[
                  Text(
                    selectedServer.remarks.isNotEmpty ? selectedServer.remarks : selectedServer.address,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${selectedServer.protocol.displayName} • ${selectedServer.network}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ] else
                  const Text('Выберите сервер', style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 16),
                // Status with animation
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Row(
                    key: ValueKey(vpnState),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (vpnState == VpnState.connecting || vpnState == VpnState.disconnecting)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                          ),
                        ),
                      if (vpnState == VpnState.connected)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.check_circle, size: 16, color: AppColors.success),
                        ),
                      Text(
                        _statusText(vpnState),
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1,
                          color: vpnState == VpnState.connected ? AppColors.success
                              : vpnState == VpnState.connecting ? AppColors.accent
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Traffic
                if (vpnState == VpnState.connected) _TrafficDisplay(),
                const SizedBox(height: 16),
                // TUN / Proxy toggle (Windows)
                if (Platform.isWindows) _WindowsModeToggle(),
                const Spacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _selectServer(BuildContext context, WidgetRef ref, String serverId) {
    final vpnState = ref.read(vpnStateProvider);
    ref.read(selectedServerIdProvider.notifier).state = serverId;
    ref.read(appPreferencesProvider).setSelectedServerId(serverId);

    // Auto-connect or reconnect
    if (vpnState == VpnState.connected || vpnState == VpnState.connecting) {
      // Reconnect with new server
      ref.read(vpnStateProvider.notifier).disconnect();
      Future.delayed(const Duration(milliseconds: 500), () {
        _toggleVpn(context, ref, VpnState.disconnected);
      });
    } else {
      // Auto-connect
      _toggleVpn(context, ref, VpnState.disconnected);
    }
  }

  PingMethod _getCurrentPingMethod(WidgetRef ref) {
    final name = ref.read(appPreferencesProvider).pingMethod;
    return PingMethod.values.firstWhere(
      (m) => m.name == name,
      orElse: () => PingMethod.tcp,
    );
  }

  void _autoSelect(BuildContext context, WidgetRef ref, List<ServerConfig> servers) async {
    if (servers.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Поиск лучшего сервера...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    // Ping all servers with selected method
    final method = _getCurrentPingMethod(ref);
    final results = await ServerPing.pingAll(servers, method: method, timeoutMs: 3000);
    final repo = ref.read(serverRepositoryProvider);

    // Update ping results
    for (final entry in results.entries) {
      final s = servers.where((s) => s.id == entry.key).firstOrNull;
      if (s != null) await repo.update(s.copyWith(testResult: entry.value));
    }
    ref.invalidate(serversProvider);

    // Pick fastest alive server
    final alive = results.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (alive.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нет доступных серверов'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final bestId = alive.first.key;
    final best = servers.firstWhere((s) => s.id == bestId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Лучший: ${best.remarks.isNotEmpty ? best.remarks : best.address} (${alive.first.value}мс)'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      // Auto-connect to best server
      _selectServer(context, ref, bestId);
    }
  }

  void _pingAll(BuildContext context, WidgetRef ref, List<ServerConfig> servers) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Тестирование серверов...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );

    final method = _getCurrentPingMethod(ref);
    final results = await ServerPing.pingAll(servers, method: method);
    final repo = ref.read(serverRepositoryProvider);

    for (final entry in results.entries) {
      final server = servers.where((s) => s.id == entry.key).firstOrNull;
      if (server != null) {
        await repo.update(server.copyWith(testResult: entry.value));
      }
    }

    ref.invalidate(serversProvider);
  }

  void _refreshSub(BuildContext context, WidgetRef ref, String subId) async {
    final result = await ref.read(subscriptionsProvider.notifier).refresh(subId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result != null ? Icons.check_circle : Icons.error_outline,
                color: result != null ? AppColors.success : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(result != null
                  ? 'Подписка обновлена (${result.servers.length} серверов)'
                  : 'Не удалось обновить',
                  style: const TextStyle(color: AppColors.textPrimary)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAddSubscriptionDialog(BuildContext context, WidgetRef ref) {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить подписку'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Вставьте ссылку на подписку от провайдера',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: 'https://...',
                hintStyle: TextStyle(color: AppColors.textMuted),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        urlController.text = data!.text!;
                        // Clear clipboard for security
                        Clipboard.setData(const ClipboardData(text: ''));
                      }
                    },
                    icon: const Icon(Icons.content_paste, size: 18),
                    label: const Text('Буфер'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.surfaceLight),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final result = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                      );
                      if (result != null && context.mounted) {
                        ref.read(subscriptionsProvider.notifier).add(result);
                      }
                    },
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('QR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.surfaceLight),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(ctx);
              final error = await ref.read(subscriptionsProvider.notifier).add(url);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}

/// Remove emoji that Windows can't render, keep text
String _cleanServerName(String name) {
  if (!Platform.isWindows) return name;
  // Remove surrogate pairs (emoji) but keep basic unicode
  return name.replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}]|[\u{2600}-\u{27BF}]|[\u{FE00}-\u{FE0F}]|[\u{1F900}-\u{1F9FF}]|[\u{200D}]|[\u{20E3}]|[\u{E0020}-\u{E007F}]|[\u{FE0F}]', unicode: true), '').trim();
}

class _DesktopServerTile extends StatelessWidget {
  final ServerConfig server;
  final bool isSelected;
  final VoidCallback onTap;

  const _DesktopServerTile({
    required this.server,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1) : null,
        ),
        child: Row(
          children: [
            // Server name with emoji support
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _cleanServerName(server.remarks.isNotEmpty ? server.remarks : server.address),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    server.protocol.displayName,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            // Ping
            if (server.testResult > 0)
              Text(
                '${server.testResult}ms',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: server.testResult < 200 ? AppColors.success
                      : server.testResult < 500 ? AppColors.warning : AppColors.error,
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _TrafficDisplay extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(trafficStatsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Speed row
            Row(
              children: [
                Expanded(
                  child: _speedItem(
                    Icons.arrow_upward_rounded,
                    'Отправка',
                    _formatSpeed(stats.uploadSpeed),
                    AppColors.accent,
                  ),
                ),
                const SizedBox(
                  height: 36,
                  child: VerticalDivider(color: AppColors.surfaceLight, width: 1),
                ),
                Expanded(
                  child: _speedItem(
                    Icons.arrow_downward_rounded,
                    'Загрузка',
                    _formatSpeed(stats.downloadSpeed),
                    AppColors.success,
                  ),
                ),
              ],
            ),
            // Session total
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.data_usage, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Сессия: ↑ ${_formatBytes(stats.totalUpload)}  ↓ ${_formatBytes(stats.totalDownload)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _speedItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  static String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec < 1024) return '$bytesPerSec Б/с';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} КБ/с';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} МБ/с';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} ГБ';
  }
}

class _WindowsModeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final isTun = prefs.windowsVpnMode == 'tun';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeButton('Proxy', !isTun, () {
            prefs.setWindowsVpnMode('systemProxy');
            (context as Element).markNeedsBuild();
          }),
          const SizedBox(width: 4),
          _modeButton('TUN', isTun, () {
            prefs.setWindowsVpnMode('tun');
            (context as Element).markNeedsBuild();
          }),
        ],
      ),
    );
  }

  Widget _modeButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
