import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/providers/roommate_provider.dart';
import 'package:roomix/utils/smooth_navigation.dart';
import 'package:roomix/providers/user_preferences_provider.dart';

class ProfileCreationScreen extends StatefulWidget {
  final bool isEditing;

  const ProfileCreationScreen({
    super.key,
    this.isEditing = false,
  });

  @override
  State<ProfileCreationScreen> createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  late TextEditingController _bioController;
  late TextEditingController _minBudgetController;
  late TextEditingController _maxBudgetController;
  late TextEditingController _collegeController;
  String _selectedGender = 'girls';
  String _selectedYear = '1st Year';
  final List<String> _selectedInterests = [];
  final List<String> _selectedLocations = [];
  final List<String> _selectedLifestyle = [];
  bool _isLoading = false;

  final List<String> interestOptions = [
    'Reading',
    'Gaming',
    'Sports',
    'Music',
    'Coding',
    'Cooking',
    'Movies',
    'Fitness',
    'Travel',
    'Art',
  ];

  final List<String> locationOptions = [
    'Delhi',
    'Noida',
    'Gurgaon',
    'Greater Noida',
    'Bangalore',
    'Mumbai',
    'Pune',
  ];

  final List<String> lifestyleOptions = [
    'Early Riser',
    'Night Owl',
    'Quiet',
    'Social',
    'Clean',
    'Relaxed',
  ];

  final List<String> genderOptions = ['girls', 'boys', 'other'];
  final List<String> yearOptions = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    'PG / Masters',
  ];

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController();
    _minBudgetController = TextEditingController(text: '5000');
    _maxBudgetController = TextEditingController(text: '50000');
    _collegeController = TextEditingController();

    final prefs = context.read<UserPreferencesProvider>();
    if (prefs.studentCollege != null && prefs.studentCollege!.isNotEmpty) {
      _collegeController.text = prefs.studentCollege!;
    }
    if (prefs.studentYear != null && prefs.studentYear!.isNotEmpty) {
      _selectedYear = prefs.studentYear!;
    }

    if (widget.isEditing) {
      final provider = context.read<RoommateProvider>();
      if (provider.myProfile != null) {
        _bioController.text = provider.myProfile!.bio;
        _minBudgetController.text =
            (provider.myProfile!.preferences['budget']?['min'] ?? 5000).toInt().toString();
        _maxBudgetController.text =
            (provider.myProfile!.preferences['budget']?['max'] ?? 50000).toInt().toString();
        _selectedInterests.addAll(provider.myProfile!.interests);
        _selectedLocations.addAll(
            (provider.myProfile!.preferences['location'] as List<dynamic>?)?.cast<String>() ?? []);
        _selectedLifestyle.addAll(
            (provider.myProfile!.preferences['lifestyle'] as List<dynamic>?)?.cast<String>() ?? []);
        _selectedGender = provider.myProfile!.gender;
        _selectedYear = provider.myProfile!.courseYear.isNotEmpty
            ? provider.myProfile!.courseYear
            : _selectedYear;
        if (provider.myProfile!.college.isNotEmpty) {
          _collegeController.text = provider.myProfile!.college;
        }
      }
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _minBudgetController.dispose();
    _maxBudgetController.dispose();
    _collegeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Profile' : 'Create Profile'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basics
            _buildSectionTitle('Basics'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    _selectedGender,
                    genderOptions,
                    (value) => setState(() => _selectedGender = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    _selectedYear,
                    yearOptions,
                    (value) => setState(() => _selectedYear = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _collegeController,
              decoration: InputDecoration(
                hintText: 'College name',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Bio
            _buildSectionTitle('About You'),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tell us about yourself...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Interests
            _buildSectionTitle('Interests'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: interestOptions.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedInterests.remove(interest);
                      } else {
                        _selectedInterests.add(interest);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      interest,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // Budget
            _buildSectionTitle('Budget Range (₹)'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minBudgetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Min',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxBudgetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Max',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Preferred Locations
            _buildSectionTitle('Preferred Locations'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: locationOptions.map((location) {
                final isSelected = _selectedLocations.contains(location);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedLocations.remove(location);
                      } else {
                        _selectedLocations.add(location);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      location,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // Lifestyle
            _buildSectionTitle('Lifestyle Preferences'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: lifestyleOptions.map((lifestyle) {
                final isSelected = _selectedLifestyle.contains(lifestyle);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedLifestyle.remove(lifestyle);
                      } else {
                        _selectedLifestyle.add(lifestyle);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      lifestyle,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSaveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.isEditing ? 'Update Profile' : 'Create Profile',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildDropdown(
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: options
              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  Future<void> _handleSaveProfile() async {
    if (_bioController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your bio')),
      );
      return;
    }

    if (_selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one interest')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<RoommateProvider>();
      final minBudget = int.tryParse(_minBudgetController.text) ?? 5000;
      final maxBudget = int.tryParse(_maxBudgetController.text) ?? 50000;

      await provider.createProfile(
        _bioController.text,
        _selectedInterests,
        {
          'budget': {
            'min': minBudget,
            'max': maxBudget,
          },
          'location': _selectedLocations,
          'lifestyle': _selectedLifestyle.isEmpty
              ? ['relaxed']
              : _selectedLifestyle.map((l) => l.toLowerCase().replaceAll(' ', '_')).toList(),
        },
        gender: _selectedGender,
        courseYear: _selectedYear,
        college: _collegeController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
