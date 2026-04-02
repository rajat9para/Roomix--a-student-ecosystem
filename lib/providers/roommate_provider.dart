import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roomix/models/roommate_profile_model.dart';
import 'package:roomix/models/chat_message_model.dart';
import 'package:roomix/services/firebase_service.dart';

class RoommateProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  // Profile state
  RoommateProfile? _myProfile;
  List<RoommateProfile> _allProfiles = [];
  List<RoommateProfile> _matches = [];
  bool _profileComplete = false;
  bool _isLoading = false;
  String? _error;

  // Chat state
  List<ChatMessage> _messages = [];
  List<ChatConversation> _conversations = [];
  String? _selectedConversationId;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _conversationsSubscription;
  StreamSubscription? _profilesSubscription;
  
  // Polling timer for message refresh (fallback)
  Timer? _pollingTimer;
  bool _isPolling = false;

  // Getters
  RoommateProfile? get myProfile => _myProfile;
  List<RoommateProfile> get allProfiles => _allProfiles;
  List<RoommateProfile> get matches => _matches;
  bool get profileComplete => _profileComplete;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ChatMessage> get messages => _messages;
  List<ChatConversation> get conversations => _conversations;
  String? get selectedConversationId => _selectedConversationId;
  bool get isPolling => _isPolling;

  // ==================== PROFILE OPERATIONS ====================

  /// Create or update profile
  Future<void> createProfile(
    String bio,
    List<String> interests,
    Map<String, dynamic> preferences, {
    String? gender,
    String? courseYear,
    String? college,
    String? username,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final userId = _firebaseService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if profile already exists
      final existingProfile = await _firebaseService.getRoommateProfileByUserId(userId);

      if (existingProfile != null) {
        // Build update map — ONLY include non-empty values to prevent overwriting
        final Map<String, dynamic> updates = {
          'bio': bio,
          'interests': interests,
          'preferences': preferences,
        };
        // Only update these fields if they have real values
        if (gender != null && gender.isNotEmpty) updates['gender'] = gender;
        if (courseYear != null && courseYear.isNotEmpty) updates['courseYear'] = courseYear;
        if (college != null && college.isNotEmpty) updates['college'] = college;
        if (username != null && username.isNotEmpty) updates['username'] = username;

        await _firebaseService.updateRoommateProfile(
          existingProfile['id'],
          updates,
        );
        _myProfile = RoommateProfile.fromJson({
          ...existingProfile,
          'bio': bio,
          'interests': interests,
          'preferences': preferences,
          'gender': (gender != null && gender.isNotEmpty) ? gender : existingProfile['gender'],
          'courseYear': (courseYear != null && courseYear.isNotEmpty) ? courseYear : existingProfile['courseYear'],
          'college': (college != null && college.isNotEmpty) ? college : existingProfile['college'],
          'username': (username != null && username.isNotEmpty) ? username : existingProfile['username'],
        });
      } else {
        // Create new profile
        final profileId = await _firebaseService.createRoommateProfile(
          userid: userId,
          username: username ?? 'User',
          bio: bio,
          college: college ?? '',
          courseYear: courseYear ?? '',
          gender: gender ?? 'other',
          interests: interests,
          preferences: preferences,
        );

        _myProfile = RoommateProfile(
          id: profileId,
          userid: userId,
          username: username ?? 'User',
          bio: bio,
          college: college ?? '',
          courseYear: courseYear ?? '',
          gender: gender ?? 'other',
          interests: interests,
          preferences: preferences,
        );
      }

      _profileComplete = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get my profile
  Future<void> getMyProfile() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final userId = _firebaseService.currentUserId;
      if (userId == null) {
        debugPrint('RoommateProvider.getMyProfile: User not authenticated');
        _isLoading = false;
        notifyListeners();
        return;
      }

      final profile = await _firebaseService.getRoommateProfileByUserId(userId);

      if (profile != null) {
        _myProfile = RoommateProfile.fromJson(profile);
        _profileComplete = _myProfile?.isComplete ?? false;
        debugPrint('RoommateProvider.getMyProfile: Profile loaded, complete=$_profileComplete');
      } else {
        debugPrint('RoommateProvider.getMyProfile: No profile found for user');
        _profileComplete = false;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('RoommateProvider.getMyProfile: Error loading profile: $e');
      _error = e.toString();
      _isLoading = false;
      _profileComplete = false;
      notifyListeners();
    }
  }

  /// Get all profiles with real-time updates
void getAllProfiles() {
  try {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _profilesSubscription?.cancel();
    _profilesSubscription = _firebaseService.getRoommateProfiles().listen(
      (profilesData) async {
        var profiles = profilesData
            .map((p) => RoommateProfile.fromJson(p))
            .where((p) => p.userid != _firebaseService.currentUserId)
            .toList();

        // Enrich with actual user names from users collection
        profiles = await _enrichWithUserNames(profiles);

        _allProfiles = profiles;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  } catch (e) {
    _error = e.toString();
    _isLoading = false;
    notifyListeners();
  }
}

/// Enrich roommate profiles with actual user data from users collection
Future<List<RoommateProfile>> _enrichWithUserNames(List<RoommateProfile> profiles) async {
  if (profiles.isEmpty) return profiles;
  try {
    final userIds = profiles.map((p) => p.userid).toSet().toList();
    final Map<String, Map<String, String>> userDataMap = {};

    // Firestore 'in' query supports max 10 items per batch
    for (var i = 0; i < userIds.length; i += 10) {
      final batch = userIds.sublist(i, i + 10 > userIds.length ? userIds.length : i + 10);
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        userDataMap[doc.id] = {
          'name': data['name'] ?? '',
          'course': data['course'] ?? '',
          'year': data['year'] ?? '',
        };
      }
    }

    // Apply real user data to profiles
    return profiles.map((profile) {
      final userData = userDataMap[profile.userid];
      if (userData != null) {
        return profile.copyWith(
          username: userData['name']!.isNotEmpty ? userData['name'] : null,
          course: userData['course']!.isNotEmpty ? userData['course'] : null,
          courseYear: userData['year']!.isNotEmpty ? userData['year'] : null,
        );
      }
      return profile;
    }).toList();
  } catch (e) {
    debugPrint('Error enriching profiles with user data: $e');
    return profiles; // Fallback to original if enrichment fails
  }
}

  /// Get compatible matches using weighted multi-factor scoring
void getMatches() {
  try {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _profilesSubscription?.cancel();
    _profilesSubscription = _firebaseService.getRoommateProfiles().listen(
      (profilesData) async {
        var profiles = profilesData
            .map((p) => RoommateProfile.fromJson(p))
            .where((p) => p.userid != _firebaseService.currentUserId)
            .toList();

        // Enrich with actual user names from users collection
        profiles = await _enrichWithUserNames(profiles);

        if (_myProfile != null) {
          _matches = profiles.map((profile) {
            final compatibility = _calculateCompatibility(_myProfile!, profile);
            return profile.copyWith(compatibility: compatibility);
          }).toList()
            ..sort((a, b) => (b.compatibility ?? 0).compareTo(a.compatibility ?? 0));
        } else {
          _matches = profiles;
        }

        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  } catch (e) {
    _error = e.toString();
    _isLoading = false;
    notifyListeners();
  }
}

  /// Multi-factor weighted compatibility scoring
  /// College: 60%, Course: 15%, Year: 5%, Lifestyle: 3%, Location: 2%
  /// Total: 85% from exact matches, 5% from overlap calculations
  int _calculateCompatibility(RoommateProfile me, RoommateProfile other) {
    double score = 0;

    // --- Same College (60%) — most important factor ---
    if (me.college.isNotEmpty && other.college.isNotEmpty) {
      if (me.college.toLowerCase().trim() == other.college.toLowerCase().trim()) {
        score += 60;
      }
    }

    // --- Same Course (15%) ---
    // Check via courseYear field or preferences
    final myCourse = (me.preferences['course'] as String?) ?? '';
    final otherCourse = (other.preferences['course'] as String?) ?? '';
    if (myCourse.isNotEmpty && otherCourse.isNotEmpty) {
      if (myCourse.toLowerCase().trim() == otherCourse.toLowerCase().trim()) {
        score += 15;
      }
    }

    // --- Same Year (5%) ---
    if (me.courseYear.isNotEmpty && other.courseYear.isNotEmpty) {
      if (me.courseYear.toLowerCase() == other.courseYear.toLowerCase()) {
        score += 5;
      }
    }

    // --- Lifestyle match (3%) ---
    final myLifestyle = (me.preferences['lifestyle'] as List<dynamic>?)
        ?.cast<String>() ?? [];
    final otherLifestyle = (other.preferences['lifestyle'] as List<dynamic>?)
        ?.cast<String>() ?? [];
    if (myLifestyle.isNotEmpty && otherLifestyle.isNotEmpty) {
      final sharedLifestyle = myLifestyle
          .where((l) => otherLifestyle.any(
              (oL) => oL.toLowerCase() == l.toLowerCase()))
          .length;
      final totalUnique = {
        ...myLifestyle.map((l) => l.toLowerCase()),
        ...otherLifestyle.map((l) => l.toLowerCase()),
      }.length;
      score += (sharedLifestyle / totalUnique) * 3;
    }

    // --- Location overlap (2%) ---
    final myLocations = (me.preferences['location'] as List<dynamic>?)
        ?.cast<String>() ?? [];
    final otherLocations = (other.preferences['location'] as List<dynamic>?)
        ?.cast<String>() ?? [];
    if (myLocations.isNotEmpty && otherLocations.isNotEmpty) {
      final sharedLocations = myLocations
          .where((loc) => otherLocations.any(
              (oLoc) => oLoc.toLowerCase() == loc.toLowerCase()))
          .length;
      final totalUnique = {
        ...myLocations.map((l) => l.toLowerCase()),
        ...otherLocations.map((l) => l.toLowerCase()),
      }.length;
      score += (sharedLocations / totalUnique) * 2;
    }

    return score.round().clamp(0, 100);
  }

  /// Delete profile
  Future<void> deleteProfile() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_myProfile != null) {
        await _firebaseService.deleteRoommateProfile(_myProfile!.id);
      }

      _myProfile = null;
      _profileComplete = false;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ==================== CHAT OPERATIONS ====================

  /// Send message
  Future<void> sendMessage(String receiverid, String message) async {
    try {
      _error = null;
      final senderid = _firebaseService.currentUserId;
      if (senderid == null) {
        throw Exception('User not authenticated');
      }

      await _firebaseService.sendMessage(
        senderid: senderid,
        receiverid: receiverid,
        message: message,
      );

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Get messages with a user (real-time)
  void getMessages(String otherUserId) {
    try {
      _selectedConversationId = otherUserId;
      _error = null;
      notifyListeners();

      final currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) return;

      _messagesSubscription?.cancel();
      _messagesSubscription = _firebaseService
          .getChatMessages(currentUserId, otherUserId)
          .listen(
        (messagesData) {
          _messages = messagesData.map((m) => ChatMessage.fromJson(m)).toList();
          notifyListeners();

          // Mark messages as read
          _firebaseService.markConversationAsRead(currentUserId, otherUserId);
        },
        onError: (e) {
          _error = e.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Get all conversations (real-time)
  void getConversations() {
    try {
      _error = null;
      final userId = _firebaseService.currentUserId;
      if (userId == null) return;

      _conversationsSubscription?.cancel();
      _conversationsSubscription = _firebaseService.getConversations(userId).listen(
        (conversationsData) {
          // Convert to ChatConversation objects
          // Note: This is simplified - you'd want to fetch user details for each conversation
          _conversations = conversationsData.map((data) {
            return ChatConversation(
              userId: data['receiverid'] ?? '',
              userName: 'User', // You'd fetch this from user collection
              lastMessage: data['message'] ?? '',
              lastMessageTime: data['timestamp'] != null
                  ? (data['timestamp'] as dynamic).toDate()
                  : DateTime.now(),
              unreadCount: data['read'] == false ? 1 : 0,
            );
          }).toList();
          notifyListeners();
        },
        onError: (e) {
          _error = e.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Mark conversation as read
  Future<void> markAsRead(String otherUserId) async {
    try {
      final currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) return;

      await _firebaseService.markConversationAsRead(currentUserId, otherUserId);
    } catch (e) {
      _error = e.toString();
    }
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    try {
      final userId = _firebaseService.currentUserId;
      if (userId == null) return 0;

      return await _firebaseService.getUnreadCount(userId);
    } catch (e) {
      return 0;
    }
  }

  /// Delete a message by ID
  Future<void> deleteMessage(String messageId) async {
    try {
      _error = null;
      final currentUserId = _firebaseService.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Find and delete the message from Firestore
      await FirebaseFirestore.instance
          .collection('chatmessages')
          .doc(messageId)
          .delete();

      // Remove from local list
      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Start polling for messages (fallback when real-time updates fail)
  void startPolling(String otherUserId, {Duration interval = const Duration(seconds: 5)}) {
    stopPolling(); // Stop any existing polling
    _isPolling = true;
    notifyListeners();

    _pollingTimer = Timer.periodic(interval, (timer) async {
      try {
        final currentUserId = _firebaseService.currentUserId;
        if (currentUserId == null) return;

        final messagesData = await _firebaseService
            .getChatMessages(currentUserId, otherUserId)
            .first;
        
        _messages = messagesData.map((m) => ChatMessage.fromJson(m)).toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  /// Stop polling for messages
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    notifyListeners();
  }

  // ==================== CLEANUP ====================

  /// Clear state
  void clearState() {
    stopPolling();
    _messagesSubscription?.cancel();
    _conversationsSubscription?.cancel();
    _profilesSubscription?.cancel();
    _selectedConversationId = null;
    _messages.clear();
    _conversations.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    _messagesSubscription?.cancel();
    _conversationsSubscription?.cancel();
    _profilesSubscription?.cancel();
    super.dispose();
  }
}
