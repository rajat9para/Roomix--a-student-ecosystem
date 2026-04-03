import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:roomix/models/utility_model.dart';
import 'package:roomix/models/map_marker_model.dart';
import 'package:roomix/providers/utility_provider.dart';
import 'package:roomix/providers/map_provider.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/widgets/filter_bottom_sheet.dart';
import 'package:roomix/widgets/sort_chip.dart';
import 'package:roomix/utils/smooth_navigation.dart';
import 'package:roomix/screens/utilities/add_utility_screen.dart';
import 'package:roomix/screens/utilities/utility_detail_screen.dart';
import 'package:roomix/screens/utilities/admin_utility_moderation_screen.dart';
import 'package:roomix/screens/map/campus_map_screen.dart';
import 'package:shimmer/shimmer.dart';

class UtilitiesScreen extends StatefulWidget {
  const UtilitiesScreen({super.key});

  @override
  State<UtilitiesScreen> createState() => _UtilitiesScreenState();
}

class _UtilitiesScreenState extends State<UtilitiesScreen> {
  late TextEditingController _searchController;
  Timer? _searchDebounceTimer;
  List<UtilityModel> _allUtilities = [];
  List<UtilityModel> _filteredUtilities = [];
  double? _minRating;
  String _sortBy = 'newest';
  bool _openNowOnly = false;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    
    Future.microtask(() {
      final provider = Provider.of<UtilityProvider>(context, listen: false);
      provider.fetchUtilities();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _applyFilters();
      // Also trigger provider search if needed (using local filter for now based on fetched list)
      // load from provider if search is empty to reset?
      // Actually provider handles search too. Let's use provider search?
      // The original code was doing local filtering on _allUtilities?
      // provider.searchUtilities(query); // If we want server side search
      final provider = Provider.of<UtilityProvider>(context, listen: false);
      provider.searchUtilities(query);
    });
  }

  void _applyFilters() {
    // We are relying on provider for search now, but we can filter locally for other things
    final provider = Provider.of<UtilityProvider>(context, listen: false);
    List<UtilityModel> results = List.from(provider.filteredUtilities);
    
    // Rating filter
    if (_minRating != null) {
      results = results.where((utility) => utility.rating >= _minRating!).toList();
    }
    
    // Open now filter
    if (_openNowOnly) {
      results = results.where((utility) {
        // Implement actual open now logic based on utility opening hours if available
        return true; // Placeholder
      }).toList();
    }
    
    _applySorting(results);
    
    setState(() {
      _filteredUtilities = results;
    });
  }

  void _applySorting(List<UtilityModel> items) {
    switch (_sortBy) {
      case 'rating':
        items.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'newest':
      default:
        // Assuming there is a createdAt or similar. If not, default sort.
        // UtilityModel has createdAt? Let's assume ID or just keep order.
        break;
    }
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_minRating != null) count++;
    if (_openNowOnly) count++;
    return count;
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FilterBottomSheet(
          title: 'Filter Utilities',
          sections: [
            FilterSection(
              title: 'Rating',
              type: 'radio',
              filterKey: 'rating',
              options: ['Any', '3+ Stars', '4+ Stars', '4.5+ Stars'],
            ),
          ],
          initialFilters: {
            'rating': _minRating == null
                ? 'Any'
                : _minRating == 3.0
                    ? '3+ Stars'
                    : _minRating == 4.0
                        ? '4+ Stars'
                        : '4.5+ Stars',
          },
          onApply: (filters) {
            setState(() {
              final ratingString = filters['rating'] as String?;
              if (ratingString == null || ratingString == 'Any') {
                _minRating = null;
              } else if (ratingString == '3+ Stars') {
                _minRating = 3.0;
              } else if (ratingString == '4+ Stars') {
                _minRating = 4.0;
              } else if (ratingString == '4.5+ Stars') {
                _minRating = 4.5;
              }
            });
            _applyFilters();
          },
          onReset: () {
            setState(() {
              _minRating = null;
              _openNowOnly = false;
            });
            _applyFilters();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.currentUser?.role == 'admin';
    final isOwner = authProvider.currentUser?.role == 'owner';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Nearby Utilities',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
        ),
        actions: [
          Badge(
            label: Text('${_getActiveFilterCount()}'),
            isLabelVisible: _getActiveFilterCount() > 0,
            child: IconButton(
              icon: const Icon(Icons.tune, color: Colors.white),
              onPressed: _showFilterBottomSheet,
            ),
          ),
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () {
                  SmoothNavigation.push(
                    context,
                    const AdminUtilityModerationScreen(),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings, size: 20, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Moderate',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Container(
        color: AppColors.scaffoldBackground,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search utilities...',
                    hintStyle: TextStyle(
                      color: AppColors.textGray.withOpacity(0.6),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textGray,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textGray),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textDark),
                ),
              ),
            ),

            // Youth Category Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  'All', 'Grocery', 'Medical', 'Gyms', 'Stationary',
                  'Photostat', 'Gaming', 'Fast Food', 'Cafes',
                ].map((cat) {
                  final isActive = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                        final provider = Provider.of<UtilityProvider>(context, listen: false);
                        if (cat == 'All') {
                          provider.searchUtilities('');
                        } else {
                          provider.searchUtilities(cat);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Sort chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SortChip(
                    label: 'Newest',
                    isActive: _sortBy == 'newest',
                    onTap: () {
                      setState(() {
                        _sortBy = 'newest';
                      });
                      _applyFilters();
                    },
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  SortChip(
                    label: 'Top Rated',
                    isActive: _sortBy == 'rating',
                    onTap: () {
                      setState(() {
                        _sortBy = 'rating';
                      });
                      _applyFilters();
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),

            // Results count
            Consumer<UtilityProvider>(
              builder: (context, provider, _) {
                // Initialize _filteredUtilities if empty (first load handled by provider, but local state needs sync?)
                // Actually we should use provider.filteredUtilities directly for list
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${provider.filteredUtilities.length} utilities',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Utilities list
            Expanded(
              child: Consumer<UtilityProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 5,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (provider.filteredUtilities.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_off,
                            size: 64,
                            color: AppColors.textGray,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty 
                              ? 'No utilities match your search'
                              : 'No utilities found',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try adjusting your filters',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.filteredUtilities.length,
                    itemBuilder: (context, index) {
                      final utility = provider.filteredUtilities[index];
                      return UtilityCard(utility: utility);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'map_fab',
            onPressed: () {
              final utilityProvider = Provider.of<UtilityProvider>(context, listen: false);
              final mapProvider = Provider.of<MapProvider>(context, listen: false);
              final markers = utilityProvider.getUtilitiesAsMapMarkers();
              mapProvider.addMarkers(markers);
              
              SmoothNavigation.push(
                context,
                const CampusMapScreen(
                  filterCategory: MarkerCategory.utility,
                ),
              );
            },
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.map),
          ),
          const SizedBox(height: 16),
          if (isOwner)
            FloatingActionButton(
              heroTag: 'add_fab',
              onPressed: () {
                SmoothNavigation.push(
                  context,
                  const AddUtilityScreen(),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add),
            ),
        ],
      ),
    );
  }
}

class UtilityCard extends StatelessWidget {
  final UtilityModel utility;

  const UtilityCard({
    super.key,
    required this.utility,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SmoothNavigation.push(
          context,
          UtilityDetailScreen(utilityId: utility.id),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: AppColors.elevatedCardDecoration,
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with name and category
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image or placeholder
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border,
                      ),
                      image: utility.image != null
                          ? DecorationImage(
                              image: NetworkImage(utility.image!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: utility.image == null
                        ? const Icon(
                            Icons.location_on,
                            size: 32,
                            color: AppColors.textGray,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                utility.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (utility.verified)
                              const Tooltip(
                                message: 'Verified',
                                child: Icon(
                                  Icons.verified,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            utility.category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${utility.rating.toStringAsFixed(1)} (${utility.reviews.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Address
              if (utility.address != null)
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppColors.textGray,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        utility.address!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              // Contact info if available
              if (utility.contact?['phone'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.phone,
                        size: 14,
                        color: AppColors.textGray,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        utility.contact!['phone'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
