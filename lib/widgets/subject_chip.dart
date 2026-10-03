import 'package:flutter/material.dart';
import '../struct/models/subject.dart';

class SubjectChip extends StatelessWidget {
  final Subject? subject;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isAll;

  const SubjectChip({
    super.key,
    required this.subject,
    required this.isSelected,
    required this.onTap,
    this.isAll = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color chipColor = isAll
        ? (isSelected ? theme.colorScheme.primary : Colors.transparent)
        : (isSelected ? subject!.colorValue : Colors.transparent);

    final Color textColor = isSelected
        ? Colors.white
        : (isDark ? Colors.white70 : Colors.black87);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? Colors.white24 : Colors.black12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isAll && subject != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : subject!.colorValue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                isAll ? 'Tất cả môn' : subject!.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
