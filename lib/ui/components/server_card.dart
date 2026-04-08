import 'package:flutter/material.dart';

import '../../core/model/server_config.dart';
import '../theme/app_theme.dart';

class ServerCard extends StatelessWidget {
  final ServerConfig server;
  final bool isSelected;
  final VoidCallback onTap;

  const ServerCard({
    super.key,
    required this.server,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : Border.all(color: AppColors.surfaceLight, width: 1),
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Server info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.remarks.isNotEmpty
                        ? server.remarks
                        : '${server.address}:${server.port}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _protocolBadge(server.protocol.displayName),
                      const SizedBox(width: 6),
                      if (server.network != 'tcp')
                        _protocolBadge(server.network),
                      if (server.security == 'reality') ...[
                        const SizedBox(width: 6),
                        _protocolBadge('Reality'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Ping
            if (server.testResult > 0)
              Text(
                '${server.testResult}ms',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: server.testResult < 200
                      ? AppColors.success
                      : server.testResult < 500
                          ? AppColors.warning
                          : AppColors.error,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _protocolBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryLight,
        ),
      ),
    );
  }
}
