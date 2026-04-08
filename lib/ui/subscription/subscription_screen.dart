import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preferences/app_preferences.dart';
import '../../data/providers.dart';
import '../components/qr_scanner_screen.dart';
import '../components/qr_share_dialog.dart';
import '../components/subscription_card.dart';
import '../theme/app_theme.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(subscriptionsProvider);
    final activeId = ref.watch(selectedSubscriptionIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Добавить', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            floating: true,
            title: Text('Подписки'),
          ),
        if (subscriptions.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 64, color: AppColors.textMuted),
                  SizedBox(height: 16),
                  Text(
                    'Нет подписок',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Нажмите + чтобы добавить',
                    style:
                        TextStyle(fontSize: 14, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final sub = subscriptions[index];
                return SubscriptionCard(
                  subscription: sub,
                  isActive: sub.id == activeId,
                  onTap: () {
                    ref.read(selectedSubscriptionIdProvider.notifier).state =
                        sub.id;
                    ref
                        .read(appPreferencesProvider)
                        .setSelectedSubscriptionId(sub.id);
                  },
                  onRefresh: () {
                    ref
                        .read(subscriptionsProvider.notifier)
                        .refresh(sub.id);
                  },
                  onShare: () => QrShareDialog.show(context, data: sub.url, title: sub.name),
                  onDelete: () => _confirmDelete(context, ref, sub.id, sub.name),
                );
              },
              childCount: subscriptions.length,
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.primaryGradient.createShader(bounds),
              child: const Icon(Icons.add_link, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('Добавить подписку'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: 'https://...',
                hintStyle: TextStyle(color: AppColors.textMuted),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            // Action buttons row
            Row(
              children: [
                // Paste from clipboard
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        urlController.text = data!.text!;
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
                // Scan QR
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final result = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QrScannerScreen(),
                        ),
                      );
                      if (result != null && context.mounted) {
                        final error = await ref
                            .read(subscriptionsProvider.notifier)
                            .add(result);
                        if (error != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error)),
                          );
                        }
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
              final error =
                  await ref.read(subscriptionsProvider.notifier).add(url);
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

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить подписку?'),
        content: Text(
          'Подписка "${name.isNotEmpty ? name : 'Без имени'}" и все её серверы будут удалены.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(subscriptionsProvider.notifier).remove(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}
