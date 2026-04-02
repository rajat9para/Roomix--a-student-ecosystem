import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/screens/auth/auth_gate.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/providers/owner_listings_provider.dart';
import 'package:roomix/services/telegram_service.dart';
import 'package:roomix/screens/owner/add_mess_screen.dart';
import 'package:roomix/screens/owner/add_room_screen.dart';
import 'package:roomix/screens/owner/owner_profile_screen.dart';
import 'package:roomix/screens/profile/account_settings_screen.dart';
import 'package:roomix/screens/notifications/notifications_screen.dart';
import 'package:roomix/screens/rooms/room_detail_screen.dart';
import 'package:roomix/screens/mess/mess_detail_screen.dart';
import 'package:roomix/models/room_model.dart';
import 'package:roomix/models/mess_model.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _loadedListingsForOwnerId;

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

  void _syncTabControllerLength(int length) {
    if (length <= 0 || _tabController.length == length) {
      return;
    }
    final previousIndex = _tabController.index;
    _tabController.dispose();
    _tabController = TabController(length: length, vsync: this);
    final safeIndex = previousIndex >= length ? length - 1 : previousIndex;
    _tabController.index = safeIndex < 0 ? 0 : safeIndex;
  }

  void _ensureListingsLoaded(String? ownerId) {
    final normalizedOwnerId = ownerId?.trim() ?? '';
    if (normalizedOwnerId.isEmpty) {
      _loadedListingsForOwnerId = null;
      return;
    }
    if (_loadedListingsForOwnerId == normalizedOwnerId) {
      return;
    }

    _loadedListingsForOwnerId = normalizedOwnerId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OwnerListingsProvider>().loadMyListings(normalizedOwnerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    _ensureListingsLoaded(user?.id);
    final ownerType = user?.ownerType?.trim().toLowerCase();
    final showPgFeatures = ownerType != 'mess_owner';
    final showMessFeatures = ownerType != 'pg_owner';

    final tabLabels = <String>[];
    final tabViews = <Widget>[];
    if (showPgFeatures) {
      tabLabels.add('PG Listings');
      tabViews.add(_roomsTab());
    }
    if (showMessFeatures) {
      tabLabels.add('Mess Listings');
      tabViews.add(_messTab());
    }
    if (tabLabels.isEmpty) {
      tabLabels.add('Listings');
      tabViews.add(_roomsTab());
    }
    _syncTabControllerLength(tabLabels.length);

    final actionTiles = <Widget>[
      if (showPgFeatures)
        _actionBox(
          Icons.home_work_outlined,
          'Add PG',
          'Create room listing',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddRoomScreen()),
            );
          },
        ),
      if (showMessFeatures)
        _actionBox(
          Icons.restaurant_outlined,
          'Add Mess',
          'Create mess listing',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddMessScreen()),
            );
          },
        ),
      _actionBox(Icons.star_outline, 'Reviews', 'View ratings', () {
        _showReviews(context);
      }),
      _actionBox(Icons.send, 'Telegram', 'Open Telegram', () async {
        final auth = context.read<AuthProvider>();
        final linkedPhone = auth.currentUser?.telegramPhone?.trim();

        if (linkedPhone != null &&
            linkedPhone.isNotEmpty &&
            TelegramService.isValidPhone(linkedPhone)) {
          // Just open the Telegram app on the device
          final opened = await TelegramService.openTelegramApp();
          if (!opened && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Telegram is not installed on this device.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Add a valid Telegram number in Account Settings first.',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
          );
        }
      }),
      _actionBox(Icons.settings_outlined, 'Settings', 'Account settings', () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
        );
      }),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          ownerType == 'mess_owner'
              ? 'Mess Owner Dashboard'
              : ownerType == 'pg_owner'
              ? 'PG Owner Dashboard'
              : 'Owner Dashboard',
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OwnerProfileScreen()),
              );
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(.15),
              child: const Icon(Icons.person, color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            tooltip: 'Logout',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Logout', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                final auth = context.read<AuthProvider>();
                try {
                  await auth.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthGate()),
                    (_) => false,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
          ),
        ],
        bottom: tabLabels.length > 1
            ? TabBar(
                controller: _tabController,
                tabs: tabLabels.map((label) => Tab(text: label)).toList(),
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.25,
              children: actionTiles,
            ),
          ),
          Expanded(
            child: TabBarView(controller: _tabController, children: tabViews),
          ),
        ],
      ),
    );
  }

  Widget _actionBox(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ROOMS TAB (with Edit/Delete) ====================

  Widget _roomsTab() {
    return Consumer<OwnerListingsProvider>(
      builder: (context, listings, __) {
        if (listings.loadingRooms) {
          return const Center(child: CircularProgressIndicator());
        }
        if (listings.rooms.isEmpty) {
          return const Center(child: Text("No rooms added yet"));
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            listings.loadMyListings(
              Provider.of<AuthProvider>(context, listen: false).currentUser!.id,
            );
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
          itemCount: listings.rooms.length,
          itemBuilder: (_, i) {
            final room = listings.rooms[i] as RoomModel;
            return ListTile(
              // Tap to view detail
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoomDetailScreen(room: room),
                  ),
                );
              },
              leading: room.imageurl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        room.imageurl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: AppColors.background,
                          child: const Icon(
                            Icons.home_work_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.home_work_outlined,
                        color: AppColors.primary,
                      ),
                    ),
              title: Text(room.title),
              subtitle: Text(
                "₹${room.price.toStringAsFixed(0)} • ${room.location}",
              ),
              // Edit/Delete popup menu
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textGray),
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddRoomScreen(existingRoom: room),
                      ),
                    );
                  } else if (value == 'delete') {
                    _confirmDeleteRoom(context, listings, room);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          ),
        );
      },
    );
  }

  // ==================== MESS TAB (with Edit/Delete) ====================

  Widget _messTab() {
    return Consumer<OwnerListingsProvider>(
      builder: (context, listings, __) {
        if (listings.loadingMess) {
          return const Center(child: CircularProgressIndicator());
        }
        if (listings.mess.isEmpty) {
          return const Center(child: Text("No mess added yet"));
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            listings.loadMyListings(
              Provider.of<AuthProvider>(context, listen: false).currentUser!.id,
            );
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
          itemCount: listings.mess.length,
          itemBuilder: (_, i) {
            final m = listings.mess[i] as MessModel;
            return ListTile(
              // Tap to view detail
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MessDetailScreen(mess: m)),
                );
              },
              leading: (m.imageurl.isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        m.imageurl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: AppColors.background,
                          child: const Icon(
                            Icons.restaurant_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.restaurant_outlined,
                        color: AppColors.primary,
                      ),
                    ),
              title: Text(m.name),
              subtitle: Text(
                "₹${m.pricepermonth.toStringAsFixed(0)} • ${m.location}",
              ),
              // Edit/Delete popup menu
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textGray),
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddMessScreen(existingMess: m.toJson()),
                      ),
                    );
                  } else if (value == 'delete') {
                    _confirmDeleteMess(context, listings, m);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          ),
        );
      },
    );
  }

  // ==================== DELETE CONFIRMATIONS ====================

  void _confirmDeleteRoom(
    BuildContext context,
    OwnerListingsProvider listings,
    RoomModel room,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text(
          'Are you sure you want to delete "${room.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await listings.deleteRoom(room.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Room deleted' : 'Failed to delete',
                    ),
                    backgroundColor: success ? Colors.green : AppColors.error,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMess(
    BuildContext context,
    OwnerListingsProvider listings,
    MessModel mess,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text(
          'Are you sure you want to delete "${mess.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await listings.deleteMess(mess.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Mess deleted' : 'Failed to delete',
                    ),
                    backgroundColor: success ? Colors.green : AppColors.error,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== REVIEWS (redirect to listing detail) ====================

  void _showReviews(BuildContext context) {
    final listings = Provider.of<OwnerListingsProvider>(context, listen: false);
    final ownerType = context
        .read<AuthProvider>()
        .currentUser
        ?.ownerType
        ?.trim()
        .toLowerCase();
    final allRooms = ownerType == 'mess_owner'
        ? <RoomModel>[]
        : listings.myRooms;
    final allMess = ownerType == 'pg_owner' ? <MessModel>[] : listings.myMess;

    if (allRooms.isEmpty && allMess.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text("No Listings"),
          content: Text("Add a PG or Mess listing first to see reviews."),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 14, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'View Reviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (allRooms.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text(
                        'PG Listings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textGray,
                        ),
                      ),
                    ),
                    ...allRooms.map(
                      (room) => ListTile(
                        leading: const Icon(
                          Icons.home_work_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(room.title),
                        subtitle: Text(
                          'Rating: ${room.rating.toStringAsFixed(1)} ★',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RoomDetailScreen(room: room),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (allMess.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text(
                        'Mess Listings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textGray,
                        ),
                      ),
                    ),
                    ...allMess.map(
                      (mess) => ListTile(
                        leading: const Icon(
                          Icons.restaurant_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(mess.name),
                        subtitle: Text(
                          'Rating: ${mess.rating.toStringAsFixed(1)} ★',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MessDetailScreen(mess: mess),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
