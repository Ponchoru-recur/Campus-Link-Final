import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/message.dart';

/// Checks whether a message is within the editable/deletable time window.
bool isWithinEditWindow(DateTime timestamp, {int minutes = 60}) {
  return DateTime.now().difference(timestamp).inMinutes <= minutes;
}

/// Soft-deletes a message by updating the Firestore document in-place.
/// Replaces the text with a placeholder and marks it as deleted.
/// The message remains in the stream so all clients see the placeholder.
Future<void> softDeleteMessage({
  required String chatId,
  required String messageId,
  String collection = 'group_chats',
}) async {
  await FirebaseFirestore.instance
      .collection(collection)
      .doc(chatId)
      .collection('messages')
      .doc(messageId)
      .update({
        'isDeleted': true,
        'text': '[This message was deleted]',
      });
}

/// Edits a message with 60-minute window enforcement and history tracking.
/// Pushes the current text into [editHistory] and writes the new text.
/// Returns `true` when the edit was performed, `false` if the window expired.
Future<bool> editMessageWithHistory({
  required String chatId,
  required Message msg,
  required String newText,
  String collection = 'group_chats',
}) async {
  if (!isWithinEditWindow(msg.timestamp)) return false;
  final msgRef = FirebaseFirestore.instance
      .collection(collection)
      .doc(chatId)
      .collection('messages')
      .doc(msg.id);
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(msgRef);
    final currentText = snap.data()?['text'] ?? '';
    final entry = {
      'text': currentText,
      'editedAt': DateTime.now().toIso8601String(),
    };
    tx.update(msgRef, {
      'text': newText,
      'editHistory': FieldValue.arrayUnion([entry]),
    });
  });
  return true;
}
