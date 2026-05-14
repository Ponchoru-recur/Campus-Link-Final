import 'package:hive_ce/hive.dart';

class ChatDatabase {
  final _userBox = Hive.box("CURRENT_USER");
  final _groupsBox = Hive.box("GROUP_CHATS");
  final _messagesBox = Hive.box("MESSAGES");

  void saveCurrentUser(String email) {
    _userBox.put("email", email);
  }

  String? getCurrentUserEmail() => _userBox.get("email");

  // Log out user
  void logout() => _userBox.clear();

  // Create new groupchats
  void createGroup(String groupId, String groupName, List<String> members) {
    _groupsBox.put(groupId, {
      "name": groupName,
      "members": members,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Get all groups
  List<Map> getAllGroups() {
    List<Map> groups = [];
    for (var key in _groupsBox.keys) {
      var group = Map<String, dynamic>.from(_groupsBox.get(key));
      group["id"] = key; // include the key
      groups.add(group);
    }
    return groups;
  }

  // -- MESSAGES --

  List<Map<String, dynamic>> getMessages(String groupId) {
    var stored = _messagesBox.get(groupId);
    if (stored == null) return [];
    return List<Map<String, dynamic>>.from(
      stored.map((m) => Map<String, dynamic>.from(m)),
    );
  }

  void sendMessage(String groupId, String text) {
    List<Map<String, dynamic>> messages = getMessages(groupId);

    messages.add({
      "senderEmail": getCurrentUserEmail(),
      "message": text,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    });

    _messagesBox.put(groupId, messages);
  }
}
