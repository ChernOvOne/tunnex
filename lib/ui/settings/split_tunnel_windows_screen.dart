import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/app_scanner_windows.dart';
import '../../data/preferences/app_preferences.dart';
import '../../data/providers.dart';
import '../theme/app_theme.dart';

class SplitTunnelWindowsScreen extends ConsumerStatefulWidget {
  const SplitTunnelWindowsScreen({super.key});

  @override
  ConsumerState<SplitTunnelWindowsScreen> createState() => _State();
}

class _State extends ConsumerState<SplitTunnelWindowsScreen> {
  late List<String> _domains;
  late bool _isSelected;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(appPreferencesProvider);
    _domains = prefs.vpnDomains.toList();
    _isSelected = prefs.windowsSplitMode == 'selected';
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider);
    final isSelected = _isSelected;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await _save();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Раздельный доступ'),
        actions: [
          TextButton(
            onPressed: () { _save(); Navigator.pop(context); },
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Mode selector
          const Text(
            'Какие сайты идут через VPN?',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          _modeCard(
            icon: Icons.public,
            title: 'Все сайты',
            subtitle: 'Весь трафик через VPN',
            active: !isSelected,
            onTap: () async {
              _isSelected = false;
              await prefs.setWindowsSplitMode('all');
              await prefs.setVpnDomains(_domains);
              debugPrint('MODE SET: all');
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          _modeCard(
            icon: Icons.checklist,
            title: 'Только выбранные',
            subtitle: 'VPN только для указанных сайтов',
            active: isSelected,
            onTap: () async {
              _isSelected = true;
              await prefs.setWindowsSplitMode('selected');
              await prefs.setVpnDomains(_domains);
              debugPrint('MODE SET: selected');
              setState(() {});
            },
          ),

          if (isSelected) ...[
            const SizedBox(height: 24),
            const Text(
              'Сайты через VPN',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Только эти домены будут идти через VPN. Остальные — напрямую.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),

            // Add domain
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'example.com',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      isDense: true,
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    onSubmitted: (_) => _addDomain(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                  onPressed: _addDomain,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quick add buttons
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _quickAdd('YouTube', ['youtube.com', 'googlevideo.com', 'ytimg.com']),
                _quickAdd('Instagram', ['instagram.com', 'cdninstagram.com']),
                _quickAdd('Twitter/X', ['twitter.com', 'x.com', 'twimg.com']),
                _quickAdd('TikTok', ['tiktok.com', 'tiktokcdn.com']),
                _quickAdd('Discord', ['discord.com', 'discord.gg', 'discordapp.com']),
                _quickAdd('AI', ['openai.com', 'chatgpt.com', 'claude.ai', 'anthropic.com']),
                _quickAdd('Spotify', ['spotify.com', 'scdn.co']),
                _quickAdd('Netflix', ['netflix.com', 'nflxvideo.net']),
              ],
            ),
            const SizedBox(height: 12),

            // Scan running apps
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _scanApps,
                icon: const Icon(Icons.radar, size: 18),
                label: const Text('Сканировать запущенные приложения'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.surfaceLight),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Domain list
            Text(
              '${_domains.length} доменов',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            ..._domains.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.language, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(d, style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _domains.remove(d)),
                      child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )),

            const SizedBox(height: 16),
            // Reset to defaults
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _domains = AppPreferences.defaultVpnDomains.toList();
                });
              },
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Сбросить по умолчанию'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _modeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: active ? Border.all(color: AppColors.primary, width: 1.5) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? AppColors.primary : AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500,
                    color: active ? AppColors.textPrimary : AppColors.textSecondary)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (active)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _quickAdd(String label, List<String> domains) {
    final allAdded = domains.every((d) => _domains.contains(d));
    return GestureDetector(
      onTap: () {
        setState(() {
          if (allAdded) {
            _domains.removeWhere((d) => domains.contains(d));
          } else {
            for (final d in domains) {
              if (!_domains.contains(d)) _domains.add(d);
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: allAdded ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          allAdded ? '$label ✓' : '+ $label',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: allAdded ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _scanApps() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    final apps = await AppScannerWindows.getRunningApps();
    if (!mounted) return;
    Navigator.pop(context); // close loading

    if (apps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Приложения не найдены'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    // Show app picker
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Запущенные приложения'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: ListView.builder(
            itemCount: apps.length,
            itemBuilder: (_, i) {
              final app = apps[i];
              final hasKnown = app.knownDomains.isNotEmpty;
              return ListTile(
                leading: Icon(
                  hasKnown ? Icons.apps : Icons.help_outline,
                  color: hasKnown ? AppColors.primary : AppColors.textMuted,
                ),
                title: Text(app.displayName,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  hasKnown
                      ? '${app.knownDomains.length} доменов известно'
                      : 'Нажмите для сканирования',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                trailing: hasKnown
                    ? IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 22),
                        onPressed: () {
                          setState(() {
                            for (final d in app.knownDomains) {
                              if (!_domains.contains(d)) _domains.add(d);
                            }
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Добавлено: ${app.knownDomains.join(", ")}',
                                  style: const TextStyle(color: AppColors.textPrimary)),
                              backgroundColor: AppColors.surface,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      )
                    : IconButton(
                        icon: const Icon(Icons.radar, color: AppColors.accent, size: 22),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          // Scan this app's connections
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                          );
                          final domains = await AppScannerWindows.scanProcessConnections(app.pid);
                          if (!mounted) return;
                          Navigator.pop(context);
                          if (domains.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Соединения не найдены. Откройте приложение и попробуйте снова.'),
                                  behavior: SnackBarBehavior.floating),
                            );
                          } else {
                            setState(() {
                              for (final d in domains) {
                                if (!_domains.contains(d)) _domains.add(d);
                              }
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Найдено: ${domains.join(", ")}',
                                    style: const TextStyle(color: AppColors.textPrimary)),
                                backgroundColor: AppColors.surface,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  void _addDomain() {
    final domain = _controller.text.trim().toLowerCase()
        .replaceAll('https://', '').replaceAll('http://', '').replaceAll('/', '');
    if (domain.isNotEmpty && domain.contains('.') && !_domains.contains(domain)) {
      setState(() => _domains.add(domain));
      _controller.clear();
    }
  }

  Future<void> _save() async {
    final prefs = ref.read(appPreferencesProvider);
    final mode = _isSelected ? 'selected' : 'all';
    await prefs.setWindowsSplitMode(mode);
    await prefs.setVpnDomains(_domains);
    debugPrint('SAVED: mode=$mode domains=${_domains.length}');
  }
}
