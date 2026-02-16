import 'dart:async';
import 'package:flutter/material.dart';
import 'package:roomix/models/bookmark_model.dart';
import 'package:roomix/services/firebase_service.dart';

class BookmarksProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  List<BookmarkModel> _bookmarks = [];
  List<BookmarkModel> _filteredBookmarks = [];
  bool _isLoading = false;
  String _errorMessage = '';

  // Getters
  List<BookmarkModel> get bookmarks => _bookmarks;
  List<BookmarkModel> get filteredBookmarks => _filteredBookmarks;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // Filter by type
  List<BookmarkModel> getBookmarksByType(String itemtype) {
    return _bookmarks.where((b) => b.itemtype == itemtype).toList();
  }

  // Check if item is bookmarked
  bool isBookmarked(String itemid) {
    return _bookmarks.any((b) => b.itemid == itemid);
  }

  // Count bookmarks by type
  int getCountByType(String itemtype) {
    return _bookmarks.where((b) => b.itemtype == itemtype).length;
  }

  // Get all bookmarks count
  int getTotalCount() => _bookmarks.length;

  // Stream subscription
  StreamSubscription<List<BookmarkModel>>? _bookmarksSubscription;

  /// Fetch bookmarks for a user using real-time stream
  /// If userId is not provided, uses current authenticated user
  Future<void> fetchBookmarks([String? userId]) async {
    final effectiveUserId = userId ?? _firebaseService.currentUserId;
    if (effectiveUserId == null) {
      _errorMessage = 'User not authenticated';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    // Cancel previous subscription if exists
    await _bookmarksSubscription?.cancel();

    _bookmarksSubscription = _firebaseService
        .getBookmarks(effectiveUserId)
        .map((data) => data.map((json) => BookmarkModel.fromJson(json)).toList())
        .listen(
          (bookmarks) {
            _bookmarks = bookmarks;
            _filteredBookmarks = List.from(_bookmarks);
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _errorMessage = 'Failed to fetch bookmarks: $e';
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Add bookmark
  Future<bool> addBookmark({
    required String itemid,
    required String itemtype,
    String? itemTitle,
    String? itemImage,
    double? itemPrice,
  }) async {
    final userId = _firebaseService.currentUserId;
    if (userId == null) {
      _errorMessage = 'User not authenticated';
      notifyListeners();
      return false;
    }

    try {
      final bookmarkId = await _firebaseService.addBookmark(
        userid: userId,
        itemid: itemid,
        itemtype: itemtype,
        itemTitle: itemTitle,
        itemImage: itemImage,
        itemPrice: itemPrice,
        location: itemTitle, // or room.location if available
      );

      // Optimistically add to local list
      final newBookmark = BookmarkModel(
        id: bookmarkId,
        userid: userId,
        itemid: itemid,
        itemtype: itemtype,
        ceratedat: DateTime.now(),
        itemTitle: itemTitle,
        itemImage: itemImage,
        itemPrice: itemPrice,
      );

      _bookmarks.add(newBookmark);
      _filteredBookmarks = List.from(_bookmarks);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add bookmark: $e';
      notifyListeners();
      return false;
    }
  }

  /// Remove bookmark by ID
  Future<bool> removeBookmark(String bookmarkId) async {
    try {
      await _firebaseService.removeBookmark(bookmarkId);

      // Optimistically remove from local list
      _bookmarks.removeWhere((b) => b.id == bookmarkId);
      _filteredBookmarks = List.from(_bookmarks);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to remove bookmark: $e';
      notifyListeners();
      return false;
    }
  }

  /// Remove bookmark by item ID (for quick toggle)
  Future<bool> removeBookmarkByItemId(String itemid) async {
    final userId = _firebaseService.currentUserId;
    if (userId == null) return false;

    try {
      await _firebaseService.removeBookmarkByItemId(userId, itemid);

      // Optimistically remove from local list
      _bookmarks.removeWhere((b) => b.itemid == itemid);
      _filteredBookmarks = List.from(_bookmarks);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to remove bookmark: $e';
      notifyListeners();
      return false;
    }
  }

  /// Toggle bookmark (add if not exists, remove if exists)
  Future<bool> toggleBookmark({
    required String itemid,
    required String itemtype,
    String? itemTitle,
    String? itemImage,
    double? itemPrice,
  }) async {
    if (isBookmarked(itemid)) {
      return removeBookmarkByItemId(itemid);
    } else {
      return addBookmark(
        itemid: itemid,
        itemtype: itemtype,
        itemTitle: itemTitle,
        itemImage: itemImage,
        itemPrice: itemPrice,
      );
    }
  }

  // Filter bookmarks by search query
  void filterBookmarks(String query) {
    if (query.isEmpty) {
      _filteredBookmarks = List.from(_bookmarks);
    } else {
      _filteredBookmarks = _bookmarks
          .where((b) =>
              b.itemid.toLowerCase().contains(query.toLowerCase()) ||
              b.itemtype.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  // Filter by type and search
  void filterByType(String itemtype, {String? query}) {
    _filteredBookmarks =
        _bookmarks.where((b) => b.itemtype == itemtype).toList();

    if (query != null && query.isNotEmpty) {
      _filteredBookmarks = _filteredBookmarks
          .where((b) => b.itemid.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }

    notifyListeners();
  }

  // Sort bookmarks
  void sortBookmarks(String sortBy) {
    switch (sortBy) {
      case 'newest':
        _filteredBookmarks
            .sort((a, b) => (b.ceratedat ?? DateTime.now()).compareTo(a.ceratedat ?? DateTime.now()));
        break;
      case 'oldest':
        _filteredBookmarks
            .sort((a, b) => (a.ceratedat ?? DateTime.now()).compareTo(b.ceratedat ?? DateTime.now()));
        break;
      case 'price-low':
        _filteredBookmarks.sort((a, b) =>
            (a.itemPrice ?? 0).compareTo(b.itemPrice ?? 0));
        break;
      case 'price-high':
        _filteredBookmarks.sort((a, b) =>
            (b.itemPrice ?? 0).compareTo(a.itemPrice ?? 0));
        break;
    }
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  // Clear bookmarks (call on logout)
  void clearBookmarks() {
    _bookmarks = [];
    _filteredBookmarks = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _bookmarksSubscription?.cancel();
    super.dispose();
  }
}
