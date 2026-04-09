import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io';

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
        title: const Text('Что идёт через VPN'),
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
            'Выберите что будет работать через VPN — '
            'сайты, приложения и сервисы.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),

          _modeCard(
            icon: Icons.shield,
            title: 'Всё через VPN',
            subtitle: 'Весь интернет-трафик защищён VPN',
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
            icon: Icons.tune,
            title: 'Только выбранное',
            subtitle: 'VPN только для нужных сайтов и приложений, остальное напрямую',
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
            // --- Section 1: Quick add popular services ---
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.star_outline, size: 18, color: AppColors.accent),
                      SizedBox(width: 8),
                      Text('Популярные сервисы', style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Нажмите чтобы добавить или убрать',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [
                      _quickAdd('YouTube', ['youtube.com', 'googlevideo.com', 'ytimg.com']),
                      _quickAdd('Instagram', ['instagram.com', 'cdninstagram.com']),
                      _quickAdd('Twitter/X', ['twitter.com', 'x.com', 'twimg.com']),
                      _quickAdd('TikTok', ['tiktok.com', 'tiktokcdn.com']),
                      _quickAdd('Discord', ['discord.com', 'discord.gg', 'discordapp.com']),
                      _quickAdd('ChatGPT', ['openai.com', 'chatgpt.com']),
                      _quickAdd('Claude AI', ['claude.ai', 'anthropic.com']),
                      _quickAdd('Spotify', ['spotify.com', 'scdn.co']),
                      _quickAdd('Netflix', ['netflix.com', 'nflxvideo.net']),
                      _quickAdd('Telegram', ['telegram.org', 't.me', 'web.telegram.org']),
                      _quickAdd('LinkedIn', ['linkedin.com']),
                      _quickAdd('GitHub', ['github.com', 'githubusercontent.com']),
                      _quickAdd('Steam', ['steampowered.com', 'steamcommunity.com']),
                      _quickAdd('Twitch', ['twitch.tv', 'twitchcdn.net']),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- Section 2: Add manually or from app ---
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Добавить вручную', style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                ],
              ),
            ),
            const SizedBox(height: 12),

            // App tools (Windows only)
            if (Platform.isWindows) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.apps, size: 18, color: AppColors.warning),
                        SizedBox(width: 8),
                        Text('Добавить из приложения', style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Автоматически найдём домены программы',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _scanApps,
                            icon: const Icon(Icons.radar, size: 16),
                            label: const Text('Запущенные'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accent,
                              side: const BorderSide(color: AppColors.surfaceLight),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickExe,
                            icon: const Icon(Icons.folder_open, size: 16),
                            label: const Text('Выбрать .exe'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.surfaceLight),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // --- Section 4: Active list ---
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

  void _pickExe() async {
    // Open file picker via PowerShell
    try {
      final result = await Process.run('powershell', ['-Command',
        "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
        "Add-Type -AssemblyName System.Windows.Forms; "
        "\$d = New-Object System.Windows.Forms.OpenFileDialog; "
        "\$d.Filter = 'Applications (*.exe)|*.exe'; "
        "\$d.Title = 'Выберите приложение'; "
        "if (\$d.ShowDialog() -eq 'OK') { \$d.FileName }"
      ]);

      final exePath = (result.stdout as String).trim();
      if (exePath.isEmpty || !exePath.endsWith('.exe')) return;

      // Extract exe name
      final exeName = exePath.split('\\').last.replaceAll('.exe', '').toLowerCase();

      // Check known mapping
      final known = AppScannerWindows.knownApps;
      if (known.containsKey(exeName) && known[exeName]!.isNotEmpty) {
        setState(() {
          for (final d in known[exeName]!) {
            if (!_domains.contains(d)) _domains.add(d);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Добавлено: ${known[exeName]!.join(", ")}',
                style: const TextStyle(color: AppColors.textPrimary)),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }

      // Unknown app — try to find running process and scan
      final psResult = await Process.run('powershell', ['-Command',
        "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
        "(Get-Process -Name '$exeName' -ErrorAction SilentlyContinue | Select-Object -First 1).Id"
      ]);
      final pidStr = (psResult.stdout as String).trim();
      final pid = int.tryParse(pidStr);

      if (pid != null && pid > 0) {
        // Scan connections
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Сканируем соединения...'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ));
        }
        final domains = await AppScannerWindows.scanProcessConnections(pid);
        if (domains.isNotEmpty) {
          setState(() {
            for (final d in domains) {
              if (!_domains.contains(d)) _domains.add(d);
            }
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Найдено: ${domains.join(", ")}',
                  style: const TextStyle(color: AppColors.textPrimary)),
              backgroundColor: AppColors.surface,
              behavior: SnackBarBehavior.floating,
            ));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Запустите приложение и попробуйте снова'),
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$exeName не запущен. Запустите его и попробуйте снова.'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (_) {}
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
