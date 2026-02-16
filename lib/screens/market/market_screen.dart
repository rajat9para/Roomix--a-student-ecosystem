import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:roomix/providers/market_provider.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/models/market_item_model.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/widgets/loading_indicator.dart';
import 'package:roomix/widgets/filter_bottom_sheet.dart';
import 'package:roomix/widgets/sort_chip.dart';
import 'package:roomix/widgets/bookmark_button.dart';
import 'package:roomix/screens/market/add_item_screen.dart';
import 'package:roomix/screens/market/item_detail_screen.dart';
import 'package:roomix/utils/smooth_navigation.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  late TextEditingController _searchController;
  Timer? _searchDebounceTimer;
  String _sortBy = 'newest';
  
  // Local filters (price/condition) on top of provider's search
  // Provider handles text search and category.
  // We can let provider handle everything or do mixed.
  // MarketProvider has _applyFilters which handles text and category.
  // I will add price/condition filtering locally on the result from provider for now, 
  // or extend provider. Let's keep it simple and do local sort/filter on provider's list.
  
  double _minPrice = 0;
  double _maxPrice = 50000;
  double _selectedMinPrice = 0;
  double _selectedMaxPrice = 50000;
  String? _selectedCondition;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    
    Future.microtask(() {
      Provider.of<MarketProvider>(context, listen: false).fetchItems();
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
      Provider.of<MarketProvider>(context, listen: false).setSearchQuery(query);
    });
  }

  List<MarketItemModel> _getProcessedItems(List<MarketItemModel> items) {
    List<MarketItemModel> results = List.from(items);
    
    // Price filter
    results = results.where((item) => 
      item.price >= _selectedMinPrice && item.price <= _selectedMaxPrice
    ).toList();
    
    // Condition filter
    if (_selectedCondition != null) {
      results = results.where((item) => item.condition == _selectedCondition).toList();
    }
    
    // Sorting
    switch (_sortBy) {
      case 'price-low':
        results.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price-high':
        results.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'newest':
      default:
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Assuming newer first
        break;
    }
    
    return results;
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedCondition != null) count++;
    if (_selectedMinPrice > _minPrice || _selectedMaxPrice < _maxPrice) count++;
    return count;
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FilterBottomSheet(
          title: 'Filter Items',
          sections: [
            FilterSection(
              title: 'Condition',
              type: 'radio',
              filterKey: 'condition',
              options: ['Any', 'New', 'Like New', 'Good', 'Fair', 'Poor'],
            ),
            FilterSection(
              title: 'Price Range',
              type: 'range',
              filterKey: 'price',
              minValue: _minPrice,
              maxValue: _maxPrice,
            ),
          ],
          initialFilters: {
            'condition': _selectedCondition ?? 'Any',
            'price_min': _selectedMinPrice,
            'price_max': _selectedMaxPrice,
          },
          onApply: (filters) {
            setState(() {
              final selectedCondition = filters['condition'] as String?;
              _selectedCondition = (selectedCondition == null || selectedCondition == 'Any')
                  ? null
                  : selectedCondition;
              _selectedMinPrice = (filters['price_min'] as num?)?.toDouble() ?? _minPrice;
              _selectedMaxPrice = (filters['price_max'] as num?)?.toDouble() ?? _maxPrice;
            });
          },
          onReset: () {
            setState(() {
              _selectedCondition = null;
              _selectedMinPrice = _minPrice;
              _selectedMaxPrice = _maxPrice;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine min/max price from all items once loaded
    // ideally provider should give this stat
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Buy & Sell',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Stack(
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _showFilterBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.background,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.tune, size: 20, color: AppColors.textDark),
                    ),
                  ),
                ),
                if (_getActiveFilterCount() > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _getActiveFilterCount().toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  hintStyle: const TextStyle(color: AppColors.textGray),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textGray),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textGray),
                          onPressed: () {
                            _searchController.clear();
                            Provider.of<MarketProvider>(context, listen: false).setSearchQuery('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // Categories (Optional, maybe Sort Chips here)
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  SortChip(
                    label: 'Newest',
                    isActive: _sortBy == 'newest',
                    onTap: () => setState(() => _sortBy = 'newest'),
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  SortChip(
                    label: 'Price Low',
                    isActive: _sortBy == 'price-low',
                    onTap: () => setState(() => _sortBy = 'price-low'),
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  SortChip(
                    label: 'Price High',
                    isActive: _sortBy == 'price-high',
                    onTap: () => setState(() => _sortBy = 'price-high'),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),

          // Items List
          Expanded(
            child: Consumer<MarketProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const LoadingIndicator();
                }

                if (provider.error != null) {
                  return Center(child: Text('Error: ${provider.error}'));
                }

                final displayItems = _getProcessedItems(provider.filteredItems);

                if (displayItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          size: 64,
                          color: AppColors.textGray,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty 
                            ? 'No items match your search'
                            : 'No items available',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => provider.fetchItems(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: displayItems.length,
                    itemBuilder: (context, index) {
                      return _buildItemCard(displayItems[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          SmoothNavigation.push(context, const AddItemScreen());
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Sell Item'),
      ),
    );
  }

  Widget _buildItemCard(MarketItemModel item) {
    return GestureDetector(
      onTap: () {
        SmoothNavigation.push(context, ItemDetailScreen(item: item));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: item.image != null
                        ? CachedNetworkImage(
                            imageUrl: item.image!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey[200]),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, size: 50, color: Colors.grey),
                          ),
                  ),
                ),
                if (item.sold)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'SOLD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₹${item.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.category,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.condition,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                      const Spacer(),
                      // Using BookmarkButton with minimal styling if needed
                      // For now, just a placeholder icon or remove it
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
