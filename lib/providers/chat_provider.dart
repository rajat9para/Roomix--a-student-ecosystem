import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Cached user profile data for chat tiles
class ChatUserProfile {
  final String id;
  final String name;
  final String? profilePicture;

  ChatUserProfile({
    required this.id,
    required this.name,
    this.profilePicture,
  });
}

/// A conversation thread (shown in the chat list)
class ChatThread {
  final String partnerId;
  final String partnerName;
  final String? partnerPhoto;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isLastMessageMine;

  ChatThread({
    required this.partnerId,
    required this.partnerName,
    this.partnerPhoto,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isLastMessageMine,
  });
}

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserId;
  String? _currentUserName;

  List<ChatThread> _conversations = [];
  List<ChatThread> get conversations => _conversations;

  int _totalUnreadCount = 0;
  int get totalUnreadCount => _totalUnreadCount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _initialized = false;

  StreamSubscription? _sentSubscription;
  StreamSubscription? _receivedSubscription;

  /// Cache for user profiles to avoid repeated Firestore lookups
  final Map<String, ChatUserProfile> _userProfileCache = {};

  /// Raw messages from both streams
  List<Map<String, dynamic>> _sentMessages = [];
  List<Map<String, dynamic>> _receivedMessages = [];

  /// Debounce timer to avoid rebuilding conversations too frequently
  Timer? _rebuildDebounce;

  /// Initialize with current user ID — safe to call multiple times
  void initialize(String userId, String userName) {
    if (_initialized && _currentUserId == userId) return;
    _currentUserId = userId;
    _currentUserName = userName;
    _initialized = true;
    _listenToConversations();
  }

  /// Clean up when user logs out
  void clear() {
    _sentSubscription?.cancel();
    _receivedSubscription?.cancel();
    _rebuildDebounce?.cancel();
    _currentUserId = null;
    _currentUserName = null;
    _conversations = [];
    _totalUnreadCount = 0;
    _sentMessages = [];
    _receivedMessages = [];
    _userProfileCache.clear();
    _initialized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sentSubscription?.cancel();
    _receivedSubscription?.cancel();
    _rebuildDebounce?.cancel();
    super.dispose();
  }

  /// Listen to both sent and received messages to build conversation list
  void _listenToConversations() {
    if (_currentUserId == null) return;

    _isLoading = true;
    notifyListeners();

    // Listen to messages I SENT — limited to last 200 for performance
    _sentSubscription?.cancel();
    _sentSubscription = _firestore
        .collection('chatmessages')
        .where('senderid', isEqualTo: _currentUserId)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .listen((snapshot) {
      _sentMessages = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      _debouncedBuildConversations();
    }, onError: (e) {
      debugPrint('ChatProvider: Error listening to sent messages: $e');
      _isLoading = false;
      notifyListeners();
    });

    // Listen to messages I RECEIVED — limited to last 200 for performance
    _receivedSubscription?.cancel();
    _receivedSubscription = _firestore
        .collection('chatmessages')
        .where('receiverid', isEqualTo: _currentUserId)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .listen((snapshot) {
      _receivedMessages = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      _debouncedBuildConversations();
    }, onError: (e) {
      debugPrint('ChatProvider: Error listening to received messages: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Debounce conversation rebuilds — both streams fire nearly simultaneously
  void _debouncedBuildConversations() {
    _rebuildDebounce?.cancel();
    _rebuildDebounce = Timer(const Duration(milliseconds: 150), () {
      _buildConversations();
    });
  }

  /// Build conversation threads from combined sent+received messages
  Future<void> _buildConversations() async {
    if (_currentUserId == null) return;

    final Map<String, _ConversationData> conversationMap = {};

    // Process sent messages
    for (var msg in _sentMessages) {
      final partnerId = msg['receiverid'] as String? ?? '';
      if (partnerId.isEmpty) continue;

      final timestamp = msg['timestamp'] as Timestamp?;
      final time = timestamp?.toDate() ?? DateTime.now();

      if (!conversationMap.containsKey(partnerId) ||
          time.isAfter(conversationMap[partnerId]!.lastMessageTime)) {
        conversationMap[partnerId] = _ConversationData(
          partnerId: partnerId,
          lastMessage: msg['message'] as String? ?? '',
          lastMessageTime: time,
          isLastMessageMine: true,
        );
      }
    }

    // Process received messages
    int totalUnread = 0;
    final Map<String, int> unreadCounts = {};

    for (var msg in _receivedMessages) {
      final partnerId = msg['senderid'] as String? ?? '';
      if (partnerId.isEmpty) continue;

      final timestamp = msg['timestamp'] as Timestamp?;
      final time = timestamp?.toDate() ?? DateTime.now();
      final isRead = msg['read'] as bool? ?? false;

      if (!isRead) {
        unreadCounts[partnerId] = (unreadCounts[partnerId] ?? 0) + 1;
        totalUnread++;
      }

      if (!conversationMap.containsKey(partnerId) ||
          time.isAfter(conversationMap[partnerId]!.lastMessageTime)) {
        conversationMap[partnerId] = _ConversationData(
          partnerId: partnerId,
          lastMessage: msg['message'] as String? ?? '',
          lastMessageTime: time,
          isLastMessageMine: false,
        );
      }
    }

    // Batch-fetch all user profiles that aren't cached yet
    final uncachedIds = conversationMap.keys
        .where((id) => !_userProfileCache.containsKey(id))
        .toList();

    if (uncachedIds.isNotEmpty) {
      // Firestore 'in' query supports max 30 items
      for (var i = 0; i < uncachedIds.length; i += 30) {
        final batch =
            uncachedIds.sublist(i, (i + 30).clamp(0, uncachedIds.length));
        try {
          final snapshots = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          for (var doc in snapshots.docs) {
            final data = doc.data();
            _userProfileCache[doc.id] = ChatUserProfile(
              id: doc.id,
              name: data['name'] as String? ?? 'Unknown',
              profilePicture: data['profilePicture'] as String? ??
                  data['photoUrl'] as String?,
            );
          }
        } catch (e) {
          debugPrint('ChatProvider: Error batch-fetching profiles: $e');
        }
      }
    }

    // Build threads using cached profiles
    final threads = <ChatThread>[];
    for (var entry in conversationMap.entries) {
      final data = entry.value;
      final profile = _userProfileCache[data.partnerId] ??
          ChatUserProfile(id: data.partnerId, name: 'Unknown');

      threads.add(ChatThread(
        partnerId: data.partnerId,
        partnerName: profile.name,
        partnerPhoto: profile.profilePicture,
        lastMessage: data.lastMessage,
        lastMessageTime: data.lastMessageTime,
        unreadCount: unreadCounts[data.partnerId] ?? 0,
        isLastMessageMine: data.isLastMessageMine,
      ));
    }

    // Sort by latest message first
    threads.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    _conversations = threads;
    _totalUnreadCount = totalUnread;
    _isLoading = false;
    notifyListeners();
  }

  /// Get cached user profile OR fetch from Firestore
  Future<ChatUserProfile> _getUserProfile(String userId) async {
    if (_userProfileCache.containsKey(userId)) {
      return _userProfileCache[userId]!;
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final profile = ChatUserProfile(
          id: userId,
          name: data['name'] as String? ?? 'Unknown',
          profilePicture: data['profilePicture'] as String? ??
              data['photoUrl'] as String?,
        );
        _userProfileCache[userId] = profile;
        return profile;
      }
    } catch (e) {
      debugPrint('ChatProvider: Error fetching user profile: $e');
    }

    final fallback = ChatUserProfile(id: userId, name: 'Unknown');
    _userProfileCache[userId] = fallback;
    return fallback;
  }

  /// Fetch user profile (public, for display on screens)
  Future<ChatUserProfile> getUserProfile(String userId) async {
    return _getUserProfile(userId);
  }

  /// Send a message
  Future<void> sendMessage({
    required String receiverId,
    required String message,
  }) async {
    if (_currentUserId == null || message.trim().isEmpty) return;

    try {
      await _firestore.collection('chatmessages').add({
        'senderid': _currentUserId,
        'receiverid': receiverId,
        'message': message.trim(),
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ChatProvider: Error sending message: $e');
      rethrow;
    }
  }

  /// Mark all messages from a partner as read
  Future<void> markConversationAsRead(String partnerId) async {
    if (_currentUserId == null) return;

    try {
      final query = await _firestore
          .collection('chatmessages')
          .where('receiverid', isEqualTo: _currentUserId)
          .where('senderid', isEqualTo: partnerId)
          .where('read', isEqualTo: false)
          .get();

      if (query.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in query.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('ChatProvider: Error marking as read: $e');
    }
  }

  /// Get real-time message stream for a specific conversation
  /// Uses TWO efficient queries instead of fetching the whole collection
  Stream<List<Map<String, dynamic>>> getChatStream(String partnerId) {
    if (_currentUserId == null) return const Stream.empty();

    // Query messages I sent to this partner
    final sentStream = _firestore
        .collection('chatmessages')
        .where('senderid', isEqualTo: _currentUserId)
        .where('receiverid', isEqualTo: partnerId)
        .orderBy('timestamp', descending: false)
        .snapshots();

    // Query messages this partner sent to me
    final receivedStream = _firestore
        .collection('chatmessages')
        .where('senderid', isEqualTo: partnerId)
        .where('receiverid', isEqualTo: _currentUserId)
        .orderBy('timestamp', descending: false)
        .snapshots();

    // Combine both streams
    return _combineStreams(sentStream, receivedStream);
  }

  /// Combine two Firestore snapshots into a single sorted message list
  Stream<List<Map<String, dynamic>>> _combineStreams(
    Stream<QuerySnapshot<Map<String, dynamic>>> stream1,
    Stream<QuerySnapshot<Map<String, dynamic>>> stream2,
  ) {
    List<Map<String, dynamic>>? latest1;
    List<Map<String, dynamic>>? latest2;

    final controller =
        StreamController<List<Map<String, dynamic>>>.broadcast();

    void emit() {
      final all = <Map<String, dynamic>>[
        ...?latest1,
        ...?latest2,
      ];
      // Sort by timestamp
      all.sort((a, b) {
        final ta = a['timestamp'] as Timestamp?;
        final tb = b['timestamp'] as Timestamp?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return -1;
        if (tb == null) return 1;
        return ta.compareTo(tb);
      });
      controller.add(all);
    }

    final sub1 = stream1.listen((snapshot) {
      latest1 = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      emit();
    }, onError: (e) => controller.addError(e));

    final sub2 = stream2.listen((snapshot) {
      latest2 = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      emit();
    }, onError: (e) => controller.addError(e));

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
  }

  /// Check if a conversation already exists with this user
  Future<bool> hasExistingConversation(String partnerId) async {
    if (_currentUserId == null) return false;

    try {
      final sent = await _firestore
          .collection('chatmessages')
          .where('senderid', isEqualTo: _currentUserId)
          .where('receiverid', isEqualTo: partnerId)
          .limit(1)
          .get();

      if (sent.docs.isNotEmpty) return true;

      final received = await _firestore
          .collection('chatmessages')
          .where('senderid', isEqualTo: partnerId)
          .where('receiverid', isEqualTo: _currentUserId)
          .limit(1)
          .get();

      return received.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

/// Internal helper class
class _ConversationData {
  final String partnerId;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isLastMessageMine;

  _ConversationData({
    required this.partnerId,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isLastMessageMine,
  });
}
