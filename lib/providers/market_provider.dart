import 'package:flutter/material.dart';
import 'package:roomix/models/market_item_model.dart';
import 'package:roomix/services/firebase_service.dart';

class MarketProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  
  List<MarketItemModel> _items = [];
  List<MarketItemModel> _filteredItems = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  List<MarketItemModel> get items => _items;
  List<MarketItemModel> get filteredItems => _filteredItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedCategory => _selectedCategory;

  // Categories match those in AddItemScreen
  final List<String> categories = [
    'All',
    'Electronics',
    'Books',
    'Furniture',
    'Clothing',
    'Stationery',
    'Cycles',
    'Others'
  ];

  Future<void> fetchItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _firebaseService.getMarketItems().listen((dataList) {
        _items = dataList.map((data) => MarketItemModel.fromJson(data)).toList();
        _applyFilters();
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredItems = _items.where((item) {
      final matchesSearch = item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> addItem(MarketItemModel item) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firebaseService.createMarketItem(
        title: item.title,
        description: item.description ?? '',
        price: item.price,
        condition: item.condition,
        category: item.category ?? 'Others',
        image: item.image,
        sellerId: item.sellerId ?? '',
        sellerName: item.sellerName,
        sellerContact: item.sellerContact,
      );
      // Refresh handled by stream listener
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsSold(String itemId) async {
    try {
      await _firebaseService.updateMarketItem(itemId, {'sold': true});
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _firebaseService.deleteMarketItem(itemId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
