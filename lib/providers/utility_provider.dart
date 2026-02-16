import 'package:flutter/material.dart';
import 'package:roomix/models/utility_model.dart';
import 'package:roomix/models/map_marker_model.dart';
import 'package:roomix/services/api_service.dart';

class UtilityProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<UtilityModel> _utilities = [];
  List<UtilityModel> _filteredUtilities = [];
  UtilityModel? _selectedUtility;
  String? _selectedCategory;
  bool _isLoading = false;
  String? _errorMessage;

  List<UtilityModel> get utilities => _utilities;
  List<UtilityModel> get filteredUtilities => _filteredUtilities;
  UtilityModel? get selectedUtility => _selectedUtility;
  String? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final List<String> categories = [
    'All', 'medical', 'grocery', 'xerox', 'stationary', 'pharmacy', 
    'cafe', 'laundry', 'salon', 'bank', 'atm', 'restaurant', 'other'
  ];

  Future<void> fetchUtilities({String? category}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final utilities = await ApiService.getUtilities(category: category);
      _utilities = utilities;
      _filteredUtilities = utilities;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> getUtilitiesByCategory(String category) async {
    _isLoading = true;
    _errorMessage = null;
    _selectedCategory = category == 'All' ? null : category;
    notifyListeners();
    try {
      if (category == 'All') {
        _filteredUtilities = _utilities;
      } else {
        _filteredUtilities = await ApiService.getUtilitiesByCategory(category);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> getUtilitiesNearby(double latitude, double longitude, {int radiusMeters = 5000, String? category}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // Call with correct signature - positional args for lat/lng
      final utilities = await ApiService.getUtilitiesNearby(latitude, longitude);
      _utilities = utilities;
      _filteredUtilities = utilities;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> searchUtilities(String query) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final utilities = query.isEmpty ? _utilities : await ApiService.searchUtilities(query);
      _filteredUtilities = utilities;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> getUtility(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _selectedUtility = await ApiService.getUtility(id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<UtilityModel?> createUtility({
    required String name, required String category,
    required double latitude, required double longitude,
    String? address, String? description, String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final utility = await ApiService.createUtility(
        name: name, category: category, latitude: latitude, longitude: longitude,
        address: address, description: description, phone: phone,
      );
      if (utility != null) {
        _utilities.add(utility);
        _filteredUtilities.add(utility);
      }
      _isLoading = false;
      notifyListeners();
      return utility;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<UtilityModel?> updateUtility(String id, {
    String? name, String? category, double? latitude, double? longitude,
    String? address, String? description, String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final utility = await ApiService.updateUtility(id,
        name: name, category: category, latitude: latitude, longitude: longitude,
        address: address, description: description, phone: phone,
      );
      if (utility != null) {
        final index = _utilities.indexWhere((u) => u.id == id);
        if (index != -1) {
          _utilities[index] = utility;
          _filteredUtilities = List.from(_utilities);
        }
      }
      _isLoading = false;
      notifyListeners();
      return utility;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteUtility(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await ApiService.deleteUtility(id);
      _utilities.removeWhere((u) => u.id == id);
      _filteredUtilities.removeWhere((u) => u.id == id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<UtilityModel?> addReview(String utilityId, {required int rating, String? comment}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // Get current user ID from Firebase
      final userId = 'current_user'; // Replace with actual user ID
      final utility = await ApiService.addReviewToUtility(utilityId,
        userId: userId, rating: rating.toDouble(), comment: comment ?? '',
      );
      if (utility != null) {
        final index = _utilities.indexWhere((u) => u.id == utilityId);
        if (index != -1) {
          _utilities[index] = utility;
          _filteredUtilities = List.from(_utilities);
        }
        if (_selectedUtility?.id == utilityId) _selectedUtility = utility;
      }
      _isLoading = false;
      notifyListeners();
      return utility;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void clearSelected() { _selectedUtility = null; notifyListeners(); }
  void clearFilters() { _selectedCategory = null; _filteredUtilities = _utilities; notifyListeners(); }

  Future<void> getAllUtilitiesAdmin() async {
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      _utilities = await ApiService.getAllUtilitiesAdmin();
      _filteredUtilities = _utilities;
      _isLoading = false; notifyListeners();
    } catch (e) { _errorMessage = e.toString(); _isLoading = false; notifyListeners(); rethrow; }
  }

  Future<void> getPendingUtilitiesAdmin() async {
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      _utilities = await ApiService.getPendingUtilities();
      _filteredUtilities = _utilities;
      _isLoading = false; notifyListeners();
    } catch (e) { _errorMessage = e.toString(); _isLoading = false; notifyListeners(); rethrow; }
  }

  Future<UtilityModel?> verifyUtility(String utilityId) async {
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      final utility = await ApiService.verifyUtility(utilityId);
      if (utility != null) {
        final index = _utilities.indexWhere((u) => u.id == utilityId);
        if (index != -1) { _utilities[index] = utility; _filteredUtilities = List.from(_utilities); }
        if (_selectedUtility?.id == utilityId) _selectedUtility = utility;
      }
      _isLoading = false; notifyListeners(); return utility;
    } catch (e) { _errorMessage = e.toString(); _isLoading = false; notifyListeners(); rethrow; }
  }

  Future<UtilityModel?> rejectUtility(String utilityId, {String? reason}) async {
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      final utility = await ApiService.rejectUtility(utilityId, reason: reason);
      if (utility != null) {
        final index = _utilities.indexWhere((u) => u.id == utilityId);
        if (index != -1) { _utilities[index] = utility; _filteredUtilities = List.from(_utilities); }
        if (_selectedUtility?.id == utilityId) _selectedUtility = utility;
      }
      _isLoading = false; notifyListeners(); return utility;
    } catch (e) { _errorMessage = e.toString(); _isLoading = false; notifyListeners(); rethrow; }
  }

  List<MapMarkerModel> getUtilitiesAsMapMarkers() {
    return _filteredUtilities.where((u) => u.verified).map((u) => MapMarkerModel(
      id: u.id, title: u.name, description: u.description,
      latitude: u.latitude, longitude: u.longitude,
      category: MarkerCategory.utility, imageUrl: u.image,
      address: u.address, metadata: u,
    )).toList();
  }
}
