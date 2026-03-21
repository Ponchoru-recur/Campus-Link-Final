import 'package:hive_ce/hive.dart';

/// ============================================
/// SIMPLE HIVE CHAT STORAGE HELPER
/// ============================================
///
/// This helper manages 3 boxes:
/// 1. CURRENT_USER - stores logged-in user info
/// 2. GROUP_CHATS  - stores group chat data
/// 3. MESSAGES     - stores all messages
///
/// HOW TO USE:
/// 1. Initialize in main.dart (you already did this!)
/// 2. Create instance: final storage = ChatStorageHelper();
/// 3. Call methods like storage.sendMessage(), storage.createGroup(), etc.

class ChatStorageHelper {
  // Access the Hive boxes
  final Box _currentUser = Hive.box("CURRENT_USER");
  final Box _groupChats = Hive.box("GROUP_CHATS");
  final Box _messages = Hive.box("MESSAGES");

  // ==========================================
  // CURRENT USER METHODS
  // ==========================================

  /// Save the current logged-in user
  void setCurrentUser({
    required String email,
    required String name,
    String? profilePic,
  }) {
    _currentUser.put("email", email);
    _currentUser.put("name", name);
    _currentUser.put("profilePic", profilePic ?? "");
  }

  /// Get current user's email
  String? getCurrentUserEmail() {
    return _currentUser.get("email");
  }

  /// Get current user's name
  String? getCurrentUserName() {
    return _currentUser.get("name");
  }

  /// Clear current user (logout)
  void logout() {
    _currentUser.clear();
  }

  // ==========================================
  // GROUP CHAT METHODS
  // ==========================================

  /// Create a new group chat
  void createGroup({
    required String groupId,
    required String groupName,
    required List<String> members,
  }) {
    _groupChats.put(groupId, {
      "id": groupId,
      "name": groupName,
      "members": members,
      "createdAt": DateTime.now().toIso8601String(),
      "createdBy": getCurrentUserEmail(),
    });
  }

  /// Get all group chats
  List<Map<String, dynamic>> getAllGroups() {
    List<Map<String, dynamic>> groups = [];
    for (var key in _groupChats.keys) {
      final group = _groupChats.get(key);
      if (group != null) {
        groups.add(Map<String, dynamic>.from(group));
      }
    }
    return groups;
  }

  /// Get a specific group by ID
  Map<String, dynamic>? getGroup(String groupId) {
    final group = _groupChats.get(groupId);
    return group != null ? Map<String, dynamic>.from(group) : null;
  }

  /// Add a member to a group
  void addMemberToGroup(String groupId, String memberEmail) {
    final group = _groupChats.get(groupId);
    if (group != null) {
      List<String> members = List<String>.from(group["members"] ?? []);
      if (!members.contains(memberEmail)) {
        members.add(memberEmail);
        group["members"] = members;
        _groupChats.put(groupId, group);
      }
    }
  }

  /// Delete a group
  void deleteGroup(String groupId) {
    _groupChats.delete(groupId);
    // Also delete all messages in this group
    _deleteMessagesForGroup(groupId);
  }

  // ==========================================
  // MESSAGE METHODS
  // ==========================================

  /// Send a message to a group
  void sendMessage({required String groupId, required String content}) {
    // Create unique message ID using timestamp
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    _messages.put(messageId, {
      "id": messageId,
      "groupId": groupId,
      "senderEmail": getCurrentUserEmail(),
      "senderName": getCurrentUserName(),
      "content": content,
      "timestamp": DateTime.now().toIso8601String(),
    });
  }

  /// Get all messages for a specific group (sorted by time)
  List<Map<String, dynamic>> getMessagesForGroup(String groupId) {
    List<Map<String, dynamic>> groupMessages = [];

    for (var key in _messages.keys) {
      final message = _messages.get(key);
      if (message != null && message["groupId"] == groupId) {
        groupMessages.add(Map<String, dynamic>.from(message));
      }
    }

    // Sort by timestamp (oldest first)
    groupMessages.sort((a, b) => a["timestamp"].compareTo(b["timestamp"]));

    return groupMessages;
  }

  /// Delete all messages for a group (used when deleting group)
  void _deleteMessagesForGroup(String groupId) {
    List<String> keysToDelete = [];
    for (var key in _messages.keys) {
      final message = _messages.get(key);
      if (message != null && message["groupId"] == groupId) {
        keysToDelete.add(key.toString());
      }
    }
    for (var key in keysToDelete) {
      _messages.delete(key);
    }
  }

  /// Clear all data (for testing/reset)
  void clearAllData() {
    _currentUser.clear();
    _groupChats.clear();
    _messages.clear();
  }
}
