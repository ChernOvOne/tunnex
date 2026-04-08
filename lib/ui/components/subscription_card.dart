import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../core/model/subscription.dart';
import '../theme/app_theme.dart';

class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.isActive = false,
    this.onTap,
    this.onRefresh,
    this.onShare,
    this.onDelete,
  });

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatExpiry(int epochSec) {
    if (epochSec <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _formatDate(int epochMs) {
    if (epochMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            subscription.name.isNotEmpty
                                ? subscription.name
                                : 'Подписка',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'активна',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (subscription.lastUpdated > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        _formatDate(subscription.lastUpdated),
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ),
                  if (onRefresh != null)
                    IconButton(
                      icon: const Icon(Icons.refresh,
                          size: 20, color: AppColors.textSecondary),
                      onPressed: onRefresh,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: AppColors.error),
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),

              // Username (copyable)
              if (subscription.username.isNotEmpty) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: subscription.username));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Скопировано'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        subscription.username,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy,
                          size: 13, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Traffic progress
              if (subscription.totalBytes > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatBytes(subscription.usedBytes.toInt()),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    Text(
                      _formatBytes(subscription.totalBytes),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: subscription.usagePercent,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: AlwaysStoppedAnimation(
                      subscription.usagePercent > 0.9
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Chips row
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (subscription.daysLeft >= 0)
                    _chip(
                      subscription.daysLeft == 0
                          ? 'Истекла'
                          : '${subscription.daysLeft} дн.',
                      subscription.daysLeft <= 3
                          ? AppColors.error
                          : AppColors.accent,
                    ),
                  if (subscription.expireTimestamp > 0)
                    _chip(
                      'до ${_formatExpiry(subscription.expireTimestamp)}',
                      AppColors.textSecondary,
                    ),
                ],
              ),

              // Action buttons row
              const SizedBox(height: 10),
              Row(
                children: [
                  // Share button
                  if (onShare != null)
                    GestureDetector(
                      onTap: onShare,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_2, size: 16, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Поделиться подпиской',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Support link
                  if (subscription.supportUrl.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        final uri = Uri.tryParse(subscription.supportUrl);
                        if (uri != null) {
                          launcher.launchUrl(uri,
                              mode: launcher.LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.support_agent, size: 16, color: AppColors.accent),
                            SizedBox(width: 6),
                            Text(
                              'Поддержка',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
