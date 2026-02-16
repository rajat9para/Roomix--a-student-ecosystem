import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/providers/user_preferences_provider.dart';
import 'package:roomix/screens/rooms/room_screen.dart';
import 'package:roomix/screens/mess/mess_screen.dart';
import 'package:roomix/screens/roommate_finder/roommate_finder_screen.dart';
import 'package:roomix/screens/events/events_screen.dart';
import 'package:roomix/screens/bookmarks/bookmarks_screen.dart';
import 'package:roomix/screens/profile/profile_screen.dart';
import 'package:roomix/screens/owner/add_room_screen.dart';
import 'package:roomix/screens/onboarding/university_selection_screen.dart';
import 'package:roomix/screens/messages/messages_screen.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/models/user_model.dart';
import 'package:roomix/services/api_service.dart';
import 'package:roomix/services/loaction_service.dart';
import 'package:roomix/models/room_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  File? _profileImage;
  String? _currentCity;
  bool _isLoading = true;
  List<dynamic> _featuredPGs = [];
  List<dynamic> _campusUpdates = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadProfileImage();
    _getUserCity();
  }

  Future<void> _getUserCity() async {
    final prefs = await SharedPreferences.getInstance();

    // if already saved → use it
    final savedCity = prefs.getString('user_city');
    if (savedCity != null) {
      setState(() => _currentCity = savedCity);
      print("CITY FROM CACHE => $savedCity");
      return;
    }

    // otherwise fetch GPS
    final city = await LocationService.getCurrentCity();

    if (city != null && mounted) {
      await prefs.setString('user_city', city);
      setState(() => _currentCity = city);
      print("CITY FROM GPS => $city");
    }
  }
  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');

    if (path != null && File(path).existsSync()) {
      setState(() {
        _profileImage = File(path);
      });
    }
  }

  Future<void> _loadData() async {
    // Simulate loading
    await Future.delayed(const Duration(seconds: 1));
    
    // Load featured PGs
    try {
      final rooms = await ApiService.getRooms();
      setState(() {
        _featuredPGs = rooms.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _selectedIndex == 0 
        ? _buildHomeContent(user)
        : _buildScreenForIndex(_selectedIndex),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildScreenForIndex(int index) {
    switch (index) {
      case 1:
        return const BookmarksScreen();
      case 2:
        return const MessagesScreen();
      case 3:
        return const ProfileScreen();
      default:
        return _buildHomeContent(Provider.of<AuthProvider>(context).currentUser);
    }
  }

  Widget _buildHomeContent(UserModel? user) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // App Bar
          SliverToBoxAdapter(
            child: _buildAppBar(user),
          ),
          
          // Search Section
          SliverToBoxAdapter(
            child: _buildSearchSection(),
          ),
          
          // Quick Categories
          SliverToBoxAdapter(
            child: _buildQuickCategories(),
          ),
          
          // Featured PGs Header
          SliverToBoxAdapter(
            child: _buildSectionHeader('Top Rated PGs', onSeeAll: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoomScreen()),
              );
            }),
          ),
          
          // Featured PGs List
          SliverToBoxAdapter(
            child: _buildFeaturedPGs(),
          ),
          
          // Campus Updates Header
          SliverToBoxAdapter(
            child: _buildSectionHeader('Campus Updates', showSeeAll: false),
          ),
          
          // Campus Updates
          SliverToBoxAdapter(
            child: _buildCampusUpdates(),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildAppBar(UserModel? user) {
    final prefs = context.watch<UserPreferencesProvider>();
    final universityName = prefs.selectedUniversity?.name ?? 'Select University';
    final cityName = _currentCity ?? prefs.selectedUniversity?.city ?? 'Select Location';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Profile Avatar
          GestureDetector(
            onTap: () => _onItemTapped(3),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: _profileImage != null
                    ? Image.file(
                  _profileImage!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                )
                    : Center(
                  child: Text(
                    prefs.selectedUniversity?.name ?? 'Select University',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // University Selector
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UniversitySelectionScreen(isOnboarding: false),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    universityName,   // 👈 now university name on top
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),

                  Row(
                    children: [
                      Text(
                        prefs.selectedUniversity?.city ?? 'Select Location',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Notification Icon
          IconButton(
            onPressed: () {
              // Show notifications
            },
            icon: Icon(
              Icons.notifications_outlined,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Find your next stay',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search PGs, Mess, or Roommates',
                hintStyle: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCategories() {
    final categories = [
      {'icon': Icons.home_work_outlined, 'label': 'PGs', 'color': AppColors.primary},
      {'icon': Icons.restaurant_outlined, 'label': 'Mess', 'color': AppColors.primary},
      {'icon': Icons.group_outlined, 'label': 'Roomies', 'color': AppColors.primary},
      {'icon': Icons.event_outlined, 'label': 'Events', 'color': AppColors.primary},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: categories.map((cat) {
          return Expanded(
            child: GestureDetector(
              onTap: () {
                // Navigate to respective screen
                switch (cat['label']) {
                  case 'PGs':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomScreen()));
                    break;
                  case 'Mess':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MessScreen()));
                    break;
                  case 'Roomies':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RoommateFinderScreen()));
                    break;
                  case 'Events':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EventsScreen()));
                    break;
                }
              },
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      cat['icon'] as IconData,
                      color: cat['color'] as Color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cat['label'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll, bool showSeeAll = true}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      color: AppColors.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          if (showSeeAll && onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                'See all',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedPGs() {
    if (_isLoading) {
      return SizedBox(
        height: 280,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          itemBuilder: (_, __) => _buildPGLoadingCard(),
        ),
      );
    }

    if (_featuredPGs.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('No PGs available'),
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _featuredPGs.length,
        itemBuilder: (context, index) {
          final RoomModel pg = _featuredPGs[index];
          return _buildPGCard(pg);
        },
      ),
    );
  }

  Widget _buildPGLoadingCard() {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 16,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 12,
                  color: Colors.grey.shade200,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPGCard(RoomModel pg) {
    final title = pg.title;
    final location = pg.location;
    final price = pg.price.toStringAsFixed(0);
    final rating = pg.rating.toStringAsFixed(1);
    final image = pg.imageurl;

    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: image.isNotEmpty
                      ? Image.network(
                    image,
                    height: 160,
                    width: 280,
                    fit: BoxFit.cover,
                  )
                      : Container(
                    height: 160,
                    width: 280,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.home, size: 50),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 14),
                        const SizedBox(width: 4),
                        Text(rating, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(location, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text("₹$price / month",
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenityChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildCampusUpdates() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'University Student Council',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '2 hours ago',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'The annual cultural fest "Aura 2024" starts this Friday. Roommates looking for group tickets? Check the events section!',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.thumb_up_outlined, size: 18, color: AppColors.textGray),
              const SizedBox(width: 6),
              Text(
                '24',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGray,
                ),
              ),
              const SizedBox(width: 24),
              Icon(Icons.comment_outlined, size: 18, color: AppColors.textGray),
              const SizedBox(width: 6),
              Text(
                '12',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final authProvider = Provider.of<AuthProvider>(context);
    final userRole = authProvider.currentUser?.role;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0),
              _buildNavItem(Icons.bookmark_outline, 'Saved', 1),
              // Only show add button for owners/admins, NOT students
              if (userRole != 'student') _buildAddButton(),
              _buildNavItem(Icons.chat_bubble_outline, 'Messages', 2),
              _buildNavItem(Icons.person_outline, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.primary : AppColors.textGray,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () {
        // Show add options
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'List Your Property',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildAddOption(
                  icon: Icons.home_work_outlined,
                  title: 'Add Room/PG',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddRoomScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildAddOption(
                  icon: Icons.restaurant_outlined,
                  title: 'Add Mess',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to add mess
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        width: 56,
        height: 56,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildAddOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
