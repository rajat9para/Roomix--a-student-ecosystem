import 'package:flutter/material.dart';
import 'package:roomix/models/university_model.dart';
import 'package:roomix/services/api_service.dart';
import 'package:roomix/utils/storage_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserPreferencesProvider extends ChangeNotifier {
  final StorageUtil _storageUtil = StorageUtil();
  UniversityModel? _selectedUniversity;

  bool _isOnboardingComplete = false;
  bool _isLoading = false;
  double? _campusLat;
  double? _campusLng;
  String? _campusAddress;
  String? _studentCourse;
  String? _studentYear;
  String? _studentCollege;
  String? _studentContact;

  UniversityModel? get selectedUniversity => _selectedUniversity;
  bool get isOnboardingComplete => _isOnboardingComplete;
  bool get isLoading => _isLoading;
  double? get campusLat => _campusLat;
  double? get campusLng => _campusLng;
  String? get campusAddress => _campusAddress;
  String? get studentCourse => _studentCourse;
  String? get studentYear => _studentYear;
  String? get studentCollege => _studentCollege;
  String? get studentContact => _studentContact;

  /// Load user preferences from local storage
  Future<void> loadUserPreferences() async {
    _isLoading = true;
    notifyListeners();

    try {
      final savedUniversityId = await _storageUtil.getSelectedUniversity();
      final onboardingComplete = await _storageUtil.getOnboardingComplete();
      final campusLocation = await _storageUtil.getCampusLocation();
      final studentProfile = await _storageUtil.getStudentProfile();

      _isOnboardingComplete = onboardingComplete;
      if (campusLocation != null) {
        _campusLat = campusLocation['latitude'] as double?;
        _campusLng = campusLocation['longitude'] as double?;
        _campusAddress = campusLocation['address'] as String?;
      }
      if (studentProfile != null) {
        _studentCourse = studentProfile['course'];
        _studentYear = studentProfile['year'];
        _studentCollege = studentProfile['college'];
        _studentContact = studentProfile['contact'];
      }
      
      // If university ID is saved, fetch and set the university model
      if (savedUniversityId != null && savedUniversityId.isNotEmpty) {
        try {
          final university = await ApiService.getUniversityById(savedUniversityId);
          _selectedUniversity = university;
        } catch (e) {
          debugPrint('Error fetching saved university details: $e');
          // University ID saved but fetch failed - keep ID for reference
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user preferences: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set selected university and save to storage
  Future<void> setSelectedUniversity(UniversityModel university) async {
    _selectedUniversity = university;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'selected_university',
      jsonEncode(university.toJson()),
    );

    notifyListeners();
  }

  Future<void> loadSelectedUniversity() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('selected_university');

    if (data != null) {
      _selectedUniversity = UniversityModel.fromJson(jsonDecode(data));
      notifyListeners();
    }
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    _isOnboardingComplete = true;
    notifyListeners();

    try {
      await _storageUtil.saveOnboardingComplete(true);
    } catch (e) {
      debugPrint('Error saving onboarding completion: $e');
    }
  }

  /// Clear user preferences
  Future<void> clearPreferences() async {
    _selectedUniversity = null;
    _isOnboardingComplete = false;
    _campusLat = null;
    _campusLng = null;
    _campusAddress = null;
    _studentCourse = null;
    _studentYear = null;
    _studentCollege = null;
    _studentContact = null;
    notifyListeners();

    try {
      await _storageUtil.clearSelectedUniversity();
      await _storageUtil.clearOnboardingComplete();
      await _storageUtil.clearCampusLocation();
      await _storageUtil.clearStudentProfile();
    } catch (e) {
      debugPrint('Error clearing preferences: $e');
    }
  }

  /// Get selected university ID
  Future<String?> getSelectedUniversityId() async {
    return await _storageUtil.getSelectedUniversity();
  }

  Future<void> saveCampusLocation({
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    _campusLat = latitude;
    _campusLng = longitude;
    _campusAddress = address;
    notifyListeners();

    try {
      await _storageUtil.saveCampusLocation(
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
    } catch (e) {
      debugPrint('Error saving campus location: $e');
    }
  }

  Future<void> saveStudentProfile({
    required String course,
    required String year,
    required String college,
    String? contact,
  }) async {
    _studentCourse = course;
    _studentYear = year;
    _studentCollege = college;
    _studentContact = contact;
    notifyListeners();

    try {
      await _storageUtil.saveStudentProfile(
        course: course,
        year: year,
        college: college,
        contact: contact,
      );
    } catch (e) {
      debugPrint('Error saving student profile: $e');
    }
  }
}
