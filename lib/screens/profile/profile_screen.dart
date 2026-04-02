import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/screens/auth/auth_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roomix/screens/splash_screen.dart';
import 'package:roomix/screens/bookmarks/bookmarks_screen.dart';
import 'package:roomix/screens/profile/my_listings_screen.dart';
import 'package:roomix/screens/profile/account_settings_screen.dart';
import 'package:roomix/screens/profile/help_support_screen.dart';
import 'package:roomix/screens/roommate_finder/profile_creation_screen.dart';
import 'package:roomix/screens/settings/settings_screen.dart';
import 'package:roomix/screens/profile/account_settings_screen.dart';
import 'package:roomix/services/telegram_service.dart';
import 'package:roomix/utils/smooth_navigation.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _courseController = TextEditingController();
  final _yearController = TextEditingController();
  final _collegeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _telegramController = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    _nameController.text = user?.name ?? '';
    _courseController.text = user?.course ?? '';
    _yearController.text = user?.year ?? '';
    _collegeController.text = user?.collegeName ?? '';
    _phoneController.text = user?.contactNumber ?? '';
    _telegramController.text = user?.telegramPhone ?? '';
    _loadSavedImage();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _courseController.dispose();
    _yearController.dispose();
    _collegeController.dispose();
    _phoneController.dispose();
    _telegramController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedImage() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    // If we already have a network image, prioritize that over the local cache
    if (user != null &&
        user.profilePicture != null &&
        user.profilePicture!.isNotEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');

    if (path != null && File(path).existsSync()) {
      setState(() {
        _imageFile = File(path);
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
      // Auto-upload immediately after picking
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      await auth.uploadProfileImage(_imageFile!.path);

      // Also save locally for quick access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', _imageFile!.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  double _calculateCompleteness() {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return 0.0;

    int totalPoints = 0;
    // Baseline: name + email always filled at registration = 15%
    if (user.name.isNotEmpty) totalPoints += 8;
    if (user.email.isNotEmpty) totalPoints += 7;

    // Academic (40%)
    if (user.university != null && user.university!.isNotEmpty)
      totalPoints += 15;
    if (user.course != null && user.course!.isNotEmpty) totalPoints += 13;
    if (user.year != null && user.year!.isNotEmpty) totalPoints += 12;

    // Personal (45%)
    if (user.phone != null && user.phone!.isNotEmpty) totalPoints += 15;
    if (user.profilePicture != null && user.profilePicture!.isNotEmpty)
      totalPoints += 15;
    if (user.telegramPhone != null && user.telegramPhone!.isNotEmpty)
      totalPoints += 15;

    return totalPoints / 100;
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    final auth = context.read<AuthProvider>();
    setState(() => _isLoading = true);
    try {
      await auth.updateProfile({
        'name': _nameController.text.trim(),
        'course': _courseController.text.trim(),
        'year': _yearController.text.trim(),
        'university': _collegeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'telegramPhone': TelegramService.formatPhone(_telegramController.text),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }
    final completeness = _calculateCompleteness();
    final percentage = (completeness * 100).toInt();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profile',
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
            icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
            onPressed: () =>
                SmoothNavigation.push(context, const SettingsScreen()),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  // Profile Picture
                  GestureDetector(
                    onTap: _isLoading ? null : _pickImage,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                              width: 4,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: AppColors.background,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!) as ImageProvider
                                : (user != null &&
                                      user.profilePicture != null &&
                                      user.profilePicture!.isNotEmpty)
                                ? NetworkImage(user.profilePicture!)
                                      as ImageProvider
                                : null,
                            child:
                                (_imageFile == null &&
                                    (user == null ||
                                        user.profilePicture == null ||
                                        user.profilePicture!.isEmpty))
                                ? Icon(
                                    Icons.person,
                                    size: 48,
                                    color: AppColors.primary.withOpacity(0.5),
                                  )
                                : null,
                          ),
                        ),
                        if (!_isLoading)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(
                                'create' == 'create'
                                    ? Icons.edit
                                    : Icons
                                          .edit, // Using literal check to force icon usage if needed
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // User Name
                  Text(
                    user?.name ?? 'User Name',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (user?.role ?? 'Student').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Campus ID
                  Text(
                    user == null
                        ? 'Campus ID: N/A'
                        : 'Campus ID: #${user.id.substring(0, min(8, user.id.length)).toUpperCase()}',
                    style: TextStyle(fontSize: 13, color: AppColors.textGray),
                  ),
                ],
              ),
            ),

            // Update Picture Button
            if (_imageFile != null)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _uploadImage,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_isLoading ? 'Uploading...' : 'Update Picture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ─────────── YOUR DETAILS CARD ───────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => SmoothNavigation.push(
                            context,
                            const AccountSettingsScreen(),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      Icons.person_outline,
                      'Name',
                      user.name.isNotEmpty ? user.name : 'Not set',
                    ),
                    _buildDetailRow(
                      Icons.school_outlined,
                      'University',
                      user.university ?? 'Not set',
                    ),
                    _buildDetailRow(
                      Icons.menu_book_outlined,
                      'Course',
                      user.course ?? 'Not set',
                    ),
                    _buildDetailRow(
                      Icons.calendar_today_outlined,
                      'Year',
                      user.year != null && user.year!.isNotEmpty
                          ? user.year!
                          : 'Not set',
                    ),
                    _buildDetailRow(Icons.email_outlined, 'Email', user.email),
                    _buildDetailRow(
                      Icons.telegram,
                      'Telegram',
                      user.telegramPhone ?? 'Not set',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Management Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MANAGEMENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textGray.withOpacity(0.7),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.bookmark_outline,
                          title: 'My Bookmarks',
                          onTap: () => SmoothNavigation.push(
                            context,
                            const BookmarksScreen(),
                          ),
                        ),
                        // Only show My Listings for owners, not students
                        if (user.role != 'student') ...[
                          Divider(
                            height: 1,
                            color: AppColors.border.withOpacity(0.5),
                          ),
                          _buildMenuItem(
                            icon: Icons.list_alt_outlined,
                            title: 'My Listings',
                            onTap: () => SmoothNavigation.push(
                              context,
                              const MyListingsScreen(),
                            ),
                          ),
                        ],
                        if (user.role == 'student') ...[
                          Divider(
                            height: 1,
                            color: AppColors.border.withOpacity(0.5),
                          ),
                          _buildMenuItem(
                            icon: Icons.group_outlined,
                            title: 'Roommate Preferences',
                            trailing: Text(
                              user.university != null &&
                                      user.university!.isNotEmpty
                                  ? 'UPDATE'
                                  : 'SET UP',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            onTap: () => SmoothNavigation.push(
                              context,
                              const ProfileCreationScreen(isEditing: true),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Application Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APPLICATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textGray.withOpacity(0.7),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.person_outline,
                          title: 'Account Settings',
                          iconColor: AppColors.textGray,
                          onTap: () => SmoothNavigation.push(
                            context,
                            const AccountSettingsScreen(),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: AppColors.border.withOpacity(0.5),
                        ),
                        _buildMenuItem(
                          icon: Icons.help_center_outlined,
                          title: 'Help & Support',
                          iconColor: AppColors.textGray,
                          onTap: () => SmoothNavigation.push(
                            context,
                            const HelpSupportScreen(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
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
                    if (confirmed != true) return;
                    final authRef = context.read<AuthProvider>();
                    try {
                      await authRef.logout();
                      if (!mounted) return;
                      // Use pushAndRemoveUntil to force fresh AuthGate
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
                  },

                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // App Version
            Center(
              child: Text(
                'Roomix v2.4.0',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGray.withOpacity(0.5),
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final isSet = value != 'Not set' && value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSet
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isSet ? AppColors.primary : AppColors.textGray,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSet
                        ? AppColors.textDark
                        : AppColors.textGray.withOpacity(0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? badge,
    Widget? trailing,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textGray,
                  ),
                ),
              ),
            if (trailing != null) trailing,
            if (badge == null && trailing == null)
              Icon(
                Icons.chevron_right,
                color: AppColors.textGray.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }
}
