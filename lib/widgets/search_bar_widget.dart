import 'package:flutter/material.dart';
import '../colors.dart';

class SearchBarWidget extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool onlyFavorites;
  final VoidCallback onToggleFavorites;

  const SearchBarWidget({
    super.key,
    required this.initialValue,
    required this.onChanged,
    required this.onClear,
    required this.onlyFavorites,
    required this.onToggleFavorites,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant SearchBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                onChanged: widget.onChanged,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm tài liệu, bài giảng, tags...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _controller.clear();
                            widget.onClear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Nút lọc Yêu thích
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: widget.onlyFavorites
                  ? AppColors.favorite.withValues(alpha: 0.2)
                  : (isDark ? AppColors.cardDark : AppColors.cardLight),
              borderRadius: BorderRadius.circular(12),
              border: widget.onlyFavorites
                  ? Border.all(color: AppColors.favorite, width: 1.5)
                  : null,
            ),
            child: IconButton(
              icon: Icon(
                widget.onlyFavorites ? Icons.star_rounded : Icons.star_outline_rounded,
                color: widget.onlyFavorites ? AppColors.favorite : Colors.grey,
              ),
              tooltip: 'Chỉ hiện yêu thích',
              onPressed: widget.onToggleFavorites,
            ),
          ),
        ],
      ),
    );
  }
}
