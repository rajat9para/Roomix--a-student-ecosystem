import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/models/university_model.dart';
import 'package:roomix/providers/user_preferences_provider.dart';
import 'package:roomix/services/firebase_service.dart';
import 'package:roomix/screens/home/home_screen.dart';

class UniversitySelectionScreen extends StatefulWidget {
  final bool isOnboarding;

  const UniversitySelectionScreen({
    Key? key,
    this.isOnboarding = true,
  }) : super(key: key);

  @override
  State<UniversitySelectionScreen> createState() => _UniversitySelectionScreenState();
}

class _UniversitySelectionScreenState extends State<UniversitySelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  List<UniversityModel> _universities = [];
  List<UniversityModel> _filteredUniversities = [];
  UniversityModel? _selectedUniversity;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUniversities();
  }

  Future<void> _loadUniversities() async {
    try {
      setState(() => _isLoading = true);
      
      final firebaseService = FirebaseService();
      final snapshot = await firebaseService.getUniversities(forceRefresh: true);
      
      if (mounted) {
        setState(() {
          _universities = snapshot;
          // Sort alphabetically by default
          _universities.sort((a, b) => a.name.compareTo(b.name));
          _filteredUniversities = List.from(_universities);
          _isLoading = false;
          _errorMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load universities: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _filterUniversities(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredUniversities = List.from(_universities);
      });
      return;
    }

    final lowerQuery = query.toLowerCase().trim();

    setState(() {
      // 1. Filter matches
      var matches = _universities.where((u) {
        return u.name.toLowerCase().contains(lowerQuery) || 
               u.city.toLowerCase().contains(lowerQuery);
      }).toList();

      // 2. Sort by startsWith (real android app feel)
      matches.sort((a, b) {
        final aLower = a.name.toLowerCase();
        final bLower = b.name.toLowerCase();
        
        final aStarts = aLower.startsWith(lowerQuery);
        final bStarts = bLower.startsWith(lowerQuery);
        
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;
        return aLower.compareTo(bLower); // alphabetical fallback
      });

      _filteredUniversities = matches;
    });
  }

  Future<void> _selectUniversity(UniversityModel university) async {
    try {
      final preferencesProvider = context.read<UserPreferencesProvider>();
      await preferencesProvider.setSelectedUniversity(university);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting university: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            if (widget.isOnboarding) _buildProgressBar(),  // ✅ only first time install

            Expanded(
              child: _buildContent(),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          if (!widget.isOnboarding)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.textDark,
                  size: 20,
                ),
              ),
            ),
          if (!widget.isOnboarding) const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Select Your University',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (!widget.isOnboarding) const SizedBox(width: 52),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step 1 of 3',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Getting Started',
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.33,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Find your University',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us tailor your experience and show relevant accommodations near your campus.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textGray,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.border.withOpacity(0.5),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUniversities,
              decoration: InputDecoration(
                hintText: 'Search university name...',
                hintStyle: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 15,
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.textGray),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'SUGGESTED',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textGray.withOpacity(0.7),
              letterSpacing: 1,
            ),
          ),
        ),

        Expanded(
          child: _buildUniversityList(),
        ),
      ],
    );
  }

  Widget _buildUniversityList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGray),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadUniversities,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredUniversities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              color: AppColors.textGray.withOpacity(0.5),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No universities found',
              style: TextStyle(color: AppColors.textGray),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredUniversities.length,
      itemBuilder: (context, index) {
        final university = _filteredUniversities[index];
        final isSelected = _selectedUniversity?.id == university.id;

        return _buildUniversityCard(university, isSelected);
      },
    );
  }

  Widget _buildUniversityCard(UniversityModel university, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUniversity = university;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary.withOpacity(0.3) : AppColors.border.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.1),
                ),
              ),
              child: Center(
                child: Text(
                  university.name.isNotEmpty ? university.name.substring(0, 1).toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    university.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${university.city}, ${university.state}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            Icon(
              isSelected ? Icons.check_circle : Icons.check_circle_outline,
              color: isSelected ? AppColors.primary : Colors.transparent,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedUniversity != null
                  ? () async {
                await _selectUniversity(_selectedUniversity!);

                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                }
              }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: AppColors.textGray.withOpacity(0.3),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              _showRequestUniversityDialog();
            },
            child: Text(
              "Can't find your university? Request to add",
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestUniversityDialog() {
    final nameController = TextEditingController();
    final cityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request University'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'University Name',
                hintText: 'e.g., Stanford University',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cityController,
              decoration: const InputDecoration(
                labelText: 'City',
                hintText: 'e.g., Stanford',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && cityController.text.isNotEmpty) {
                final firebaseService = FirebaseService();
                await firebaseService.createUniversity({
                  'name': nameController.text,
                  'city': cityController.text,
                  'state': 'Unknown',
                  'country': 'India',
                  'isPending': true,
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('University request submitted!'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadUniversities();
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
