import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/models/bookmark_model.dart';
import 'package:roomix/providers/bookmarks_provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:roomix/services/firebase_service.dart';
import 'package:roomix/models/room_model.dart';
import 'package:roomix/screens/rooms/room_detail_screen.dart';
import 'package:roomix/utils/smooth_navigation.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  String _selectedTab = 'PGs';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _tabs = ['PGs', 'Roommates', 'Market'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookmarksProvider>().fetchBookmarks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Saved Bookmarks',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primary),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.primary),
            onPressed: _showClearAllDialog,
          ),
        ],
      ),
      body: Consumer<BookmarksProvider>(
        builder: (context, bookmarksProvider, _) {
          return Column(
            children: [
              // Tab Navigation
              Container(
                color: Colors.white,
                child: Row(
                  children: _tabs.map((tab) {
                    final isSelected = _selectedTab == tab;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = tab),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isSelected ? AppColors.primary : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            tab,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.primary : AppColors.textGray,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Search Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      context.read<BookmarksProvider>().filterBookmarks(value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search saved items...',
                      hintStyle: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                context.read<BookmarksProvider>().filterBookmarks('');
                              },
                              child: const Icon(Icons.clear, color: AppColors.textGray),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: bookmarksProvider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      )
                    : _buildFilteredBookmarks(bookmarksProvider).isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: () => bookmarksProvider.fetchBookmarks(),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _buildFilteredBookmarks(bookmarksProvider).length,
                              itemBuilder: (context, index) {
                                final bookmark = _buildFilteredBookmarks(bookmarksProvider)[index];
                                return _buildBookmarkCard(bookmark);
                              },
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<BookmarkModel> _buildFilteredBookmarks(BookmarksProvider provider) {
    List<BookmarkModel> bookmarks = provider.filteredBookmarks;
    
    // Filter by tab
    if (_selectedTab == 'PGs') {
      bookmarks = bookmarks.where((b) => b.type == 'room' || b.type == 'pg').toList();
    } else if (_selectedTab == 'Roommates') {
      bookmarks = bookmarks.where((b) => b.type == 'roommate').toList();
    } else if (_selectedTab == 'Market') {
      bookmarks = bookmarks.where((b) => b.type == 'market').toList();
    }
    
    return bookmarks;
  }

  Widget _buildBookmarkCard(BookmarkModel bookmark) {
    return GestureDetector(
        onTap: () async {
      if (bookmark.type != 'room' && bookmark.type != 'pg') return;

      final firebase = FirebaseService();

      final data = await firebase.getRoomById(bookmark.itemid);

      if (!mounted) return;

      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Room no longer exists")),
        );
        return;
      }

      final room = RoomModel.fromJson(data);

      SmoothNavigation.push(
        context,
        RoomDetailScreen(room: room),
      );
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          if (bookmark.itemImage != null)
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: bookmark.itemImage!,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 100,
                  height: 100,
                  color: AppColors.background,
                  child: const Icon(Icons.image_not_supported, color: AppColors.textGray),
                ),
              ),
            )
          else
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
              child: Icon(
                _getTypeIcon(bookmark.type),
                color: AppColors.primary.withOpacity(0.5),
                size: 32,
              ),
            ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getTypeColor(bookmark.type).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          bookmark.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _getTypeColor(bookmark.type),
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _removeBookmark(context, bookmark.id),
                        child: Icon(
                          Icons.close,
                          color: AppColors.textGray.withOpacity(0.5),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bookmark.itemTitle ?? 'Untitled',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (bookmark.itemPrice != null)
                    Text(
                      '₹${bookmark.itemPrice?.toStringAsFixed(0) ?? 'N/A'}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    )
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.bookmark_outline,
              size: 48,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No saved $_selectedTab yet',
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start bookmarking your favorite items',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'room':
      case 'pg':
        return Icons.home_work_outlined;
      case 'mess':
        return Icons.restaurant_outlined;
      case 'utility':
        return Icons.store_outlined;
      case 'market':
        return Icons.shopping_bag_outlined;
      case 'roommate':
        return Icons.group_outlined;
      case 'event':
        return Icons.event_outlined;
      default:
        return Icons.bookmark_outline;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'room':
      case 'pg':
        return AppColors.primary;
      case 'mess':
        return const Color(0xFF10B981);
      case 'utility':
        return const Color(0xFF06B6D4);
      case 'market':
        return const Color(0xFFEC4899);
      case 'roommate':
        return const Color(0xFF8B5CF6);
      case 'event':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.primary;
    }
  }

  void _removeBookmark(BuildContext context, String bookmarkId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Remove Bookmark?',
          style: TextStyle(color: AppColors.textDark),
        ),
        content: const Text(
          'This bookmark will be removed from your saved items.',
          style: TextStyle(color: AppColors.textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGray)),
          ),
          TextButton(
            onPressed: () {
              context.read<BookmarksProvider>().removeBookmark(bookmarkId);
              Navigator.pop(context);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Clear All Bookmarks?',
          style: TextStyle(color: AppColors.textDark),
        ),
        content: const Text(
          'This will remove all your bookmarked items permanently.',
          style: TextStyle(color: AppColors.textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Clear All', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
