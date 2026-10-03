import 'package:flutter/material.dart';
import '../colors.dart';
import '../struct/models/doc_type.dart';

class StatsHeaderCard extends StatelessWidget {
  final Map<String, int> stats;
  final DocType? selectedDocType;
  final Function(DocType?) onSelectDocType;

  const StatsHeaderCard({
    super.key,
    required this.stats,
    required this.selectedDocType,
    required this.onSelectDocType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TỔNG SỐ TÀI LIỆU',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${stats['total'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'tài liệu',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.favorite.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: AppColors.favorite),
                    const SizedBox(width: 4),
                    Text(
                      '${stats['favorites'] ?? 0} yêu thích',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC78200),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Danh mục loại tài liệu
          Row(
            children: [
              _buildTypeStatItem(
                context: context,
                type: DocType.lecture,
                count: stats['lectures'] ?? 0,
              ),
              _buildTypeStatItem(
                context: context,
                type: DocType.assignment,
                count: stats['assignments'] ?? 0,
              ),
              _buildTypeStatItem(
                context: context,
                type: DocType.reference,
                count: stats['references'] ?? 0,
              ),
              _buildTypeStatItem(
                context: context,
                type: DocType.exam,
                count: stats['exams'] ?? 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeStatItem({
    required BuildContext context,
    required DocType type,
    required int count,
  }) {
    final isSelected = selectedDocType == type;

    return Expanded(
      child: InkWell(
        onTap: () => onSelectDocType(type),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? type.color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: type.color, width: 1.5) : null,
          ),
          child: Column(
            children: [
              Icon(type.icon, size: 18, color: type.color),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? type.color : null,
                ),
              ),
              Text(
                type.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? type.color : Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
