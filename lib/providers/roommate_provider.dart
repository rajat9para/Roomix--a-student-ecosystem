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
        // Update existing profile
        await _firebaseService.updateRoommateProfile(
          existingProfile['id'],
          {
            'bio': bio,
            'interests': interests,
            'preferences': preferences,
            'gender': gender ?? 'other',
            'courseYear': courseYear ?? '',
            'college': college ?? '',
            'username': username ?? '',
          },
        );
        _myProfile = RoommateProfile.fromJson({
          ...existingProfile,
          'bio': bio,
          'interests': interests,
          'preferences': preferences,
          'gender': gender,
          'courseYear': courseYear,
          'college': college,
          'username': username,
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
        throw Exception('User not authenticated');
      }

      final profile = await _firebaseService.getRoommateProfileByUserId(userId);

      if (profile != null) {
        _myProfile = RoommateProfile.fromJson(profile);
        _profileComplete = _myProfile?.isComplete ?? false;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
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
        (profilesData) {
          _allProfiles = profilesData
              .map((p) => RoommateProfile.fromJson(p))
              .where((p) => p.userid != _firebaseService.currentUserId) // Exclude self
              .toList();
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

  /// Get compatible matches (simple implementation - can be enhanced)
  void getMatches() {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _profilesSubscription?.cancel();
      _profilesSubscription = _firebaseService.getRoommateProfiles().listen(
        (profilesData) {
          final profiles = profilesData
              .map((p) => RoommateProfile.fromJson(p))
              .where((p) => p.userid != _firebaseService.currentUserId)
              .toList();

          // Simple matching algorithm based on shared interests
          if (_myProfile != null) {
            _matches = profiles.map((profile) {
              final sharedInterests = profile.interests
                  .where((i) => _myProfile!.interests.contains(i))
                  .length;
              final compatibility =
                  (sharedInterests / (_myProfile!.interests.length + profile.interests.length) * 100)
                      .round();
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
