import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io';

import '../../core/ping/server_ping.dart';
import '../../data/preferences/app_preferences.dart';
import '../theme/app_theme.dart';
import 'split_tunnel_screen.dart';
import 'split_tunnel_windows_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider);

    return SafeArea(
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [

        // --- Subscriptions ---
        _sectionTitle('Подписки'),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.sync_outlined,
          title: 'Автообновление',
          subtitle: prefs.autoRefreshMinutes == 0
              ? 'Выключено'
              : 'Каждые ${prefs.autoRefreshMinutes} мин.',
          onTap: () => _showRefreshIntervalDialog(context, prefs),
        ),

        const SizedBox(height: 24),

        // --- Network ---
        _sectionTitle('Сеть'),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.dns_outlined,
          title: 'DNS сервер',
          subtitle: prefs.dnsServer,
          onTap: () => _showDnsDialog(context, prefs),
        ),

        const SizedBox(height: 24),

        // --- VPN Mode ---
        _sectionTitle('Режим VPN'),
        const SizedBox(height: 8),

        // App split tunnel (Android only)
        if (!Platform.isWindows) ...[
          _tile(
            icon: prefs.splitTunnelBypassMode ? Icons.public : Icons.app_shortcut,
            title: prefs.splitTunnelBypassMode
                ? 'Все приложения через VPN'
                : 'Выбранные приложения',
            subtitle: prefs.splitTunnelBypassMode
                ? 'Весь трафик на устройстве защищён'
                : 'Только выбранные приложения через VPN',
            onTap: () => _showVpnModeDialog(context, prefs),
          ),
          const SizedBox(height: 6),
          if (!prefs.splitTunnelBypassMode)
            _tile(
              icon: Icons.checklist_outlined,
              title: 'Изменить список',
              subtitle: 'Выберите приложения для VPN',
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SplitTunnelScreen()));
                setState(() {});
              },
            ),
          const SizedBox(height: 6),
        ],

        // Domain split tunnel (Windows only — Android uses app-level split)
        if (Platform.isWindows)
          _tile(
            icon: prefs.windowsSplitMode == 'all' ? Icons.shield : Icons.tune,
            title: prefs.windowsSplitMode == 'all'
                ? 'Всё через VPN'
                : 'Только выбранное через VPN',
            subtitle: prefs.windowsSplitMode == 'all'
                ? 'Весь трафик защищён'
                : 'Сайты и приложения по выбору',
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SplitTunnelWindowsScreen()));
              setState(() {});
            },
          ),

        const SizedBox(height: 24),

        // --- General ---
        _sectionTitle('Общие'),
        const SizedBox(height: 8),
        _toggleTile(
          icon: Icons.power_settings_new_outlined,
          title: 'Автозапуск при загрузке',
          value: prefs.autoConnect,
          onChanged: (v) {
            prefs.setAutoConnect(v);
            setState(() {});
          },
        ),

        const SizedBox(height: 24),

        // --- Ping ---
        _sectionTitle('Проверка серверов'),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.speed_outlined,
          title: 'Метод проверки',
          subtitle: _pingMethodName(prefs.pingMethod),
          onTap: () => _showPingMethodDialog(context, prefs),
        ),

        const SizedBox(height: 24),

        // --- FAQ ---
        _sectionTitle('FAQ'),
        const SizedBox(height: 8),
        _faqItem(
          'VPN отключается в фоне',
          'На Huawei/Xiaomi/Samsung система может убивать приложение в фоне.\n\n'
              'Решение:\n'
              '1. Настройки → Батарея → Запуск приложений → Tunnex → Управлять вручную\n'
              '2. Включите: Автозапуск, Косвенный запуск, Работа в фоне\n'
              '3. Отключите оптимизацию батареи для Tunnex',
        ),
        _faqItem(
          'Telegram не работает после блокировки экрана',
          'Телефон замораживает приложение во сне. После разблокировки VPN-соединения восстанавливаются.\n\n'
              'Для решения:\n'
              '1. Разрешите автозапуск Tunnex\n'
              '2. На Huawei: Настройки → Батарея → Запуск приложений → Tunnex → все три галочки',
        ),
        _faqItem(
          'Как работает автоматический выбор сервера?',
          'Приложение тестирует все серверы и выбирает самый быстрый.\n\n'
              'При включённом автоматическом режиме:\n'
              '• Серверы проверяются каждые 30 секунд\n'
              '• Если текущий сервер упал — мгновенное переключение\n'
              '• При смене WiFi/LTE — автоматический перезапуск',
        ),
        _faqItem(
          'Что значит «Защитить всё» и «Только нужное»?',
          '«Защитить всё» — весь интернет-трафик проходит через VPN.\n\n'
              '«Только нужное» — через VPN работают только выбранные приложения '
              '(YouTube, Telegram и др.). Остальные используют обычный интернет.',
        ),
        _faqItem(
          'YouTube/Instagram медленно загружается',
          'Если используете транспорт XHTTP — первые 10-20 секунд '
              'соединение «прогревается». Это нормально.\n\n'
              'Попробуйте другой сервер или транспорт (TCP, WebSocket, gRPC).',
        ),
        _faqItem(
          'Серверы не работают на мобильном интернете',
          'Некоторые серверы могут быть заблокированы оператором на LTE.\n\n'
              'Включите автоматический выбор — приложение найдёт рабочий сервер.',
        ),

        const SizedBox(height: 24),

        // --- About ---
        _sectionTitle('О приложении'),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.info_outline,
          title: 'Tunnex',
          subtitle: 'v1.0.0 • xray-core',
          onTap: () {},
        ),
      ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showVpnModeDialog(BuildContext context, AppPreferences prefs) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Режим VPN'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              prefs.setSplitTunnelBypassMode(true);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: ListTile(
              leading: Icon(
                Icons.public,
                color: prefs.splitTunnelBypassMode
                    ? AppColors.primary
                    : AppColors.textMuted,
              ),
              title: const Text('Все приложения',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
              subtitle: const Text(
                  'Весь трафик через VPN.\nМаксимальная защита.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: prefs.splitTunnelBypassMode
                  ? const Icon(Icons.check_circle, color: AppColors.primary)
                  : null,
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              prefs.setSplitTunnelBypassMode(false);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: ListTile(
              leading: Icon(
                Icons.app_shortcut,
                color: !prefs.splitTunnelBypassMode
                    ? AppColors.primary
                    : AppColors.textMuted,
              ),
              title: const Text('Только выбранные',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
              subtitle: const Text(
                  'VPN только для нужных приложений.\nЭкономит трафик.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: !prefs.splitTunnelBypassMode
                  ? const Icon(Icons.check_circle, color: AppColors.primary)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _faqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: Theme(
          data: ThemeData(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding:
                const EdgeInsets.fromLTRB(14, 0, 14, 14),
            iconColor: AppColors.textMuted,
            collapsedIconColor: AppColors.textMuted,
            title: Text(
              question,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            children: [
              Text(
                answer,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDnsDialog(BuildContext context, AppPreferences prefs) {
    final dnsOptions = {
      '8.8.8.8': 'Google',
      '1.1.1.1': 'Cloudflare',
      '9.9.9.9': 'Quad9',
      '208.67.222.222': 'OpenDNS',
    };
    final current = prefs.dnsServer;

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('DNS сервер'),
        children: dnsOptions.entries.map((e) {
          return SimpleDialogOption(
            onPressed: () {
              prefs.setDnsServer(e.key);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: Row(
              children: [
                Icon(
                  current == e.key
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: current == e.key
                      ? AppColors.primary
                      : AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.value,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500)),
                    Text(e.key,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _pingMethodName(String method) {
    return PingMethod.values
        .firstWhere((m) => m.name == method, orElse: () => PingMethod.tcp)
        .displayName;
  }

  void _showRefreshIntervalDialog(BuildContext context, AppPreferences prefs) {
    final options = {0: 'Выключено', 30: '30 минут', 60: '1 час', 120: '2 часа', 360: '6 часов'};
    final current = prefs.autoRefreshMinutes;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Автообновление подписок'),
        children: options.entries.map((e) => SimpleDialogOption(
          onPressed: () {
            prefs.setAutoRefreshMinutes(e.key);
            Navigator.pop(ctx);
            setState(() {});
          },
          child: Row(children: [
            Icon(current == e.key ? Icons.radio_button_checked : Icons.radio_button_off,
                color: current == e.key ? AppColors.primary : AppColors.textMuted, size: 20),
            const SizedBox(width: 12),
            Text(e.value, style: const TextStyle(color: AppColors.textPrimary)),
          ]),
        )).toList(),
      ),
    );
  }

  void _showPingMethodDialog(BuildContext context, AppPreferences prefs) {
    final current = prefs.pingMethod;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Метод проверки'),
        children: PingMethod.values.map((m) {
          return SimpleDialogOption(
            onPressed: () {
              prefs.setPingMethod(m.name);
              Navigator.pop(ctx);
              setState(() {});
            },
            child: ListTile(
              leading: Icon(
                current == m.name
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: current == m.name
                    ? AppColors.primary
                    : AppColors.textMuted,
                size: 20,
              ),
              title: Text(m.displayName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
              subtitle: Text(m.description,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
