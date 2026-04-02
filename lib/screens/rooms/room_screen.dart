import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/services/api_service.dart';
import 'package:roomix/models/room_model.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/widgets/room_card.dart';
import 'package:roomix/widgets/loading_indicator.dart';
import 'package:roomix/widgets/filter_bottom_sheet.dart';
import 'package:roomix/widgets/sort_chip.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late AuthProvider _authProvider;
  List<RoomModel> _allRooms = [];
  List<RoomModel> _filteredRooms = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Search and Filter state
  final TextEditingController _searchController = TextEditingController();
  String _selectedSort = 'newest';
  Timer? _searchDebounce;
  
  // Filter options
  Set<String> _selectedCategories = {};
  Set<String> _selectedAmenities = {};
  double _minPrice = 0;
  double _maxPrice = 50000;
  double _selectedMinPrice = 0;
  double _selectedMaxPrice = 50000;
  bool _verifiedOnly = false;
  double? _minRating;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _applyFilters();
    });
  }

  Future<void> _fetchRooms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // ApiService.getRooms() already returns List<RoomModel>
      _allRooms = await ApiService.getRooms();
      
      // Calculate price range from fetched rooms
      if (_allRooms.isNotEmpty) {
        final prices = _allRooms.map((r) => r.price).toList();
        _minPrice = prices.reduce((a, b) => a < b ? a : b);
        _maxPrice = prices.reduce((a, b) => a > b ? a : b);
        _selectedMaxPrice = _maxPrice;
      }
      
      _applyFilters();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<RoomModel> filtered = List.from(_allRooms);
    final searchQuery = _searchController.text.toLowerCase();

    // Search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((room) =>
              room.title.toLowerCase().contains(searchQuery) ||
              room.location.toLowerCase().contains(searchQuery) ||
              room.type.toLowerCase().contains(searchQuery) ||
              room.amenities.any((a) => a.toLowerCase().contains(searchQuery)))
          .toList();
    }

    // Category filter
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered.where((room) {
        final roomType = room.type.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
        return _selectedCategories.any((category) {
          final cat = category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
          return roomType.contains(cat) || cat.contains(roomType);
        });
      }).toList();
    }

    // Price range filter
    filtered = filtered
        .where((room) {
          final roomPrice = room.price;
          return roomPrice >= _selectedMinPrice && roomPrice <= _selectedMaxPrice;
        })
        .toList();

    // Amenities filter
    if (_selectedAmenities.isNotEmpty) {
      filtered = filtered
          .where((room) {
            final roomAmenities = room.amenities
                .map((a) => a.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ''))
                .toSet();
            return _selectedAmenities.every((amenity) {
              final key = amenity.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
              return roomAmenities.contains(key);
            });
          })
          .toList();
    }

    // Verified only filter
    if (_verifiedOnly) {
      filtered = filtered.where((room) => room.verified).toList();
    }

    // Rating filter
    if (_minRating != null) {
      filtered = filtered
          .where((room) => room.rating >= _minRating!)
          .toList();
    }

    // Apply sorting
    _applySorting(filtered);

    setState(() {
      _filteredRooms = filtered;
    });
  }

  void _applySorting(List<RoomModel> rooms) {
    switch (_selectedSort) {
      case 'price_low':
        rooms.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        rooms.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        rooms.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'newest':
      default:
        break;
    }
  }

  Future<void> _handleContactOwner(String contactNumber) async {
    final Uri phoneUri = Uri.parse('tel:$contactNumber');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone dialer')),
      );
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return FilterBottomSheet(
          title: 'Filter Rooms',
          sections: [
            FilterSection(
              title: 'Room Type',
              type: 'checkbox',
              options: ['Single Room', 'Double Room', 'Triple Room', 'PG', 'Hostel'],
            ),
            FilterSection(
              title: 'Price Range',
              type: 'range',
              filterKey: 'price',
              minValue: _minPrice,
              maxValue: _maxPrice,
            ),
            FilterSection(
              title: 'Amenities',
              type: 'checkbox',
              options: ['WiFi', 'AC', 'Attached Bathroom', 'Parking', 'Meals'],
            ),
            FilterSection(
              title: 'Rating',
              type: 'radio',
              filterKey: 'rating',
              options: ['Any', '3+ Stars', '4+ Stars', '4.5+ Stars'],
            ),
          ],
          initialFilters: {
            for (final c in _selectedCategories) c: true,
            'price_min': _selectedMinPrice,
            'price_max': _selectedMaxPrice,
            for (final a in _selectedAmenities) a: true,
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
              _selectedCategories = filters.entries
                  .where((e) =>
                      ['Single Room', 'Double Room', 'Triple Room', 'PG', 'Hostel']
                          .contains(e.key) &&
                      e.value == true)
                  .map((e) => e.key as String)
                  .toSet();
              _selectedMinPrice = (filters['price_min'] as num?)?.toDouble() ?? _minPrice;
              _selectedMaxPrice = (filters['price_max'] as num?)?.toDouble() ?? _maxPrice;
              _selectedAmenities = filters.entries
                  .where((e) =>
                      ['WiFi', 'AC', 'Attached Bathroom', 'Parking', 'Meals']
                          .contains(e.key) &&
                      e.value == true)
                  .map((e) => e.key as String)
                  .toSet();

              final ratingString = filters['rating'] as String?;
              if (ratingString == 'Any') {
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
              _selectedCategories.clear();
              _selectedAmenities.clear();
              _selectedMinPrice = _minPrice;
              _selectedMaxPrice = _maxPrice;
              _minRating = null;
              _verifiedOnly = false;
            });
            _applyFilters();
          },
        );
      },
    );
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategories.isNotEmpty) count++;
    if (_selectedMinPrice > _minPrice || _selectedMaxPrice < _maxPrice) count++;
    if (_selectedAmenities.isNotEmpty) count++;
    if (_minRating != null) count++;
    if (_verifiedOnly) count++;
    if (_searchController.text.isNotEmpty) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    _authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Find Your Room'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          Badge(
            label: Text('${_activeFilterCount}'),
            isLabelVisible: _activeFilterCount > 0,
            child: IconButton(
              icon: const Icon(Icons.tune),
              onPressed: _showFilterBottomSheet,
            ),
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Search rooms...',
                  hintStyle: const TextStyle(color: AppColors.textGray),
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),

                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    color: AppColors.textGray,
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                  )
                      : null,

                  filled: true,
                  fillColor: Colors.white,

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  SortChip(
                    label: 'Newest',
                    icon: Icons.fiber_new,
                    isActive: _selectedSort == 'newest',
                    onTap: () {
                      setState(() => _selectedSort = 'newest');
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 8),
                  SortChip(
                    label: 'Price: Low-High',
                    icon: Icons.trending_down,
                    isActive: _selectedSort == 'price_low',
                    onTap: () {
                      setState(() => _selectedSort = 'price_low');
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 8),
                  SortChip(
                    label: 'Price: High-Low',
                    icon: Icons.trending_up,
                    isActive: _selectedSort == 'price_high',
                    onTap: () {
                      setState(() => _selectedSort = 'price_high');
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 8),
                  SortChip(
                    label: 'Rating',
                    icon: Icons.star,
                    isActive: _selectedSort == 'rating',
                    onTap: () {
                      setState(() => _selectedSort = 'rating');
                      _applyFilters();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filteredRooms.length} room${_filteredRooms.length != 1 ? 's' : ''} found',
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const LoadingIndicator()
                  : _errorMessage.isNotEmpty
                      ? _buildErrorState()
                      : _filteredRooms.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _fetchRooms,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredRooms.length,
                                itemBuilder: (context, index) {
                                  return RoomCard(
                                    room: _filteredRooms[index],
                                    onContactPressed: () => _handleContactOwner(
                                        _filteredRooms[index].contact),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: AppColors.textSubtle),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty ? 'No rooms match your search' : 'No rooms found',
            style: const TextStyle(fontSize: 18, color: AppColors.textDark, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Try adjusting your filters or search criteria',
              style: TextStyle(fontSize: 14, color: AppColors.textGray)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              _searchController.clear();
              setState(() {
                _selectedCategories.clear();
                _selectedAmenities.clear();
                _selectedMinPrice = _minPrice;
                _selectedMaxPrice = _maxPrice;
                _minRating = null;
              });
              _applyFilters();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Clear All Filters',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: AppColors.textSubtle),
          const SizedBox(height: 16),
          const Text('Error loading rooms',
              style: TextStyle(fontSize: 18, color: AppColors.textDark, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_errorMessage, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textGray)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _fetchRooms,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
