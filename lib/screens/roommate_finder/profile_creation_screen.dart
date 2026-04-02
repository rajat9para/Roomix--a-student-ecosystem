import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/providers/roommate_provider.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/utils/smooth_navigation.dart';
import 'package:roomix/providers/user_preferences_provider.dart';
import 'package:roomix/services/location_autocomplete_service.dart';
import 'package:roomix/widgets/location_autocomplete_field.dart';
import 'package:roomix/models/roommate_profile_model.dart';
import 'package:roomix/models/university_model.dart';
import 'package:roomix/services/firebase_service.dart';

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
  bool _hasPrefilledExistingProfile = false;
  
  // Location search
  final LocationAutocompleteService _locationService = LocationAutocompleteService();
  List<LocationPrediction> _locationPredictions = [];
  String _locationSearchQuery = '';
  bool _isLoadingLocations = false;
  
  List<UniversityModel> _universities = [];
  List<UniversityModel> _filteredUniversities = [];

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

  // Removed hardcoded cities - will use dynamic location autocomplete
  // Users can search for any city using the location service

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

    _loadUniversities();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillFromExistingProfile();
    });
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

  Future<void> _prefillFromExistingProfile() async {
    if (_hasPrefilledExistingProfile) return;

    try {
      final provider = context.read<RoommateProvider>();
      if (provider.myProfile == null) {
        await provider.getMyProfile();
      }
      if (!mounted) return;

      final profile = provider.myProfile;
      if (profile == null) return;

      setState(() {
        _applyProfileToForm(profile);
        _hasPrefilledExistingProfile = true;
      });
    } catch (e) {
      debugPrint('Failed to prefill roommate profile form: $e');
    }
  }

  void _applyProfileToForm(RoommateProfile profile) {
    _bioController.text = profile.bio;

    final budget = profile.preferences['budget'];
    if (budget is Map) {
      final min = (budget['min'] as num?)?.toInt() ?? 5000;
      final max = (budget['max'] as num?)?.toInt() ?? 50000;
      _minBudgetController.text = min.toString();
      _maxBudgetController.text = max.toString();
    } else {
      _minBudgetController.text = '5000';
      _maxBudgetController.text = '50000';
    }

    _selectedInterests
      ..clear()
      ..addAll(profile.interests);

    final locations = (profile.preferences['location'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        <String>[];
    _selectedLocations
      ..clear()
      ..addAll(locations);

    final rawLifestyles = (profile.preferences['lifestyle'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        <String>[];
    _selectedLifestyle.clear();
    for (final lifestyle in rawLifestyles) {
      final uiText = lifestyleOptions.firstWhere(
        (option) => option.toLowerCase().replaceAll(' ', '_') == lifestyle,
        orElse: () => lifestyle,
      );
      _selectedLifestyle.add(uiText);
    }

    if (profile.gender.isNotEmpty) {
      _selectedGender = profile.gender;
    }
    if (profile.courseYear.isNotEmpty) {
      _selectedYear = profile.courseYear;
    }
    if (profile.college.isNotEmpty) {
      _collegeController.text = profile.college;
    }
  }

  Future<void> _searchLocations(String query) async {
    if (query.length < 2) {
      setState(() {
        _locationPredictions = [];
        _locationSearchQuery = query;
      });
      return;
    }

    setState(() {
      _locationSearchQuery = query;
      _isLoadingLocations = true;
    });

    try {
      final predictions = await _locationService.search(query, limit: 8);
      if (mounted) {
        setState(() {
          _locationPredictions = predictions;
          _isLoadingLocations = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching locations: $e');
      if (mounted) {
        setState(() {
          _locationPredictions = [];
          _isLoadingLocations = false;
        });
      }
    }
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

  void _addLocation(String location) {
    if (!_selectedLocations.contains(location)) {
      setState(() {
        _selectedLocations.add(location);
      });
    }
  }

  void _removeLocation(String location) {
    setState(() {
      _selectedLocations.remove(location);
    });
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
            GestureDetector(
              onTap: _showUniversityPicker,
              child: AbsorbPointer(
                child: TextField(
                  controller: _collegeController,
                  decoration: InputDecoration(
                    hintText: 'Select your college/university',
                    filled: true,
                    fillColor: AppColors.background,
                    suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
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

            // Preferred Locations - Dynamic Search
            _buildSectionTitle('Preferred Locations'),
            const SizedBox(height: 4),
            Text(
              'Search and add cities you prefer to live in',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textGray,
              ),
            ),
            const SizedBox(height: 12),
            
            // Location Search Field
            _buildLocationSearchField(),
            
            // Selected Locations
            if (_selectedLocations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedLocations.map((location) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _removeLocation(location),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
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

  Widget _buildLocationSearchField() {
    return Column(
      children: [
        TextField(
          onChanged: _searchLocations,
          decoration: InputDecoration(
            hintText: 'Search for a city or area...',
            hintStyle: TextStyle(color: AppColors.textGray, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
            suffixIcon: _isLoadingLocations
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        
        // Predictions dropdown
        if (_locationPredictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _locationPredictions.length > 6 ? 6 : _locationPredictions.length,
              itemBuilder: (context, index) {
                final prediction = _locationPredictions[index];
                return InkWell(
                  onTap: () {
                    _addLocation(prediction.mainText.isNotEmpty 
                        ? prediction.mainText 
                        : prediction.description.split(',').first);
                    setState(() {
                      _locationPredictions = [];
                      _locationSearchQuery = '';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: index < _locationPredictions.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: AppColors.border.withOpacity(0.5),
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prediction.mainText.isNotEmpty 
                                    ? prediction.mainText 
                                    : prediction.description.split(',').first,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              if (prediction.secondaryText.isNotEmpty)
                                Text(
                                  prediction.secondaryText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textGray,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
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

      final auth = context.read<AuthProvider>();
      final actualUsername = auth.currentUser?.name ?? 'User';

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
        username: actualUsername,
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
