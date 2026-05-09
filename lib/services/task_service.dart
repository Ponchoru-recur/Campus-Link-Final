import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class TaskService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    return user;
  }

  Future<Map<String, String>> _uploadFile({
    required String storagePath,
    required String fileName,
    required PlatformFile file,
  }) async {
    final ref = _storage.ref().child(storagePath);

    UploadTask uploadTask;
    if (kIsWeb && file.bytes != null) {
      uploadTask = ref.putData(
        file.bytes!,
        SettableMetadata(contentType: _getContentType(fileName)),
      );
    } else if (file.path != null) {
      uploadTask = ref.putFile(
        File(file.path!),
        SettableMetadata(contentType: _getContentType(fileName)),
      );
    } else if (file.bytes != null) {
      uploadTask = ref.putData(
        file.bytes!,
        SettableMetadata(contentType: _getContentType(fileName)),
      );
    } else {
      throw Exception('No file content available');
    }

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return {
      'fileName': fileName,
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
    };
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

  Future<Map<String, dynamic>> createTask({
    required String title,
    required String description,
    required String deadline,
    required List<PlatformFile> attachments,
  }) async {
    final user = _user;

    final taskRef = _firestore.collection('tasks').doc();
    final taskId = taskRef.id;

    final attachmentMetadata = <Map<String, String>>[];

    for (final file in attachments) {
      final storagePath = 'tasks/$taskId/attachments/${file.name}';
      final metadata = await _uploadFile(
        storagePath: storagePath,
        fileName: file.name,
        file: file,
      );
      attachmentMetadata.add(metadata);
    }

    final taskData = {
      'title': title,
      'description': description,
      'deadline': deadline,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'attachments': attachmentMetadata,
    };

    await taskRef.set(taskData);

    return {...taskData, 'id': taskId};
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    final snapshot = await _firestore
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {...data, 'id': doc.id};
    }).toList();
  }

  Future<Map<String, dynamic>> getTask(String taskId) async {
    final doc = await _firestore.collection('tasks').doc(taskId).get();
    if (!doc.exists) throw Exception('Task not found');
    final data = doc.data()!;
    return {...data, 'id': doc.id};
  }

  Future<Map<String, dynamic>> submitTask({
    required String taskId,
    required String studentName,
    required List<PlatformFile> attachments,
  }) async {
    final user = _user;

    final submissionRef = _firestore
        .collection('tasks')
        .doc(taskId)
        .collection('submissions')
        .doc();
    final submissionId = submissionRef.id;

    final fileMetadata = <Map<String, String>>[];

    for (final file in attachments) {
      final storagePath = 'tasks/$taskId/submissions/$submissionId/${file.name}';
      final metadata = await _uploadFile(
        storagePath: storagePath,
        fileName: file.name,
        file: file,
      );
      fileMetadata.add(metadata);
    }

    final submissionData = {
      'studentId': user.uid,
      'studentName': studentName,
      'submittedAt': FieldValue.serverTimestamp(),
      'files': fileMetadata,
    };

    await submissionRef.set(submissionData);

    return {'id': submissionId, ...submissionData};
  }

  Future<List<Map<String, dynamic>>> getSubmissions(String taskId) async {
    final snapshot = await _firestore
        .collection('tasks')
        .doc(taskId)
        .collection('submissions')
        .orderBy('submittedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {...data, 'id': doc.id};
    }).toList();
  }
}
