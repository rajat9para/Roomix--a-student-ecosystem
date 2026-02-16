import 'package:flutter/material.dart';
import 'package:roomix/models/lost_item_model.dart';
import 'package:roomix/services/firebase_service.dart';

class LostFoundProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  
  List<LostItemModel> _items = [];
  List<LostItemModel> _filteredItems = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _currentTab = 'Lost'; // 'Lost' or 'Found'

  List<LostItemModel> get items => _items;
  List<LostItemModel> get filteredItems => _filteredItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentTab => _currentTab;

  Future<void> fetchItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _firebaseService.getLostItems().listen((dataList) {
        _items = dataList.map((data) => LostItemModel.fromJson(data)).toList();
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

  void setTab(String tab) {
    _currentTab = tab;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredItems = _items.where((item) {
      final matchesSearch = item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesTab = item.status.toLowerCase() == _currentTab.toLowerCase();
      return matchesSearch && matchesTab;
    }).toList();
  }

  Future<void> addItem(LostItemModel item) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firebaseService.createLostItem(
        title: item.title,
        description: item.description,
        status: item.status,
        date: item.date,
        location: item.location ?? '',
        contact: item.contact,
        image: item.image,
        userId: item.userId ?? '',
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsResolved(String itemId) async {
    try {
      await _firebaseService.updateLostItem(itemId, {'claimStatus': 'Resolved'});
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _firebaseService.deleteLostItem(itemId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
