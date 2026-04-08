import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preferences/app_preferences.dart';
import '../theme/app_theme.dart';

/// Installed app info fetched from platform
class AppInfo {
  final String packageName;
  final String appName;
  final bool isSystem;

  const AppInfo({
    required this.packageName,
    required this.appName,
    this.isSystem = false,
  });
}

/// Provider to fetch installed apps from platform
final installedAppsProvider = FutureProvider<List<AppInfo>>((ref) async {
  const channel = MethodChannel('com.tunnex/apps');
  try {
    final result = await channel.invokeMethod<List>('getInstalledApps');
    if (result == null) return [];
    return result.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return AppInfo(
        packageName: map['packageName'] as String,
        appName: map['appName'] as String,
        isSystem: map['isSystem'] as bool? ?? false,
      );
    }).toList()
      ..sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
  } catch (_) {
    return [];
  }
});

class SplitTunnelScreen extends ConsumerStatefulWidget {
  const SplitTunnelScreen({super.key});

  @override
  ConsumerState<SplitTunnelScreen> createState() => _SplitTunnelScreenState();
}

class _SplitTunnelScreenState extends ConsumerState<SplitTunnelScreen> {
  late Set<String> _selectedApps;
  String _search = '';
  bool _showSystem = false;

  @override
  void initState() {
    super.initState();
    _selectedApps = ref.read(appPreferencesProvider).splitTunnelApps.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(installedAppsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Приложения'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск приложений...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showSystem ? Icons.apps : Icons.apps_outage,
                    color: _showSystem
                        ? AppColors.primary
                        : AppColors.textMuted,
                    size: 20,
                  ),
                  tooltip: _showSystem
                      ? 'Скрыть системные'
                      : 'Показать системные',
                  onPressed: () =>
                      setState(() => _showSystem = !_showSystem),
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          // Info chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _chip('Выбрано: ${_selectedApps.length}', AppColors.primary),
                const Spacer(),
                TextButton(
                  onPressed: _selectDefaults,
                  child: const Text(
                    'По умолчанию',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // App list
          Expanded(
            child: appsAsync.when(
              data: (apps) {
                var filtered = apps.where((a) {
                  if (!_showSystem && a.isSystem) return false;
                  if (_search.isNotEmpty) {
                    return a.appName
                            .toLowerCase()
                            .contains(_search.toLowerCase()) ||
                        a.packageName
                            .toLowerCase()
                            .contains(_search.toLowerCase());
                  }
                  return true;
                }).toList();

                // Selected apps first
                filtered.sort((a, b) {
                  final aSelected =
                      _selectedApps.contains(a.packageName) ? 0 : 1;
                  final bSelected =
                      _selectedApps.contains(b.packageName) ? 0 : 1;
                  if (aSelected != bSelected) return aSelected - bSelected;
                  return a.appName
                      .toLowerCase()
                      .compareTo(b.appName.toLowerCase());
                });

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final app = filtered[index];
                    final isSelected =
                        _selectedApps.contains(app.packageName);
                    return _appTile(app, isSelected);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (_, __) => const Center(
                child: Text(
                  'Не удалось загрузить приложения',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appTile(AppInfo app, bool isSelected) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.android, color: AppColors.textMuted),
      ),
      title: Text(
        app.appName,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        app.packageName,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (v) {
          setState(() {
            if (v == true) {
              _selectedApps.add(app.packageName);
            } else {
              _selectedApps.remove(app.packageName);
            }
          });
        },
        activeColor: AppColors.primary,
      ),
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedApps.remove(app.packageName);
          } else {
            _selectedApps.add(app.packageName);
          }
        });
      },
    );
  }

  void _selectDefaults() {
    setState(() {
      _selectedApps = AppPreferences.defaultSplitApps.toSet();
    });
  }

  void _save() {
    ref
        .read(appPreferencesProvider)
        .setSplitTunnelApps(_selectedApps.toList());
    Navigator.pop(context);
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
