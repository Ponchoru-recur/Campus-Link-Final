import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

/// Service for Firebase Storage operations related to task attachments and submissions.
class StorageService {
  final FirebaseStorage storage;

  StorageService({FirebaseStorage? storage})
      : storage = storage ?? FirebaseStorage.instance;

  /// Uploads a faculty attachment for a task.
  /// Returns the download URL.
  Future<String> uploadTaskAttachment({
    required String taskId,
    required String filePath,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    final ref = storage.ref().child('task_attachments').child(taskId).child(fileName);
    final uploadTask = ref.putFile(
      File(filePath),
      SettableMetadata(contentType: _getContentType(fileName)),
    );

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });
    }

    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  /// Uploads a student submission file for a task.
  /// Returns the download URL.
  Future<String> uploadSubmissionFile({
    required String taskId,
    required String studentUid,
    required String filePath,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    final ref = storage
        .ref()
        .child('task_submissions')
        .child(taskId)
        .child(studentUid)
        .child(fileName);
    final uploadTask = ref.putFile(
      File(filePath),
      SettableMetadata(contentType: _getContentType(fileName)),
    );

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });
    }

    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  /// Deletes a file by its download URL.
  Future<void> deleteFile(String fileUrl) async {
    final ref = storage.refFromURL(fileUrl);
    await ref.delete();
  }

  /// Gets a download URL for a file path.
  Future<String> getDownloadUrl(String filePath) async {
    final ref = storage.ref().child(filePath);
    return ref.getDownloadURL();
  }

  String? _getContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}
