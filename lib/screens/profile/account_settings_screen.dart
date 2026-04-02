import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/screens/settings/settings_screen.dart';
import 'package:roomix/utils/smooth_navigation.dart';
import 'package:roomix/services/firebase_service.dart';
import 'package:roomix/services/telegram_service.dart';
import 'package:roomix/models/university_model.dart';

import 'package:shared_preferences/shared_preferences.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _courseController = TextEditingController();
  final _startYearController = TextEditingController();
  final _endYearController = TextEditingController();
  final _collegeController = TextEditingController();
  final _telegramController = TextEditingController();
  List<UniversityModel> _universities = [];
  List<UniversityModel> _filteredUniversities = [];
  
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isEditing = true;
  bool _isImageChanged = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUniversities();
  }

  Future<void> _loadUniversities() async {
    try {
      final unis = await FirebaseService().getUniversities();
      if (mounted) {
        setState(() {
          _universities = unis;
          _filteredUniversities = unis;
        });
      }
    } catch (e) {
      debugPrint('Failed to load universities: $e');
    }
  }

  void _loadUserData() {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      _courseController.text = user.course ?? '';
      _collegeController.text = user.collegeName ?? '';
      _telegramController.text = user.telegramPhone ?? '';
      
      // Parse year: "2023-2027" → start=2023, end=2027
      final yearStr = user.year ?? '';
      if (yearStr.contains('-')) {
        final parts = yearStr.split('-');
        _startYearController.text = parts[0].trim();
        _endYearController.text = parts.length > 1 ? parts[1].trim() : '';
      } else {
        _startYearController.text = yearStr;
        _endYearController.text = '';
      }
    }
    _loadSavedImage();
  }

  Future<void> _loadSavedImage() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    
    // If we already have a network image, prioritize that over the local cache
    if (user != null && user.profilePicture != null && user.profilePicture!.isNotEmpty) {
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _courseController.dispose();
    _startYearController.dispose();
    _endYearController.dispose();
    _collegeController.dispose();
    _telegramController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
        _isImageChanged = true;
      });
      // Save the image path
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', picked.path);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    // Validate Telegram phone is mandatory
    final telegramPhone = _telegramController.text.trim();
    if (telegramPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telegram phone number is required for messaging'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (!TelegramService.isValidPhone(telegramPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid Telegram phone number'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      
      if (_isImageChanged && _imageFile != null) {
        await auth.uploadProfileImage(_imageFile!.path);
      }

      await auth.updateProfile({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'course': _courseController.text.trim(),
        'year': '${_startYearController.text.trim()}-${_endYearController.text.trim()}',
        'university': _collegeController.text.trim(),
        'telegramPhone': TelegramService.formatPhone(_telegramController.text),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _isEditing = false;
          _isImageChanged = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
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
      return const Scaffold(
        body: Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Account Settings',
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
          if (!_isEditing)
            TextButton(
              onPressed: () => setState(() => _isEditing = true),
              child: const Text(
                'Edit',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Picture Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: GestureDetector(
                  onTap: _isEditing ? _pickImage : null,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                            width: 4,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 56,
                          backgroundColor: AppColors.background,
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!) as ImageProvider
                              : (user != null && user.profilePicture != null && user.profilePicture!.isNotEmpty)
                                  ? NetworkImage(user.profilePicture!) as ImageProvider
                                  : null,
                          child: (_imageFile == null && (user == null || user.profilePicture == null || user.profilePicture!.isEmpty))
                              ? Icon(
                                  Icons.person,
                                  size: 48,
                                  color: AppColors.primary.withOpacity(0.5),
                                )
                              : null,
                        ),
                      ),
                      if (_isEditing)
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
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Account Information Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'ACCOUNT INFORMATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGray,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    enabled: _isEditing,
                  ),
                  Divider(height: 1, color: AppColors.border.withOpacity(0.5)),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    enabled: false, // Email cannot be changed
                  ),
                  Divider(height: 1, color: AppColors.border.withOpacity(0.5)),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    enabled: _isEditing,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Academic Information Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'ACADEMIC INFORMATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGray,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  // University Picker (tappable field → opens bottom sheet)
                  GestureDetector(
                    onTap: _isEditing ? _showUniversityPicker : null,
                    child: AbsorbPointer(
                      child: _buildTextField(
                        controller: _collegeController,
                        label: 'University/College',
                        icon: Icons.school_outlined,
                        enabled: false,
                        suffixIcon: _isEditing ? Icons.arrow_drop_down : null,
                      ),
                    ),
                  ),
                  // Only show course/year for students (not owners)
                  if (user.role != 'owner') ...[
                  Divider(height: 1, color: AppColors.border.withOpacity(0.5)),
                  _buildTextField(
                    controller: _courseController,
                    label: 'Course',
                    icon: Icons.book_outlined,
                    enabled: _isEditing,
                  ),
                  Divider(height: 1, color: AppColors.border.withOpacity(0.5)),
                  // Start Year & End Year — side by side
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _startYearController,
                            enabled: _isEditing,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Start Year',
                              hintText: 'e.g. 2023',
                              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _endYearController,
                            enabled: _isEditing,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'End Year',
                              hintText: 'e.g. 2027',
                              prefixIcon: const Icon(Icons.school_outlined, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ], // end if (user.role != 'owner')
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Social & Messaging Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text(
                          'SOCIAL & MESSAGING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textGray,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'REQUIRED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildTextField(
                    controller: _telegramController,
                    label: 'Telegram Phone Number (e.g. +91XXXXXXXXXX)',
                    icon: Icons.send_outlined,
                    enabled: _isEditing,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.5),
                ),
              ),
              child: Column(
                children: [
                  _buildActionTile(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: () => _showChangePasswordDialog(),
                  ),
                  Divider(height: 1, color: AppColors.border.withOpacity(0.5)),
                  _buildActionTile(
                    icon: Icons.settings_outlined,
                    title: 'App Settings',
                    subtitle: 'Notifications, privacy, and more',
                    onTap: () => SmoothNavigation.push(context, const SettingsScreen()),
                  ),
                  Divider(height: 1, color: AppColors.border.withOpacity(0.5)),
                  _buildActionTile(
                    icon: Icons.delete_outline,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account',
                    iconColor: AppColors.error,
                    titleColor: AppColors.error,
                    onTap: () => _showDeleteAccountDialog(),
                  ),
                ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    IconData? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.primary : AppColors.textGray,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              textAlign: TextAlign.start,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textDark,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGray,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: AppColors.primary) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUniversityPicker() {
    final searchController = TextEditingController();
    
    // Create a local copy of filtered universities for this dialog session
    List<UniversityModel> localFilteredUniversities = List.from(_universities);

    void filterLocalUniversities(String query, void Function(void Function()) setModalState) {
      if (query.isEmpty) {
        setModalState(() {
          localFilteredUniversities = List.from(_universities);
        });
        return;
      }

      final lowerQuery = query.toLowerCase().trim();

      setModalState(() {
        var matches = _universities.where((u) {
          return u.name.toLowerCase().contains(lowerQuery) || 
                 u.city.toLowerCase().contains(lowerQuery);
        }).toList();

        matches.sort((a, b) {
          final aLower = a.name.toLowerCase();
          final bLower = b.name.toLowerCase();
          
          final aStarts = aLower.startsWith(lowerQuery);
          final bStarts = bLower.startsWith(lowerQuery);
          
          if (aStarts && !bStarts) return -1;
          if (!aStarts && bStarts) return 1;
          return aLower.compareTo(bLower);
        });

        localFilteredUniversities = matches;
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select University',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Type university name...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (query) {
                          filterLocalUniversities(query, setModalState);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (localFilteredUniversities.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 48, color: AppColors.textGray.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text('No universities found', style: TextStyle(color: AppColors.textGray)),
                          ],
                        ),
                      ),
                    // University list
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: localFilteredUniversities.length,
                        itemBuilder: (_, index) {
                          final uni = localFilteredUniversities[index];
                          final isSelected = _collegeController.text == uni.name;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? AppColors.primary
                                  : AppColors.primary.withOpacity(0.1),
                              child: Text(
                                uni.name.isNotEmpty ? uni.name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              uni.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                            ),
                            subtitle: Text(
                              '${uni.city}, ${uni.state}',
                              style: TextStyle(fontSize: 12, color: AppColors.textGray),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: AppColors.primary)
                                : null,
                            onTap: () {
                              setState(() {
                                _collegeController.text = uni.name;
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textGray.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Change Password',
            style: TextStyle(color: AppColors.textDark),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textGray)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (newPasswordController.text != confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Passwords do not match')),
                        );
                        return;
                      }

                      if (newPasswordController.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password must be at least 6 characters')),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        final auth = context.read<AuthProvider>();
                        await auth.changePassword(
                          currentPassword: currentPasswordController.text,
                          newPassword: newPasswordController.text,
                        );

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password changed successfully'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => isLoading = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: AppColors.textDark),
        ),
        content: const Text(
          'This action is permanent and cannot be undone. All your data, listings, and messages will be deleted.',
          style: TextStyle(color: AppColors.textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGray)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show confirmation
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  title: const Text(
                    'Final Confirmation',
                    style: TextStyle(color: AppColors.error),
                  ),
                  content: const Text(
                    'Are you absolutely sure you want to delete your account? This cannot be undone.',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('No, Keep Account'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Yes, Delete Forever', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );

              if (confirmed == true && mounted) {
                try {
                  final auth = context.read<AuthProvider>();
                  await auth.deleteAccount();
                  // Auth provider should handle navigation to login
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
