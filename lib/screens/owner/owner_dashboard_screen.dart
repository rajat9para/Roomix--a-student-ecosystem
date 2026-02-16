import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/providers/owner_listings_provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/screens/owner/add_room_screen.dart';
import 'package:roomix/screens/owner/add_mess_screen.dart';
import 'package:roomix/utils/smooth_navigation.dart';
import 'package:roomix/screens/messages/messages_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return ChangeNotifierProvider(
      create: (_) => OwnerListingsProvider(),
      child: Consumer<OwnerListingsProvider>(builder: (context, listings, _) {
        // Load listings when provider is created
        if (user?.id != null) {
          listings.loadMyListings(user!.id!);
        }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 120,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Header
                _buildHeader(user?.name ?? 'Owner'),
                const SizedBox(height: 30),

                // Quick Actions Title
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Action Cards Grid
                _buildActionGrid(context),
                const SizedBox(height: 30),

                // My Listings Section
                const Text(
                  'Manage Your Business',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Management Options
                _buildManagementOptions(context),
                const SizedBox(height: 20),
                // Responsive Tab area
                const SizedBox(height: 12),
                Expanded(
                  child: Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(text: 'PG Listings'),
                            Tab(text: 'Mess Listings'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildRoomsTab(context),
                              _buildMessTab(context),
                            ],
                          ),
                        ),
                      ],
                    ),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
    );
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _editRoom(String id, Map<String, dynamic> current) async {
    final titleController = TextEditingController(text: current['title']?.toString() ?? '');
    final priceController = TextEditingController(text: current['price']?.toString() ?? '');
    final result = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (result == true) {
      final listings = Provider.of<OwnerListingsProvider>(context, listen: false);
      try {
        final updates = <String, dynamic>{
          if (titleController.text.isNotEmpty) 'title': titleController.text.trim(),
          if (priceController.text.isNotEmpty) 'price': double.tryParse(priceController.text.trim()) ?? current['price'],
        };
        final ok = await listings.editRoom(id, updates);
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room updated')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(listings.error ?? 'Update failed')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Future<void> _editMess(String id, Map<String, dynamic> current) async {
    final titleController = TextEditingController(text: current['name']?.toString() ?? current['title']?.toString() ?? '');
    final result = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Mess'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (result == true) {
      final listings = Provider.of<OwnerListingsProvider>(context, listen: false);
      try {
        final updates = <String, dynamic>{
          if (titleController.text.isNotEmpty) 'name': titleController.text.trim(),
        };
        final ok = await listings.editMess(id, updates);
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mess updated')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(listings.error ?? 'Update failed')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Widget _buildHeader(String name) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Manage your listings',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.business, color: Colors.white, size: 28),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildActionCard(
          context,
          icon: Icons.home_work_rounded,
          title: 'Add PG/Room',
          subtitle: 'List your property',
          gradient: AppColors.primaryGradient,
          onTap: () => SmoothNavigation.push(context, const AddRoomScreen()),
        ),
        _buildActionCard(
          context,
          icon: Icons.restaurant_menu_rounded,
          title: 'Add Mess',
          subtitle: 'Add your mess service',
          gradient: AppColors.accentGradient,
          onTap: () => SmoothNavigation.push(context, const AddMessScreen()),
        ),
        _buildActionCard(
          context,
          icon: Icons.photo_library_rounded,
          title: 'Add Photos',
          subtitle: 'Upload images',
          gradient: AppColors.secondaryGradient,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add photos via Add PG or Add Mess')),
            );
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.analytics_rounded,
          title: 'View Stats',
          subtitle: 'Check performance',
          gradient: const LinearGradient(
            colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
          ),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Analytics coming soon!')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (gradient as LinearGradient).colors.first.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementOptions(BuildContext context) {
    return Column(
      children: [
        _buildManagementTile(
          icon: Icons.home_rounded,
          title: 'My PG Listings',
          subtitle: 'View and edit your room listings',
          color: AppColors.primary,
          onTap: () async {
            final listings = Provider.of<OwnerListingsProvider>(context, listen: false);
            await listings.fetchRooms();
            _tabController.animateTo(0);
            Future.delayed(const Duration(milliseconds: 200), () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Viewing PG Listings')),
              );
            });
          },
        ),
        const SizedBox(height: 12),
        _buildManagementTile(
          icon: Icons.restaurant_rounded,
          title: 'My Mess Listings',
          subtitle: 'Manage your mess services',
          color: AppColors.accent,
          onTap: () async {
            final listings = Provider.of<OwnerListingsProvider>(context, listen: false);
            await listings.fetchMess();
            _tabController.animateTo(1);
            Future.delayed(const Duration(milliseconds: 200), () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Viewing Mess Listings')),
              );
            });
          },
        ),
        const SizedBox(height: 12),
        _buildManagementTile(
          icon: Icons.star_rounded,
          title: 'Reviews & Ratings',
          subtitle: 'See what customers are saying',
          color: AppColors.secondary,
          onTap: () async {
            final listings = Provider.of<OwnerListingsProvider>(context, listen: false);
            await listings.fetchAll();
            _showReviewsDialog(context);
          },
        ),
        const SizedBox(height: 12),
        _buildManagementTile(
          icon: Icons.chat_bubble_rounded,
          title: 'Inquiries & Messages',
          subtitle: 'Chat with potential tenants',
          color: AppColors.primary, // Using primary color for messages
          onTap: () {
            SmoothNavigation.push(context, const MessagesScreen());
          },
        ),
      ],
    );
  }

  Widget _buildManagementTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.5),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomsTab(BuildContext context) {
    final listings = Provider.of<OwnerListingsProvider>(context);
    if (listings.loadingRooms) return const Center(child: CircularProgressIndicator());
    if (listings.rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No room listings yet', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => SmoothNavigation.push(context, const AddRoomScreen()).then((v) async {
                await listings.fetchRooms();
              }),
              child: const Text('Add your first room'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: listings.rooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = listings.rooms[index];
        final id = item['_id'] ?? item['id'] ?? '';
        return Card(
          color: Colors.white.withOpacity(0.06),
          child: ListTile(
            title: Text(item['title'] ?? 'Untitled', style: const TextStyle(color: Colors.white)),
            subtitle: Text('₹${item['price'] ?? 'N/A'} • ${item['location'] ?? ''}', style: TextStyle(color: Colors.white70)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => _editRoom(id, item)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _confirmDeleteRoom(id)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildMessTab(BuildContext context) {
    final listings = Provider.of<OwnerListingsProvider>(context);
    if (listings.loadingMess) return const Center(child: CircularProgressIndicator());
    if (listings.mess.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No mess listings yet', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => SmoothNavigation.push(context, const AddMessScreen()).then((v) async {
                await listings.fetchMess();
              }),
              child: const Text('Add your first mess'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: listings.mess.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = listings.mess[index] as Map<String, dynamic>;
        final id = item['_id'] ?? item['id'] ?? '';
        return Card(
          color: Colors.white.withOpacity(0.06),
          child: ListTile(
            title: Text(item['name'] ?? item['title'] ?? 'Untitled', style: const TextStyle(color: Colors.white)),
            subtitle: Text(item['description'] ?? '', style: TextStyle(color: Colors.white70)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => _editMess(id, item)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _confirmDeleteMess(id)),
            ]),
          ),
        );
      },
    );
  }

  void _confirmDeleteRoom(String id) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete room'),
        content: const Text('Are you sure you want to delete this room listing?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            Navigator.pop(ctx, true);
            final listings = Provider.of<OwnerListingsProvider>(context, listen: false);
            final ok = await listings.deleteRoom(id);
            if (ok) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room deleted')));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(listings.error ?? 'Delete failed')));
            }
          }, child: const Text('Delete')),
        ],
      ),
    );
  }

  void _confirmDeleteMess(String id) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete mess'),
        content: const Text('Are you sure you want to delete this mess listing?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            Navigator.pop(ctx, true);
            final listings = Provider.of<OwnerListingsProvider>(context, listen: false);
            final ok = await listings.deleteMess(id);
            if (ok) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mess listing deleted')));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(listings.error ?? 'Delete failed')));
            }
          }, child: const Text('Delete')),
        ],
      ),
    );
  }

  void _showReviewsDialog(BuildContext context) {
    final listings = Provider.of<OwnerListingsProvider>(context, listen: false);

    // Aggregate all reviews from rooms and mess
    final allReviews = <Map<String, dynamic>>[];

    // Add room reviews
    for (final room in listings.rooms) {
      if (room['reviews'] != null && room['reviews'] is List) {
        for (final review in room['reviews'] as List) {
          allReviews.add({
            ...review as Map<String, dynamic>,
            'source': 'Room: ${room['title'] ?? "Room"}',
            'sourceId': room['_id'] ?? room['id'] ?? '',
          });
        }
      }
    }

    // Add mess reviews
    for (final mess in listings.mess) {
      if (mess != null && mess is Map) {
        if (mess['reviews'] != null && mess['reviews'] is List) {
          for (final review in mess['reviews'] as List) {
            allReviews.add({
              ...review as Map<String, dynamic>,
              'source': 'Mess: ${mess['name'] ?? mess['title'] ?? "Mess"}',
              'sourceId': mess['_id'] ?? mess['id'] ?? '',
            });
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reviews & Ratings'),
        content: allReviews.isEmpty
            ? const Text('No reviews yet. Customers can leave reviews on your listings.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  itemCount: allReviews.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final review = allReviews[index];
                    final rating = review['rating'] ?? 0;
                    final comment = review['comment'] ?? '';
                    final user = review['userId'] ?? 'Anonymous';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                review['source'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < rating
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          if (comment.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              comment,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
