import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/screens/rooms/room_screen.dart';
import 'package:roomix/screens/rooms/room_detail_screen.dart';
import 'package:roomix/screens/mess/mess_screen.dart';
import 'package:roomix/screens/roommate_finder/roommate_finder_screen.dart';
import 'package:roomix/screens/bookmarks/bookmarks_screen.dart';
import 'package:roomix/screens/profile/profile_screen.dart';
import 'package:roomix/screens/owner/add_room_screen.dart';
import 'package:roomix/screens/utilities/utilities_hub_screen.dart';
import 'package:roomix/screens/lost_found/lost_found_screen.dart';
import 'package:roomix/screens/market/market_screen.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/models/user_model.dart';
import 'package:roomix/services/api_service.dart';
import 'package:roomix/services/loaction_service.dart';
import 'package:roomix/models/room_model.dart';
import 'package:roomix/models/mess_model.dart';
import 'package:roomix/services/firebase_service.dart';
import 'package:roomix/utils/smooth_navigation.dart';
import 'package:roomix/screens/mess/mess_detail_screen.dart';
import 'package:roomix/screens/profile/account_settings_screen.dart';
import 'package:roomix/screens/notifications/notifications_screen.dart';
import 'package:roomix/screens/roommate_finder/profile_creation_screen.dart';
import 'package:roomix/services/telegram_service.dart';
import 'package:roomix/screens/messages/messages_screen.dart';
import 'package:roomix/providers/chat_provider.dart';
import 'dart:async';

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
  List<dynamic> _featuredMess = [];
  List<Map<String, dynamic>> _notices = [];
  StreamSubscription? _noticesSubscription;
  bool _hasUnreadNotices = false;
  bool _showStartupNotice = false;
  bool _startupProfileChecked = false;
  bool _startupRoommateChecked = false;
  bool _startupTelegramChecked = false;
  bool _startupChecklistSubmitted = false;
  bool _startupDismissedForSession = false;
  String? _startupStateLoadedForUserId;
  int _checkoutDayOffset = 0;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadProfileImage();
    _getUserCity();
    _loadStartupNoticeState();
  }

  /// Check if a string contains non-Latin characters (Hindi, etc.)
  bool _hasNonLatinChars(String text) {
    return RegExp(r'[^\x00-\x7F]').hasMatch(text);
  }

  Future<void> _getUserCity() async {
    final prefs = await SharedPreferences.getInstance();

    // if already saved → use it (but invalidate if it's in Hindi)
    final savedCity = prefs.getString('user_city');
    if (savedCity != null && !_hasNonLatinChars(savedCity)) {
      setState(() => _currentCity = savedCity);
      print("CITY FROM CACHE => $savedCity");
      return;
    }

    // Clear stale Hindi cache
    if (savedCity != null) {
      await prefs.remove('user_city');
      print("CLEARED HINDI CITY CACHE: $savedCity");
    }

    // Fetch GPS (will now return English via LocationService)
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
    // Refresh user profile from server (fixes stale phone/name)
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.firebaseUser != null) {
        await auth.fetchProfile();
      }
    } catch (_) {} // Non-critical, continue loading data

    // Load featured PGs from Firebase
    try {
      final rooms = await ApiService.getRooms();
      final messResponse = await ApiService.getMessMenu();
      final messList = messResponse['data'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _featuredPGs = rooms.take(5).toList();
          _featuredMess = messList.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    // Load admin notices from Firestore
    _noticesSubscription = FirebaseService().getNotices().listen((
      notices,
    ) async {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final lastReadTimestamp = prefs.getInt('last_read_notice_ts') ?? 0;
      final latestNoticeTimestamp = notices.isNotEmpty
          ? _toDateTime(notices.first['createdAt']).millisecondsSinceEpoch
          : 0;

      setState(() {
        _notices = notices;
        _hasUnreadNotices = latestNoticeTimestamp > lastReadTimestamp;
      });
    });
  }

  String _startupNoticeKey(String userId, String field) =>
      'startup_notice_${field}_$userId';

  Future<void> _persistStartupNoticeState(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _startupNoticeKey(userId, 'profile_done'),
      _startupProfileChecked,
    );
    await prefs.setBool(
      _startupNoticeKey(userId, 'roommate_done'),
      _startupRoommateChecked,
    );
    await prefs.setBool(
      _startupNoticeKey(userId, 'telegram_done'),
      _startupTelegramChecked,
    );
  }

  Future<void> _loadStartupNoticeState() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.firebaseUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _showStartupNotice = false;
        _startupChecklistSubmitted = false;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final submitted =
        prefs.getBool(_startupNoticeKey(userId, 'submitted')) ?? false;

    var profileChecked =
        prefs.getBool(_startupNoticeKey(userId, 'profile_done')) ?? false;
    var roommateChecked =
        prefs.getBool(_startupNoticeKey(userId, 'roommate_done')) ?? false;
    var telegramChecked =
        prefs.getBool(_startupNoticeKey(userId, 'telegram_done')) ?? false;

    final user = auth.currentUser;
    profileChecked = profileChecked || (user?.isProfileComplete ?? false);
    telegramChecked = telegramChecked ||
        TelegramService.isValidPhone(user?.telegramPhone ?? '');

    if (!roommateChecked) {
      try {
        final profile = await FirebaseService().getRoommateProfileByUserId(
          userId,
        );
        roommateChecked = profile != null;
      } catch (_) {}
    }

    _startupProfileChecked = profileChecked;
    _startupRoommateChecked = roommateChecked;
    _startupTelegramChecked = telegramChecked;
    await _persistStartupNoticeState(userId);

    if (!mounted) return;
    setState(() {
      _startupChecklistSubmitted = submitted;
      _showStartupNotice = !submitted && !_startupDismissedForSession;
    });
  }

  Future<void> _setStartupTaskValue({
    required String task,
    required bool value,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.firebaseUser?.uid;
    if (userId == null) return;

    setState(() {
      if (task == 'profile') _startupProfileChecked = value;
      if (task == 'roommate') _startupRoommateChecked = value;
      if (task == 'telegram') _startupTelegramChecked = value;
    });

    await _persistStartupNoticeState(userId);
  }

  Future<void> _submitStartupChecklist() async {
    if (!_startupProfileChecked ||
        !_startupRoommateChecked ||
        !_startupTelegramChecked) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all checklist items before submit.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.firebaseUser?.uid;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_startupNoticeKey(userId, 'submitted'), true);

    if (!mounted) return;
    setState(() {
      _startupChecklistSubmitted = true;
      _showStartupNotice = false;
    });
  }

  Future<void> _markNoticesAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final latestNoticeTimestamp = _notices.isNotEmpty
        ? _toDateTime(_notices.first['createdAt']).millisecondsSinceEpoch
        : DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('last_read_notice_ts', latestNoticeTimestamp);
    await prefs.setInt('last_read_notice_count', _notices.length);
    setState(() {
      _hasUnreadNotices = false;
    });
  }

  String _formatNoticeTime(dynamic timestamp) {
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        // Firestore Timestamp
        date = (timestamp as dynamic).toDate();
      }
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _noticesSubscription?.cancel();
    _searchController.dispose();
    _commentController.dispose();
    super.dispose();
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
    final firebaseUserId = authProvider.firebaseUser?.uid;

    if (firebaseUserId != null &&
        _startupStateLoadedForUserId != firebaseUserId) {
      _startupStateLoadedForUserId = firebaseUserId;
      _startupDismissedForSession = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadStartupNoticeState();
        }
      });
    }

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _selectedIndex == 0
            ? _buildHomeContent(user)
            : _buildScreenForIndex(_selectedIndex),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildScreenForIndex(int index) {
    switch (index) {
      case 1:
        return const MessagesScreen();
      case 2:
        return const BookmarksScreen();
      case 3:
        return const ProfileScreen();
      default:
        return _buildHomeContent(
          Provider.of<AuthProvider>(context).currentUser,
        );
    }
  }

  Widget _buildHomeContent(UserModel? user) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverToBoxAdapter(child: _buildAppBar(user)),

            if (_showStartupNotice)
              SliverToBoxAdapter(child: _buildStartupNotice()),

            // Search Section
            SliverToBoxAdapter(child: _buildSearchSection()),

            // Quick Categories
            SliverToBoxAdapter(child: _buildQuickCategories()),

            // Two-Column: Top PGs + Top Mess
            SliverToBoxAdapter(child: _buildTopRated()),

            SliverToBoxAdapter(child: _buildCheckoutSection(user)),

            SliverToBoxAdapter(child: _buildFooterSection()),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(UserModel? user) {
    final studentName = user?.name ?? 'Student';
    final universityName = user?.university ?? 'Set university in settings';
    final cityName = _currentCity ?? 'Location';

    // Build avatar: network URL → local file → initials
    Widget avatarContent;
    if (user?.profilePicture != null && user!.profilePicture!.isNotEmpty) {
      avatarContent = Image.network(
        user.profilePicture!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _profileImage != null
            ? Image.file(
                _profileImage!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              )
            : _buildInitialsAvatar(studentName),
      );
    } else if (_profileImage != null) {
      avatarContent = Image.file(
        _profileImage!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      );
    } else {
      avatarContent = _buildInitialsAvatar(studentName);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
                child: avatarContent,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Student Name + University + City
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        universityName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Notification Icon
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  _markNoticesAsRead();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                ),
              ),
              if (_hasUnreadNotices)
                Positioned(
                  top: 12,
                  right: 14,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartupNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Get Started',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppColors.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _showStartupNotice = false;
                  _startupDismissedForSession = true;
                }),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Complete these steps to unlock all features and start connecting with roommates.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.4,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 16),
          _buildStartupChecklistItem(
            checked: _startupProfileChecked,
            text: 'Complete your profile',
            subtitle: 'Add university, course & contact info',
            icon: Icons.person_outline_rounded,
            onChanged: (value) => _setStartupTaskValue(
              task: 'profile',
              value: value,
            ),
            actionLabel: 'Open',
            onAction: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountSettingsScreen(),
                ),
              );
              await _loadStartupNoticeState();
            },
          ),
          _buildStartupChecklistItem(
            checked: _startupRoommateChecked,
            text: 'Create roommate profile',
            subtitle: 'Set preferences to find matches',
            icon: Icons.group_outlined,
            onChanged: (value) => _setStartupTaskValue(
              task: 'roommate',
              value: value,
            ),
            actionLabel: 'Open',
            onAction: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileCreationScreen(),
                ),
              );
              await _loadStartupNoticeState();
            },
          ),
          _buildStartupChecklistItem(
            checked: _startupTelegramChecked,
            text: 'Set Up Chat Profile',
            subtitle: 'Ready for in-app messaging',
            icon: Icons.chat_rounded,
            onChanged: (value) => _setStartupTaskValue(
              task: 'telegram',
              value: value,
            ),
            actionLabel: 'Done',
            onAction: () {
              _setStartupTaskValue(task: 'telegram', value: true);
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startupChecklistSubmitted
                  ? null
                  : _submitStartupChecklist,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _startupChecklistSubmitted ? 'Completed ✓' : 'Submit',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartupChecklistItem({
    required bool checked,
    required String text,
    required String subtitle,
    required IconData icon,
    required ValueChanged<bool> onChanged,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: checked
            ? AppColors.primary.withOpacity(0.04)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: checked
              ? AppColors.primary.withOpacity(0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onChanged(!checked),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? AppColors.primary : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: checked ? AppColors.primary : Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: checked ? AppColors.primary : AppColors.textDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.primary.withOpacity(0.5),
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (!checked)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(String name) {
    final initials = name.isNotEmpty
        ? name
              .trim()
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : '?';
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: AppColors.sectionGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Everything',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primary,
                    height: 1.4,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: ' that a student\nneeds is ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                    height: 1.4,
                  ),
                ),
                TextSpan(
                  text: 'here ✨',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value.trim().toLowerCase());
              },
              decoration: InputDecoration(
                hintText: 'Search PGs or Mess by name...',
                hintStyle: const TextStyle(
                  color: AppColors.textGray,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppColors.textGray,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          // Search results
          if (_searchQuery.isNotEmpty) _buildSearchResults(),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final matchingPGs = _featuredPGs
        .cast<RoomModel>()
        .where(
          (pg) =>
              pg.title.toLowerCase().contains(_searchQuery) ||
              pg.location.toLowerCase().contains(_searchQuery),
        )
        .toList();
    final matchingMess = _featuredMess
        .cast<MessModel>()
        .where(
          (m) =>
              m.name.toLowerCase().contains(_searchQuery) ||
              m.location.toLowerCase().contains(_searchQuery),
        )
        .toList();

    if (matchingPGs.isEmpty && matchingMess.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Center(
          child: Text(
            'No results for "$_searchQuery"',
            style: const TextStyle(color: AppColors.textGray, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (matchingPGs.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              'PGs',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          ...matchingPGs
              .take(3)
              .map(
                (pg) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.home_work,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: Text(
                    pg.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '₹${pg.price.toStringAsFixed(0)}/mo • ${pg.location}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textGray,
                    ),
                  ),
                  onTap: () => SmoothNavigation.push(
                    context,
                    RoomDetailScreen(room: pg),
                  ),
                ),
              ),
        ],
        if (matchingMess.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              'Mess',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          ...matchingMess
              .take(3)
              .map(
                (m) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.restaurant,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: Text(
                    m.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '₹${m.pricepermonth.toStringAsFixed(0)}/mo • ${m.location}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textGray,
                    ),
                  ),
                  onTap: () =>
                      SmoothNavigation.push(context, MessDetailScreen(mess: m)),
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildQuickCategories() {
    final categories = [
      {'icon': Icons.home_work_rounded, 'label': 'PG'},
      {'icon': Icons.restaurant_rounded, 'label': 'Mess'},
      {'icon': Icons.group_rounded, 'label': 'Roomies'},
      {'icon': Icons.build_circle_outlined, 'label': 'Utilities'},
      {'icon': Icons.manage_search_rounded, 'label': 'Lost & Found'},
      {'icon': Icons.shopping_bag_rounded, 'label': 'Market'},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: AppColors.primarySurface,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.25,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return GestureDetector(
            onTap: () {
              switch (cat['label']) {
                case 'PG':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RoomScreen()),
                  );
                  break;
                case 'Mess':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MessScreen()),
                  );
                  break;
                case 'Roomies':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoommateFinderScreen(),
                    ),
                  );
                  break;
                case 'Utilities':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UtilitiesHubScreen(),
                    ),
                  );
                  break;
                case 'Lost & Found':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LostFoundScreen()),
                  );
                  break;
                case 'Market':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MarketScreen()),
                  );
                  break;
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    cat['icon'] as IconData,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat['label'] as String,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    VoidCallback? onSeeAll,
    bool showSeeAll = true,
  }) {
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
        child: Center(child: Text('No PGs available')),
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 150, height: 16, color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Container(width: 100, height: 12, color: Colors.grey.shade200),
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
      onTap: () => SmoothNavigation.push(context, RoomDetailScreen(room: pg)),
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(location, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    "₹$price / month",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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

  Widget _buildQuickTip() {
    return const SizedBox.shrink(); // Replaced by notice board
  }

  /// Two horizontal sliding sections: Top PGs + Top Mess
  Widget _buildTopRated() {
    return Column(
      children: [
        // Section 1: Top PGs — horizontal
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top PGs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RoomScreen()),
                ),
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: _isLoading
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 3,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 200,
                      child: _buildCompactLoadingCard(),
                    ),
                  ),
                )
              : _featuredPGs.isEmpty
              ? Center(child: _buildEmptyColumn('No PGs yet'))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _featuredPGs.length > 5 ? 5 : _featuredPGs.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 220,
                      child: _buildCompactPGCard(_featuredPGs[i] as RoomModel),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),

        // Section 2: Top Mess — horizontal
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Mess',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MessScreen()),
                ),
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: _isLoading
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 3,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 200,
                      child: _buildCompactLoadingCard(),
                    ),
                  ),
                )
              : _featuredMess.isEmpty
              ? Center(child: _buildEmptyColumn('No Mess yet'))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _featuredMess.length > 5
                      ? 5
                      : _featuredMess.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 220,
                      child: _buildCompactMessCard(
                        _featuredMess[i] as MessModel,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCompactPGCard(RoomModel pg) {
    return GestureDetector(
      onTap: () => SmoothNavigation.push(context, RoomDetailScreen(room: pg)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with rating overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: pg.imageurl.isNotEmpty
                      ? Image.network(
                          pg.imageurl,
                          height: 105,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 105,
                          color: AppColors.primary.withOpacity(0.04),
                          child: const Center(
                            child: Icon(
                              Icons.home_work_outlined,
                              size: 32,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                ),
                // Rating badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: AppColors.starColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          pg.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pg.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 11,
                          color: AppColors.textGray,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            pg.location,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textGray,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '₹${pg.price.toStringAsFixed(0)}/mo',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMessCard(MessModel mess) {
    return GestureDetector(
      onTap: () => SmoothNavigation.push(context, MessDetailScreen(mess: mess)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with rating overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: mess.imageurl.isNotEmpty
                      ? Image.network(
                          mess.imageurl,
                          height: 105,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 105,
                          color: AppColors.primary.withOpacity(0.04),
                          child: const Center(
                            child: Icon(
                              Icons.restaurant_outlined,
                              size: 32,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                ),
                // Rating badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: AppColors.starColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          mess.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      mess.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 11,
                          color: AppColors.textGray,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            mess.location,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textGray,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '₹${mess.pricepermonth.toStringAsFixed(0)}/mo',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactLoadingCard() {
    return Container(
      height: 130,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildEmptyColumn(String label) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.textGray),
      ),
    );
  }

  /// Admin notice board — only rendered if _notices is not empty
  DateTime _toDateTime(dynamic timestamp) {
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (_) {
        return DateTime.now();
      }
    }
    try {
      return (timestamp as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  List<Map<String, dynamic>> _checkoutPostsForSelectedDay() {
    final now = DateTime.now();
    final targetDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: _checkoutDayOffset));
    return _notices.where((post) {
      final created = _toDateTime(post['createdAt']);
      final postDay = DateTime(created.year, created.month, created.day);
      return postDay == targetDay;
    }).toList();
  }

  String _checkoutDayLabel() {
    if (_checkoutDayOffset == 0) return 'Today';
    if (_checkoutDayOffset == 1) return 'Yesterday';
    return '$_checkoutDayOffset days ago';
  }

  void _shiftCheckoutDay(int delta) {
    final next = _checkoutDayOffset + delta;
    if (next < 0) return;
    setState(() => _checkoutDayOffset = next);
  }

  Future<void> _toggleCheckoutLike(
    Map<String, dynamic> post,
    UserModel user,
  ) async {
    try {
      await FirebaseService().toggleNoticeLike(
        noticeId: post['id'].toString(),
        userId: user.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update like: $e')));
    }
  }

  Future<void> _sendCheckoutComment(
    Map<String, dynamic> post,
    UserModel user,
  ) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      await FirebaseService().addNoticeComment(
        noticeId: post['id'].toString(),
        userId: user.id,
        userName: user.name,
        text: text,
      );
      _commentController.clear();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to post comment: $e')));
    }
  }

  void _openCommentsSheet(Map<String, dynamic> post, UserModel user) {
    _commentController.clear();
    final commentsRaw = post['comments'] as List? ?? const [];
    final comments = commentsRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              if (comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No comments yet. Start the conversation.',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      final author = comment['userName']?.toString().trim();
                      final text = comment['text']?.toString().trim() ?? '';
                      final createdAt = _formatNoticeTime(comment['createdAt']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              author != null && author.isNotEmpty
                                  ? author
                                  : 'User',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            if (text.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                text,
                                style: const TextStyle(
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                            if (createdAt.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                createdAt,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _sendCheckoutComment(post, user),
                    child: const Text('Send'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckoutSection(UserModel? user) {
    final posts = _checkoutPostsForSelectedDay();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'Checkout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        if (posts.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'No checkout updates for ${_checkoutDayLabel().toLowerCase()}.',
              style: const TextStyle(color: AppColors.textGray),
            ),
          )
        else
          ...posts.map((post) => _buildCheckoutPostCard(post, user)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _checkoutDayOffset > 0
                    ? () => _shiftCheckoutDay(-1)
                    : null,
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
              ),
              Text(
                _checkoutDayLabel(),
                style: const TextStyle(
                  color: AppColors.textGray,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              IconButton(
                onPressed: () => _shiftCheckoutDay(1),
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutPostCard(Map<String, dynamic> post, UserModel? user) {
    final title = post['title']?.toString() ?? '';
    final message = post['message']?.toString() ?? '';
    final imageUrl = post['imageUrl']?.toString() ?? '';
    final likeCount = (post['likeCount'] as num?)?.toInt() ?? 0;
    final commentCount = (post['commentCount'] as num?)?.toInt() ?? 0;
    final likedBy = ((post['likedBy'] as List?) ?? [])
        .map((e) => e.toString())
        .toSet();
    final isLiked = user != null && likedBy.contains(user.id);
    final createdLabel = _formatNoticeTime(post['createdAt']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 190,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 190,
                  color: AppColors.background,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image,
                    color: AppColors.textGray,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                if (title.isNotEmpty && message.isNotEmpty)
                  const SizedBox(height: 6),
                if (message.isNotEmpty)
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textGray,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : AppColors.textGray,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$likeCount',
                      style: const TextStyle(color: AppColors.textGray),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.textGray,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$commentCount',
                      style: const TextStyle(color: AppColors.textGray),
                    ),
                    const Spacer(),
                    if (createdLabel.isNotEmpty)
                      Text(
                        createdLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGray,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: user == null
                            ? null
                            : () => _toggleCheckoutLike(post, user),
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isLiked ? Colors.red : AppColors.primary,
                        ),
                        label: Text(isLiked ? 'Liked' : 'Like'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: user == null
                            ? null
                            : () => _openCommentsSheet(post, user),
                        icon: const Icon(Icons.mode_comment_outlined, size: 16),
                        label: const Text('Comment'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Made with \u2764\uFE0F by TechBuilders',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '© ${DateTime.now().year} Roomix — Student Ecosystem',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final chatProvider = Provider.of<ChatProvider>(context);
    final unreadCount = chatProvider.totalUnreadCount;

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
              _buildNavItem(Icons.chat_bubble_outline, 'Chats', 1, badgeCount: unreadCount),
              _buildNavItem(Icons.bookmark_outline, 'Saved', 2),
              _buildNavItem(Icons.person_outline, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, {int badgeCount = 0}) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textGray,
                size: 24,
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
        child: const Icon(Icons.add, color: Colors.white, size: 28),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
