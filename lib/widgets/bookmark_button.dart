import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/providers/bookmarks_provider.dart';

class BookmarkButton extends StatefulWidget {
  final String itemId;
  final String type;
  final String itemTitle;
  final String? itemImage;
  final double? itemPrice;
  final double? rating;
  final Map<String, dynamic>? metadata;
  final VoidCallback? onBookmarkChanged;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const BookmarkButton({
    super.key,
    required this.itemId,
    required this.type,
    required this.itemTitle,
    this.itemImage,
    this.itemPrice,
    this.rating,
    this.metadata,
    this.onBookmarkChanged,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<BookmarkButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _playAnimation() async {
    await _animationController.forward();
    await _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookmarksProvider>(
      builder: (context, bookmarksProvider, _) {
        final isBookmarked = bookmarksProvider.isBookmarked(widget.itemId);

        return ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTap: () async {
              _playAnimation();

              if (isBookmarked) {
                await bookmarksProvider
                    .removeBookmarkByItemId(widget.itemId);
              } else {
                await bookmarksProvider.addBookmark(
                  itemid: widget.itemId,
                  itemtype: widget.type,
                  itemTitle: widget.itemTitle,
                  itemImage: widget.itemImage,
                  itemPrice: widget.itemPrice,
                );
              }

              widget.onBookmarkChanged?.call();
            },
            child: Container(
              width: widget.size + 8,
              height: widget.size + 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: widget.size,
                  color: isBookmarked
                      ? (widget.activeColor ?? const Color(0xFFFFB800))
                      : (widget.inactiveColor ??
                          Colors.white.withOpacity(0.6)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
