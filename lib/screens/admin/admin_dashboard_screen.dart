import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/screens/auth/auth_gate.dart';
import 'package:roomix/services/cloudinary_upload_service.dart';
import 'package:roomix/services/firebase_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _firebaseService = FirebaseService();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _storageService = CloudinaryUploadService();

  int _tabIndex = 0;
  bool _loadingAnalytics = true;
  bool _publishingPost = false;

  // Multi-image support
  List<File> _selectedImages = [];

  Map<String, int> _analytics = {
    'users': 0,
    'market': 0,
    'lost': 0,
    'checkout_posts': 0,
    'checkout_likes': 0,
    'checkout_comments': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loadingAnalytics = true);
    try {
      final firestore = FirebaseFirestore.instance;

      final usersFuture = firestore.collection('users').count().get();
      final marketFuture = firestore.collection('marketItems').count().get();
      final lostFuture = firestore.collection('lostItems').count().get();
      final noticeStatsFuture = _firebaseService.getNoticeEngagementSummary();

      final results = await Future.wait([
        usersFuture,
        marketFuture,
        lostFuture,
        noticeStatsFuture,
      ]);

      final users = (results[0] as AggregateQuerySnapshot).count ?? 0;
      final market = (results[1] as AggregateQuerySnapshot).count ?? 0;
      final lost = (results[2] as AggregateQuerySnapshot).count ?? 0;
      final noticeStats = results[3] as Map<String, int>;

      if (!mounted) return;
      setState(() {
        _analytics = {
          'users': users,
          'market': market,
          'lost': lost,
          'checkout_posts': noticeStats['posts'] ?? 0,
          'checkout_likes': noticeStats['likes'] ?? 0,
          'checkout_comments': noticeStats['comments'] ?? 0,
        };
        _loadingAnalytics = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAnalytics = false);
    }
  }

  Future<void> _pickImages() async {
    final picked = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      limit: 4,
    );

    if (picked.isEmpty) return;
    // Limit to 4 images total
    final newFiles = picked.take(4 - _selectedImages.length).map((x) => File(x.path)).toList();
    if (newFiles.isEmpty) return;
    setState(() {
      _selectedImages.addAll(newFiles);
      if (_selectedImages.length > 4) {
        _selectedImages = _selectedImages.take(4).toList();
      }
    });
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _createCheckoutPost(AuthProvider auth) async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description is required.')),
      );
      return;
    }

    setState(() => _publishingPost = true);
    try {
      // Upload all selected images
      List<String> imageUrls = [];
      String? primaryImageUrl;

      for (final file in _selectedImages) {
        final url = await _storageService.uploadImage(
          file: file,
          folder: 'checkout_posts',
        );
        if (url != null) {
          imageUrls.add(url);
          primaryImageUrl ??= url;
        }
      }

      await _firebaseService.addNotice(
        title: title.isEmpty ? 'Checkout Update' : title,
        message: message,
        adminId: auth.currentUser?.id ?? auth.firebaseUser?.uid ?? '',
        imageUrl: primaryImageUrl,
        imageUrls: imageUrls,
      );

      _titleController.clear();
      _messageController.clear();
      setState(() => _selectedImages.clear());
      await _loadAnalytics();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checkout post published.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to publish: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _publishingPost = false);
      }
    }
  }

  Future<void> _deleteDoc(String collection, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .delete();
      await _loadAnalytics();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout from admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final auth = context.read<AuthProvider>();
      try {
        await auth.logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.currentUser?.role == 'admin';

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Unauthorized access',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.primary.withOpacity(0.3),
        actions: [
          IconButton(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          GestureDetector(
            onTap: _handleLogout,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar with icons
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildTab('Analytics', 0, Icons.analytics_outlined),
                _buildTab('Checkout', 1, Icons.campaign_outlined),
                _buildTab('Moderation', 2, Icons.admin_panel_settings_outlined),
              ],
            ),
          ),
          Expanded(
            child: _tabIndex == 0
                ? _buildAnalyticsTab()
                : _tabIndex == 1
                ? _buildCheckoutTab(auth)
                : _buildModerationTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index, IconData icon) {
    final isActive = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? AppColors.primary : AppColors.textGray,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive ? AppColors.primary : AppColors.textGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    if (_loadingAnalytics) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Grid of stat cards — 2 columns, evenly aligned
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _statCard('Users', _analytics['users'] ?? 0, Icons.people_outline, Colors.blue),
              _statCard('Marketplace', _analytics['market'] ?? 0, Icons.storefront_outlined, Colors.green),
              _statCard('Lost & Found', _analytics['lost'] ?? 0, Icons.search_outlined, Colors.orange),
              _statCard('Checkout Posts', _analytics['checkout_posts'] ?? 0, Icons.campaign_outlined, AppColors.primary),
              _statCard('Checkout Likes', _analytics['checkout_likes'] ?? 0, Icons.favorite_outline, Colors.red),
              _statCard('Comments', _analytics['checkout_comments'] ?? 0, Icons.comment_outlined, Colors.purple),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Recent Checkout Posts',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildCheckoutPostsList(),
        ],
      ),
    );
  }

  Widget _statCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: AppColors.textGray, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutTab(AuthProvider auth) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Publish Checkout Post',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'Title (optional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _messageController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Description',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),

        // Multi-image picker button
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _selectedImages.length >= 4 ? null : _pickImages,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text('Add Photos (${_selectedImages.length}/4)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),

        // Image preview grid
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _selectedImages[index],
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _publishingPost ? null : () => _createCheckoutPost(auth),
            icon: _publishingPost
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.publish_outlined),
            label: Text(
              _publishingPost ? 'Publishing...' : 'Publish Checkout Post',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 3,
              shadowColor: AppColors.primary.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Live Posts',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildCheckoutPostsList(),
      ],
    );
  }

  Widget _buildCheckoutPostsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firebaseService.getNotices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final notices = snapshot.data ?? [];
        if (notices.isEmpty) {
          return const Center(child: Text('No checkout posts yet'));
        }

        return ListView.builder(
          itemCount: notices.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final notice = notices[index];
            final title = notice['title']?.toString() ?? 'Checkout Update';
            final message = notice['message']?.toString() ?? '';
            final imageUrl = notice['imageUrl']?.toString() ?? '';
            final imageUrls = List<String>.from(notice['imageUrls'] ?? []);
            final likeCount = (notice['likeCount'] as num?)?.toInt() ?? 0;
            final commentCount = (notice['commentCount'] as num?)?.toInt() ?? 0;

            // Combine imageUrls + legacy imageUrl
            final allImages = <String>[...imageUrls];
            if (allImages.isEmpty && imageUrl.isNotEmpty) {
              allImages.add(imageUrl);
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image carousel for multi-image
                    if (allImages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          height: 140,
                          child: allImages.length == 1
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    allImages[0],
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 140,
                                      color: AppColors.background,
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.broken_image),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: allImages.length,
                                  itemBuilder: (context, imgIndex) {
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right: imgIndex < allImages.length - 1 ? 8 : 0,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          allImages[imgIndex],
                                          height: 140,
                                          width: 200,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            height: 140,
                                            width: 200,
                                            color: AppColors.background,
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.broken_image),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: const TextStyle(color: AppColors.textGray),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Text('$likeCount'),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.comment,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text('$commentCount'),
                        if (allImages.length > 1) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.photo_library, color: AppColors.textGray, size: 16),
                          const SizedBox(width: 4),
                          Text('${allImages.length}', style: const TextStyle(color: AppColors.textGray)),
                        ],
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _deleteDoc('notices', notice['id'].toString()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModerationTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Marketplace Listings',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildModerationCollectionList(
          collection: 'marketItems',
          titleBuilder: (data) => data['title']?.toString() ?? 'Untitled Item',
          subtitleBuilder: (data) {
            final seller = data['sellerName']?.toString() ?? 'Unknown seller';
            final price = (data['price'] as num?)?.toInt() ?? 0;
            return '$seller • Rs $price';
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Lost & Found Reports',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildModerationCollectionList(
          collection: 'lostItems',
          titleBuilder: (data) =>
              data['title']?.toString() ?? 'Untitled Report',
          subtitleBuilder: (data) {
            final status = data['status']?.toString() ?? 'Unknown';
            final location = data['location']?.toString() ?? 'No location';
            return '$status • $location';
          },
        ),
      ],
    );
  }

  Widget _buildModerationCollectionList({
    required String collection,
    required String Function(Map<String, dynamic>) titleBuilder,
    required String Function(Map<String, dynamic>) subtitleBuilder,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text(
            'No records found',
            style: TextStyle(color: AppColors.textGray),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(titleBuilder(data)),
                subtitle: Text(subtitleBuilder(data)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteDoc(collection, doc.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
