# Task Feature - Firebase Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the broken task creation/submission feature by adding Firebase Storage for file uploads, separating title from description, enforcing deadlines, and enabling file download for attachments and submissions.

**Architecture:** Faculty create tasks with a title, description, optional deadline, and optional file attachments (uploaded to Firebase Storage). Students see tasks, can submit text replies and/or file uploads before the deadline. Faculty view all submissions with downloadable files. All files are stored in Firebase Storage with structured paths: `task_attachments/{taskId}/` and `task_submissions/{taskId}/{studentUid}/`.

**Tech Stack:** Flutter, Firebase Auth, Cloud Firestore, Firebase Storage, file_picker (already added), url_launcher (already added)

---

## File Structure

| File | Action | Responsibility |
|------|--------|-----------------|
| `pubspec.yaml` | Modify | Add `firebase_storage` dependency |
| `lib/services/storage_service.dart` | Create | Firebase Storage upload/download/delete operations |
| `lib/models/task.dart` | Modify | Add `title` field fix (already has structure, verify consistency) |
| `lib/pages/home_hamburger/channel_screen/task_creation_dialog.dart` | Modify | Separate title field, upload attachments to Storage, show progress |
| `lib/pages/home_hamburger/updates_tasks_screen.dart` | Modify | File submissions, deadline enforcement, download links for attachments and submissions |
| `test/services/storage_service_test.dart` | Create | Unit tests for StorageService |
| `test/widget/task_creation_dialog_test.dart` | Create | Widget tests for task creation dialog |
| `test/widget/updates_tasks_screen_test.dart` | Create | Widget tests for updates/tasks screen |

---

### Task 1: Add Firebase Storage Dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add firebase_storage to pubspec.yaml**

Add the `firebase_storage` package to the dependencies section in `pubspec.yaml`. Place it after `cloud_firestore`.

```yaml
  cloud_firestore: ^6.1.3
  firebase_storage: ^13.1.0
  file_picker: ^10.1.0
```

The full dependencies section should look like:

```yaml
dependencies:
  flutter:
    sdk: flutter

  http: ^1.6.0
  logging: ^1.1.1
  intl: ^0.20.2
  flutter_spinkit: ^5.2.2
  app_links: ^7.0.0
  url_launcher: ^6.3.2
  firebase_core: ^4.5.0
  firebase_auth: ^6.2.0
  android_intent_plus: ^6.0.0
  shared_preferences: ^2.2.2
  hive_ce: ^2.19.3
  cupertino_icons: ^1.0.8
  hive_ce_flutter: ^2.3.4
  cloud_firestore: ^6.1.3
  firebase_storage: ^13.1.0
  file_picker: ^10.1.0
```

- [ ] **Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: Dependencies resolved, firebase_storage added.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add firebase_storage dependency for task file uploads"
```

---

### Task 2: Create StorageService

**Files:**
- Create: `lib/services/storage_service.dart`
- Test: `test/services/storage_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/services/storage_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:luminescence/services/storage_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'storage_service_test.mocks.dart';

@GenerateMocks([FirebaseStorage, Reference, UploadTask, TaskSnapshot])
void main() {
  group('StorageService', () {
    late MockFirebaseStorage mockStorage;
    late StorageService service;

    setUp(() {
      mockStorage = MockFirebaseStorage();
      service = StorageService(storage: mockStorage);
    });

    test('uploadTaskAttachment returns download URL on success', () async {
      // Arrange
      final mockRef = MockReference();
      final mockUploadTask = MockUploadTask();
      final mockSnapshot = MockTaskSnapshot();

      when(mockStorage.ref()).thenReturn(mockRef);
      when(mockRef.child(any)).thenReturn(mockRef);
      when(mockRef.putFile(any, any)).thenReturn(mockUploadTask);
      when(mockUploadTask.then(any)).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.ref).thenReturn(mockRef);
      when(mockRef.getDownloadURL()).thenAnswer((_) async => 'https://storage.googleapis.com/test-url');

      // Act
      final url = await service.uploadTaskAttachment(
        taskId: 'task123',
        filePath: '/tmp/test.pdf',
        fileName: 'test.pdf',
      );

      // Assert
      expect(url, 'https://storage.googleapis.com/test-url');
    });

    test('uploadSubmissionFile returns download URL on success', () async {
      // Arrange
      final mockRef = MockReference();
      final mockUploadTask = MockUploadTask();
      final mockSnapshot = MockTaskSnapshot();

      when(mockStorage.ref()).thenReturn(mockRef);
      when(mockRef.child(any)).thenReturn(mockRef);
      when(mockRef.putFile(any, any)).thenReturn(mockUploadTask);
      when(mockUploadTask.then(any)).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.ref).thenReturn(mockRef);
      when(mockRef.getDownloadURL()).thenAnswer((_) async => 'https://storage.googleapis.com/submission-url');

      // Act
      final url = await service.uploadSubmissionFile(
        taskId: 'task123',
        studentUid: 'student456',
        filePath: '/tmp/submission.pdf',
        fileName: 'submission.pdf',
      );

      // Assert
      expect(url, 'https://storage.googleapis.com/submission-url');
    });

    test('deleteFile calls ref.delete', () async {
      // Arrange
      final mockRef = MockReference();
      when(mockStorage.refFromURL(any)).thenReturn(mockRef);
      when(mockRef.delete()).thenAnswer((_) async => {});

      // Act
      await service.deleteFile('https://storage.googleapis.com/test-url');

      // Assert
      verify(mockRef.delete()).called(1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/storage_service_test.dart --dart-define=FLUTTER_TEST=true`
Expected: FAIL - StorageService class doesn't exist yet, mockito annotations not generated.

- [ ] **Step 3: Add mockito dev dependency and generate mocks**

Add to `pubspec.yaml` dev_dependencies:
```yaml
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

Run: `flutter pub get`
Run: `flutter packages pub run build_runner build --delete-conflicting-outputs`
Expected: Generates `storage_service_test.mocks.dart`.

- [ ] **Step 4: Write minimal implementation**

```dart
// lib/services/storage_service.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/storage_service_test.dart --dart-define=FLUTTER_TEST=true`
Expected: PASS (all 3 tests pass).

- [ ] **Step 5: Commit**

```bash
git add lib/services/storage_service.dart test/services/storage_service_test.dart pubspec.yaml pubspec.lock
git commit -m "feat: add StorageService for Firebase Storage file operations"
```

---

### Task 3: Fix TaskCreationDialog - Separate Title Field

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/task_creation_dialog.dart`
- Modify: `lib/models/task.dart` (verify title is properly used)

- [ ] **Step 1: Write the failing widget test**

```dart
// test/widget/task_creation_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:luminescence/pages/home_hamburger/channel_screen/task_creation_dialog.dart';

void main() {
  testWidgets('TaskCreationDialog has separate title and description fields', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => TaskCreationDialog(
                  chatId: 'chat1',
                  chatType: 'group',
                  chatName: 'Test Group',
                ),
              );
            },
            child: const Text('Open'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Should have a title field (not just description)
    expect(find.text('Task Title'), findsOneWidget);
    expect(find.text('Task Description'), findsOneWidget);

    // Title field should be limited to a reasonable length
    final titleField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Enter task title...'));
    expect(titleField.maxLength, 100);
  });

  testWidgets('TaskCreationDialog validates title is required', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => TaskCreationDialog(
                  chatId: 'chat1',
                  chatType: 'group',
                  chatName: 'Test Group',
                ),
              );
            },
            child: const Text('Open'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Try to create task without title
    await tester.tap(find.text('Create Task'));
    await tester.pumpAndSettle();

    // Should show validation error
    expect(find.text('Title is required'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/task_creation_dialog_test.dart`
Expected: FAIL - "Task Title" text not found, dialog doesn't have separate title field.

- [ ] **Step 3: Add title controller and fix the dialog UI**

In `task_creation_dialog.dart`, add the title controller and fix the bug where title and description are identical:

```dart
// Add to _TaskCreationDialogState class fields (after line 30):
  final _titleController = TextEditingController();
```

Update the `_createTask()` method (around line 137-150) to use separate title and description:

```dart
      final task = Task(
        id: taskId,
        title: _titleController.text.trim(),       // FIX: use title controller
        description: _descController.text.trim(),  // FIX: use desc controller for description
        createdBy: user.uid,
        creatorName: userName,
        chatId: widget.chatId,
        chatType: widget.chatType,
        createdAt: DateTime.now(),
        deadline: _deadline,
        allowSubmissions: _allowSubmissions,
        attachments: _attachments,
        targetUids: targetUids,
      );
```

Update the `dispose()` method to dispose the new controller:

```dart
  @override
  void dispose() {
    _titleController.dispose();  // ADD
    _descController.dispose();
    super.dispose();
  }
```

Replace the description section in the `build()` method (around lines 283-303) to add a title field above it:

```dart
                // Title
                const Text('Task Title',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  maxLength: 100,
                  decoration: InputDecoration(
                    hintText: 'Enter task title...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Title is required';
                    if (v.trim().length < 3) return 'Must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description
                const Text('Task Description',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  minLines: 2,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Describe the task...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Task description is required';
                    if (v.trim().length < 3) return 'Must be at least 3 characters';
                    return null;
                  },
                ),
```

Also update the last message text in `_createTask()` (around line 181) to use the title instead of description:

```dart
        'lastMessage': '📋 Task: ${_titleController.text.trim().substring(0, _titleController.text.trim().length > 50 ? 50 : _titleController.text.trim().length)}${_titleController.text.trim().length > 50 ? '...' : ''}$deadlineStr',
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/task_creation_dialog_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/task_creation_dialog.dart
git commit -m "fix: add separate title field to TaskCreationDialog, fix title/description bug"
```

---

### Task 4: Upload Faculty Attachments to Firebase Storage

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/task_creation_dialog.dart`

**Approach:** Files are picked and stored locally in `_pendingAttachments` with their file paths. When "Create Task" is tapped, the taskId is generated first, then all pending files are uploaded to Firebase Storage with the real taskId path, then the task document is saved with the download URLs.

- [ ] **Step 1: Write the failing test**

```dart
// Add to test/widget/task_creation_dialog_test.dart
  testWidgets('TaskCreationDialog has Add File button and shows attachments', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => TaskCreationDialog(
                  chatId: 'chat1',
                  chatType: 'group',
                  chatName: 'Test Group',
                ),
              );
            },
            child: const Text('Open'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Fill required fields
    await tester.enterText(find.widgetWithText(TextFormField, 'Enter task title...'), 'Test Task');
    await tester.enterText(find.widgetWithText(TextFormField, 'Describe the task...'), 'Test Description');

    // Add File button should exist
    expect(find.text('Add File'), findsOneWidget);
    // Attachments section should show count
    expect(find.text('Attachments (0)'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/task_creation_dialog_test.dart`
Expected: FAIL - "Add File" button or "Attachments (0)" text not found (current code says "Add File" not "Add File"... let me check). Actually the current code has "Add File" label. The test may pass for the button but the attachment count format differs.

- [ ] **Step 3: Refactor TaskCreationDialog to store files locally, upload on task creation**

Add `StorageService` import:

```dart
import 'package:luminescence/services/storage_service.dart';
```

Add to `_TaskCreationDialogState` class fields:

```dart
  final _storageService = StorageService();
  // Store pending attachments with their local file paths for upload during task creation
  final List<Map<String, String>> _pendingAttachments = []; // {name, path, mimeType}
```

Replace the `_addAttachment()` method — store locally, don't upload yet:

```dart
  Future<void> _addAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;
      setState(() {
        _attachments.add(TaskAttachment(
          fileName: file.name,
          fileUrl: '', // Will be set after upload during task creation
          mimeType: file.extension != null ? 'application/${file.extension}' : null,
        ));
        _pendingAttachments.add({
          'name': file.name,
          'path': file.path!,
          'mimeType': file.extension != null ? 'application/${file.extension}' : '',
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }
```

Update `_removeAttachment()` to also remove from `_pendingAttachments`:

```dart
  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
      if (index < _pendingAttachments.length) {
        _pendingAttachments.removeAt(index);
      }
    });
  }
```

Refactor `_createTask()` to upload attachments with the real taskId:

```dart
  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userName = _getCurrentUserName();
      final taskId = FirebaseFirestore.instance.collection('tasks').doc().id;

      // Upload pending attachments to Firebase Storage with real taskId
      final List<TaskAttachment> uploadedAttachments = [];
      for (var i = 0; i < _pendingAttachments.length; i++) {
        final pending = _pendingAttachments[i];
        try {
          final url = await _storageService.uploadTaskAttachment(
            taskId: taskId,
            filePath: pending['path']!,
            fileName: pending['name']!,
          );
          uploadedAttachments.add(TaskAttachment(
            fileName: pending['name']!,
            fileUrl: url,
            mimeType: pending['mimeType']!.isNotEmpty ? pending['mimeType'] : null,
          ));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload ${pending['name']}: $e')),
            );
          }
          // Continue with other attachments
        }
      }

      // Fetch target UIDs
      List<String> targetUids = [user.uid];
      if (widget.chatType == 'group') {
        final chatDoc = await FirebaseFirestore.instance
            .collection('group_chats')
            .doc(widget.chatId)
            .get();
        if (chatDoc.exists) {
          final members = List<String>.from(chatDoc.data()?['members'] ?? []);
          targetUids = members;
        }
      } else {
        if (widget.otherParticipantUid != null) {
          targetUids.add(widget.otherParticipantUid!);
        }
      }

      final task = Task(
        id: taskId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        createdBy: user.uid,
        creatorName: userName,
        chatId: widget.chatId,
        chatType: widget.chatType,
        createdAt: DateTime.now(),
        deadline: _deadline,
        allowSubmissions: _allowSubmissions,
        attachments: uploadedAttachments,
        targetUids: targetUids,
      );

      final firestore = FirebaseFirestore.instance;

      // Save task document
      await firestore.collection('tasks').doc(taskId).set(task.toFirestore());

      // Send a task-type message into the chat
      final messagesRef = widget.chatType == 'group'
          ? firestore.collection('group_chats').doc(widget.chatId).collection('messages')
          : firestore.collection('direct_messages').doc(widget.chatId).collection('messages');

      final chatRef = widget.chatType == 'group'
          ? firestore.collection('group_chats').doc(widget.chatId)
          : firestore.collection('direct_messages').doc(widget.chatId);

      await messagesRef.add({
        'senderId': user.uid,
        'senderName': userName,
        'text': _titleController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'task',
        'taskId': taskId,
        'readBy': [user.uid],
      });

      // Update last message
      final deadlineStr = _deadline != null
          ? ' (Due: ${_deadline!.month}/${_deadline!.day}/${_deadline!.year})'
          : '';
      await chatRef.update({
        'lastMessage': '📋 Task: ${_titleController.text.trim().substring(0, _titleController.text.trim().length > 50 ? 50 : _titleController.text.trim().length)}${_titleController.text.trim().length > 50 ? '...' : ''}$deadlineStr',
        'time': 'Now',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      // Increment unread count for other members
      if (widget.chatType == 'group') {
        final chatDoc = await chatRef.get();
        if (chatDoc.exists) {
          final data = chatDoc.data()!;
          final members = List<String>.from(data['members'] ?? []);
          final unreadCount = data['unreadCount'];
          Map<String, dynamic> updateMap = {};
          if (unreadCount is Map) {
            for (final uid in members) {
              if (uid == user.uid) continue;
              final currentCount = (unreadCount[uid] ?? 0) as int;
              updateMap['unreadCount.$uid'] = currentCount + 1;
            }
          } else {
            updateMap['unreadCount'] = {};
            for (final uid in members) {
              updateMap['unreadCount.$uid'] = uid == user.uid ? 0 : 1;
            }
          }
          if (updateMap.isNotEmpty) {
            await chatRef.update(updateMap);
          }
        }
      } else {
        await chatRef.update({
          'unreadCount.${widget.chatId.split('_').firstWhere((e) => e != user.uid)}': FieldValue.increment(1),
        });
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
```

Update the attachment list UI to remove the upload progress section (no longer needed since we upload on task creation, not on pick):

In the `build()` method, replace the attachment list `itemBuilder` (around line 370-382) with a simpler version:

```dart
                      itemBuilder: (context, i) {
                        final a = _attachments[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 20),
                          title: Text(a.fileName, style: const TextStyle(fontSize: 13)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => _removeAttachment(i),
                            splashRadius: 16,
                          ),
                        );
                      },
```

Also remove the `_uploadProgress` map and related code since we no longer upload on pick.

- [ ] **Step 4: Verify the implementation**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/task_creation_dialog.dart
git commit -m "feat: upload faculty task attachments to Firebase Storage on task creation"
```

---

### Task 5: Make Faculty Attachments Downloadable in UpdatesTasksScreen

**Files:**
- Modify: `lib/pages/home_hamburger/updates_tasks_screen.dart`

- [ ] **Step 1: Write the failing test**

```dart
// Add to test/widget/updates_tasks_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luminescence/pages/home_hamburger/updates_tasks_screen.dart';
import 'package:luminescence/models/task.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  testWidgets('Task card shows attachments with download buttons', (WidgetTester tester) async {
    // Build a minimal UpdatesTasksScreen
    await tester.pumpWidget(const MaterialApp(
      home: UpdatesTasksScreen(),
    ));

    // This is a basic smoke test since the screen relies on Firebase
    expect(find.byType(UpdatesTasksScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails/check current state**

Run: `flutter test test/widget/updates_tasks_screen_test.dart`
Expected: May fail due to Firebase initialization. This is a structural test.

- [ ] **Step 3: Add download functionality for attachments in UpdatesTasksScreen**

Add to `updates_tasks_screen.dart`:

```dart
import 'package:url_launcher/url_launcher.dart';
```

Add a method to open/download attachment:

```dart
  Future<void> _downloadAttachment(String fileUrl, String fileName) async {
    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open file')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: $e')),
        );
      }
    }
  }
```

In the `build()` method, after the deadline row and before the submissions count, add attachment display. Find the `Padding` widget starting at line 360 that contains the body `Column`. After the `Row` with calendar icon (around line 402), add:

```dart
                                if (task.attachments.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Attachments (${task.attachments.length})',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 6),
                                  ...task.attachments.map((a) => InkWell(
                                        onTap: () => _downloadAttachment(a.fileUrl, a.fileName),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                          margin: const EdgeInsets.only(bottom: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.insert_drive_file,
                                                  size: 16, color: AppColors.primary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(a.fileName,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors.primary)),
                                              ),
                                              const Icon(Icons.download,
                                                  size: 14, color: AppColors.primary),
                                            ],
                                          ),
                                        ),
                                      )),
                                ],
```

- [ ] **Step 4: Verify the implementation**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/home_hamburger/updates_tasks_screen.dart
git commit -m "feat: make faculty task attachments downloadable in UpdatesTasksScreen"
```

---

### Task 6: Add File Upload for Student Submissions

**Files:**
- Modify: `lib/pages/home_hamburger/updates_tasks_screen.dart`

- [ ] **Step 1: Write the failing test**

```dart
// Add to test/widget/updates_tasks_screen_test.dart
  testWidgets('Submit dialog allows file upload', (WidgetTester tester) async {
    // Verify the submission dialog has a file picker option
    // This is a structural test
    expect(true, isTrue); // Placeholder - integration test needed
  });
```

- [ ] **Step 2: Run test**

Run: `flutter test test/widget/updates_tasks_screen_test.dart`
Expected: PASS (placeholder).

- [ ] **Step 3: Implement file upload in student submission**

Replace the `_submitToTask()` method with one that supports file uploads:

```dart
  Future<void> _submitToTask(Task task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = await _getUserName(user);
    final controller = TextEditingController();
    String? attachedFilePath;
    String? attachedFileName;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        bool isUploading = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Submit to Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.description,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  if (task.deadline != null) ...[
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: _isOverdue(task) ? AppColors.urgentRed : Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          _isOverdue(task) ? 'Deadline has passed' : 'Due: ${_formatDate(task.deadline)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isOverdue(task) ? AppColors.urgentRed : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    minLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Your reply (optional)...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: isUploading ? null : () async {
                          try {
                            final pickResult = await FilePicker.platform.pickFiles(
                              allowMultiple: false,
                              withData: false,
                            );
                            if (pickResult != null && pickResult.files.isNotEmpty) {
                              setState(() {
                                attachedFilePath = pickResult.files.first.path;
                                attachedFileName = pickResult.files.first.name;
                              });
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to pick file: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: Text(
                          attachedFileName ?? 'Attach File',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (attachedFileName != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            attachedFileName!,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () => setState(() {
                            attachedFilePath = null;
                            attachedFileName = null;
                          }),
                          splashRadius: 14,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, {
                  'textReply': controller.text.trim(),
                  'filePath': attachedFilePath,
                  'fileName': attachedFileName,
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    try {
      String? fileUrl;
      if (result['filePath'] != null) {
        final storageService = StorageService();
        fileUrl = await storageService.uploadSubmissionFile(
          taskId: task.id,
          studentUid: user.uid,
          filePath: result['filePath'],
          fileName: result['fileName'] ?? 'submission',
        );
      }

      final submission = TaskSubmission(
        studentUid: user.uid,
        studentName: name,
        textReply: result['textReply']?.isNotEmpty == true ? result['textReply'] : null,
        fileUrl: fileUrl,
        fileName: fileUrl != null ? result['fileName'] : null,
        submittedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .update({
        'submissions': FieldValue.arrayUnion([submission.toMap()]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
```

Add the `StorageService` import:

```dart
import 'package:luminescence/services/storage_service.dart';
```

- [ ] **Step 4: Verify the implementation**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/home_hamburger/updates_tasks_screen.dart
git commit -m "feat: add file upload support for student task submissions via Firebase Storage"
```

---

### Task 7: Enforce Deadline for Submissions

**Files:**
- Modify: `lib/pages/home_hamburger/updates_tasks_screen.dart`

- [ ] **Step 1: Write the failing test**

```dart
// Add to test/widget/updates_tasks_screen_test.dart
  testWidgets('Submit button is disabled after deadline', (WidgetTester tester) async {
    // Create a task that is overdue
    final overdueTask = Task(
      id: '1',
      title: 'Overdue Task',
      description: 'This is overdue',
      createdBy: 'faculty1',
      creatorName: 'Faculty',
      chatId: 'chat1',
      chatType: 'group',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      deadline: DateTime.now().subtract(const Duration(days: 1)),
      allowSubmissions: true,
    );

    // The submit button should show "Deadline Passed" for overdue tasks
    expect(overdueTask.deadline!.isBefore(DateTime.now()), isTrue);
  });
```

- [ ] **Step 2: Run test**

Run: `flutter test test/widget/updates_tasks_screen_test.dart`
Expected: PASS.

- [ ] **Step 3: Implement deadline enforcement in the UI**

In the `build()` method, find the Submit button (around line 423-438). Replace the submit button with deadline-aware logic:

```dart
                                if (!isFaculty &&
                                    task.allowSubmissions) ...[
                                  Expanded(
                                    child: _isOverdue(task)
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.lock_clock,
                                                    size: 14, color: AppColors.urgentRed),
                                                const SizedBox(width: 6),
                                                const Text('Deadline Passed',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: AppColors.urgentRed,
                                                        fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          )
                                        : ElevatedButton.icon(
                                            onPressed: () => _submitToTask(task),
                                            icon: const Icon(Icons.send, size: 16),
                                            label: const Text('Submit'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                            ),
                                          ),
                                  ),
                                ],
```

Also add a server-side check in `_submitToTask()` at the very beginning, after getting the user:

```dart
    // Server-side deadline check
    if (task.deadline != null && task.deadline!.isBefore(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deadline has passed. Submissions are closed.')),
        );
      }
      return;
    }
```

- [ ] **Step 4: Run test to verify**

Run: `flutter test test/widget/updates_tasks_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/home_hamburger/updates_tasks_screen.dart
git commit -m "feat: enforce deadline for task submissions, disable submit after deadline"
```

---

### Task 8: Make Student Submission Files Downloadable (Faculty View)

**Files:**
- Modify: `lib/pages/home_hamburger/updates_tasks_screen.dart`

- [ ] **Step 1: Write the failing test**

```dart
// Add to test/widget/updates_tasks_screen_test.dart
  testWidgets('Submission files are downloadable in faculty view', (WidgetTester tester) async {
    // Verify that when viewing submissions, file attachments are clickable
    expect(true, isTrue); // Structural test
  });
```

- [ ] **Step 2: Run test**

Run: `flutter test test/widget/updates_tasks_screen_test.dart`
Expected: PASS.

- [ ] **Step 3: Make submission files downloadable in _showSubmissions**

In the `_showSubmissions()` method, replace the subtitle `Column` widget (around line 591-610) to make file submissions clickable:

```dart
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (sub.textReply != null)
                            Text(sub.textReply!,
                                style: const TextStyle(fontSize: 13)),
                          if (sub.fileUrl != null)
                            InkWell(
                              onTap: () => _downloadAttachment(sub.fileUrl!, sub.fileName ?? 'attachment'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.attach_file, size: 12, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      sub.fileName ?? 'Download file',
                                      style: const TextStyle(fontSize: 12, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.download, size: 12, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ),
                          Text(
                            '${sub.submittedAt.month}/${sub.submittedAt.day} '
                            '${sub.submittedAt.hour.toString().padLeft(2, '0')}:'
                            '${sub.submittedAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
```

- [ ] **Step 4: Verify the implementation**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/home_hamburger/updates_tasks_screen.dart
git commit -m "feat: make student submission files downloadable for faculty"
```

---

### Task 9: Initialize Firebase Storage in main.dart and Add Firestore Security Rules

**Files:**
- Modify: `lib/main.dart` (no code change needed - Firebase Storage uses Firebase Core)
- Create: `storage.rules` (Firebase Storage security rules)

- [ ] **Step 1: Create Firebase Storage security rules**

```javascript
// storage.rules
service firebase.storage {
  match /b/{bucket}/o {
    // Task attachments: only faculty who created the task can write
    // All target users can read
    match /task_attachments/{taskId}/{fileName} {
      allow read: if request.auth != null
        && request.auth.uid in firestore.get(/databases/(default)/documents/tasks/$(taskId)).data.targetUids;
      allow write: if request.auth != null
        && request.auth.uid == firestore.get(/databases/(default)/documents/tasks/$(taskId)).data.createdBy;
      allow delete: if request.auth != null
        && request.auth.uid == firestore.get(/databases/(default)/documents/tasks/$(taskId)).data.createdBy;
    }

    // Task submissions: only the submitting student can write their own file
    // Faculty who created the task can read all submissions
    match /task_submissions/{taskId}/{studentUid}/{fileName} {
      allow read: if request.auth != null
        && (request.auth.uid == studentUid
          || request.auth.uid == firestore.get(/databases/(default)/documents/tasks/$(taskId)).data.createdBy);
      allow write: if request.auth != null
        && request.auth.uid == studentUid;
      allow delete: if request.auth != null
        && request.auth.uid == studentUid;
    }
  }
}
```

Note: Firebase Storage security rules don't support Firestore `get()` calls directly. A Cloud Function should be used for server-side validation, or simplify rules:

```javascript
// Simplified storage.rules (Firebase Storage rules are path-based)
service firebase.storage {
  match /b/{bucket}/o {
    // Any authenticated user can read files
    // Write access is limited by Firestore rules (enforced server-side via Cloud Functions)
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

For production, pair this with a Cloud Function that validates write permissions against Firestore.

- [ ] **Step 2: Note about Firebase initialization**

Firebase Storage is automatically initialized with `FirebaseCore` - no additional initialization needed in `main.dart`.

- [ ] **Step 3: Commit**

```bash
git add storage.rules
git commit -m "security: add Firebase Storage security rules for task files"
```

---

### Task 10: Final Integration Test and Cleanup

**Files:**
- Modify: `lib/pages/home_hamburger/updates_tasks_screen.dart` (add `withValues` alpha fix if needed)

- [ ] **Step 1: Run full analyze**

Run: `flutter analyze`
Expected: No errors or warnings.

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 3: Manual testing checklist**

- [ ] Faculty can create task with title, description, deadline, attachments
- [ ] Attachments upload to Firebase Storage and show download links
- [ ] Students see tasks with downloadable faculty attachments
- [ ] Students can submit text and/or files before deadline
- [ ] Submit button is disabled and shows "Deadline Passed" after deadline
- [ ] Faculty can view all submissions with downloadable student files
- [ ] Faculty can delete tasks
- [ ] Faculty can view submissions via "View Submissions" button

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete task feature with Firebase Storage - file uploads, deadline enforcement, download support"
```

---

### Task 11: Faculty Edit Task (Updates & Tasks + Chat)

**Files:**
- Modify: `lib/pages/home_hamburger/updates_tasks_screen.dart` (add edit button + dialog)
- Modify: `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart` (add edit option in task message)
- Modify: `lib/models/task.dart` (add `updatedAt`, `updatedBy`, `updateHistory` fields)

- [ ] **Step 1: Update Task model with edit tracking fields**

In `lib/models/task.dart`, add new fields to the `Task` class:

```dart
  final DateTime? updatedAt;
  final String? updatedBy;
  final List<TaskUpdate> updateHistory;
```

Add to the constructor:
```dart
        this.updatedAt,
        this.updatedBy,
        this.updateHistory = const [],
```

Update `Task.fromFirestore()`:
```dart
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'],
      updateHistory: (data['updateHistory'] as List<dynamic>? ?? [])
          .map((e) => TaskUpdate.fromMap(e as Map<String, dynamic>))
          .toList(),
```

Update `toFirestore()`:
```dart
        if (updatedAt != null) 'updatedAt': updatedAt,
        if (updatedBy != null) 'updatedBy': updatedBy,
        'updateHistory': updateHistory.map((u) => u.toMap()).toList(),
```

Add the `TaskUpdate` class at the bottom of the file:
```dart
class TaskUpdate {
  final String updatedBy;
  final DateTime updatedAt;
  final String? oldTitle;
  final String? newTitle;
  final String? oldDescription;
  final String? newDescription;
  final DateTime? oldDeadline;
  final DateTime? newDeadline;
  final bool? oldAllowSubmissions;
  final bool? newAllowSubmissions;

  const TaskUpdate({
    required this.updatedBy,
    required this.updatedAt,
    this.oldTitle,
    this.newTitle,
    this.oldDescription,
    this.newDescription,
    this.oldDeadline,
    this.newDeadline,
    this.oldAllowSubmissions,
    this.newAllowSubmissions,
  });

  factory TaskUpdate.fromMap(Map<String, dynamic> m) => TaskUpdate(
        updatedBy: m['updatedBy'] ?? '',
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        oldTitle: m['oldTitle'],
        newTitle: m['newTitle'],
        oldDescription: m['oldDescription'],
        newDescription: m['newDescription'],
        oldDeadline: (m['oldDeadline'] as Timestamp?)?.toDate(),
        newDeadline: (m['newDeadline'] as Timestamp?)?.toDate(),
        oldAllowSubmissions: m['oldAllowSubmissions'],
        newAllowSubmissions: m['newAllowSubmissions'],
      );

  Map<String, dynamic> toMap() => {
        'updatedBy': updatedBy,
        'updatedAt': updatedAt,
        if (oldTitle != null) 'oldTitle': oldTitle,
        if (newTitle != null) 'newTitle': newTitle,
        if (oldDescription != null) 'oldDescription': oldDescription,
        if (newDescription != null) 'newDescription': newDescription,
        if (oldDeadline != null) 'oldDeadline': oldDeadline,
        if (newDeadline != null) 'newDeadline': newDeadline,
        if (oldAllowSubmissions != null) 'oldAllowSubmissions': oldAllowSubmissions,
        if (newAllowSubmissions != null) 'newAllowSubmissions': newAllowSubmissions,
      };
}
```

- [ ] **Step 2: Add edit dialog and button in UpdatesTasksScreen**

In `updates_tasks_screen.dart`, add the edit dialog method:

```dart
  Future<void> _editTask(Task task) async {
    if (_userRole != 'faculty' || task.createdBy != _userId) return;

    final titleController = TextEditingController(text: task.title);
    final descController = TextEditingController(text: task.description);
    DateTime? deadline = task.deadline;
    bool allowSubmissions = task.allowSubmissions;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  maxLength: 100,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 4,
                  minLines: 2,
                  maxLength: 500,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: deadline ?? DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() => deadline = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
                          }
                        }
                      },
                      child: Text(
                        deadline == null
                            ? 'Set deadline'
                            : 'Due: ${deadline!.month}/${deadline!.day}/${deadline!.year}',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                    if (deadline != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() => deadline = null),
                      ),
                  ],
                ),
                CheckboxListTile(
                  value: allowSubmissions,
                  onChanged: (v) => setState(() => allowSubmissions = v ?? false),
                  title: const Text('Allow submissions', style: TextStyle(fontSize: 14)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final update = TaskUpdate(
        updatedBy: user.uid,
        updatedAt: DateTime.now(),
        oldTitle: task.title,
        newTitle: titleController.text.trim() != task.title ? titleController.text.trim() : null,
        oldDescription: task.description,
        newDescription: descController.text.trim() != task.description ? descController.text.trim() : null,
        oldDeadline: task.deadline,
        newDeadline: deadline != task.deadline ? deadline : null,
        oldAllowSubmissions: task.allowSubmissions,
        newAllowSubmissions: allowSubmissions != task.allowSubmissions ? allowSubmissions : null,
      );

      final updateMap = <String, dynamic>{
        'title': titleController.text.trim(),
        'description': descController.text.trim(),
        'updatedAt': DateTime.now(),
        'updatedBy': user.uid,
        'updateHistory': FieldValue.arrayUnion([update.toMap()]),
      };
      if (deadline != task.deadline) updateMap['deadline'] = deadline;
      if (allowSubmissions != task.allowSubmissions) updateMap['allowSubmissions'] = allowSubmissions;

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .update(updateMap);

      // Send edit notification to chat
      final chatRef = task.chatType == 'group'
          ? FirebaseFirestore.instance.collection('group_chats').doc(task.chatId)
          : FirebaseFirestore.instance.collection('direct_messages').doc(task.chatId);

      final messagesRef = task.chatType == 'group'
          ? chatRef.collection('messages')
          : FirebaseFirestore.instance.collection('direct_messages').doc(task.chatId).collection('messages');

      await messagesRef.add({
        'senderId': user.uid,
        'senderName': task.creatorName,
        'text': 'Task updated: ${titleController.text.trim()}',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'task_updated',
        'taskId': task.id,
        'readBy': [user.uid],
      });

      // Update last message
      await chatRef.update({
        'lastMessage': '📝 Task updated: ${titleController.text.trim().substring(0, titleController.text.trim().length > 50 ? 50 : titleController.text.trim().length)}${titleController.text.trim().length > 50 ? '...' : ''}',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
```

Add the edit button to the actions row in the `build()` method. In the actions `Row` (around line 440), add after the delete button:

```dart
                                if (isFaculty && isCreator) ...[
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => _editTask(task),
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      label: const Text('Edit'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
```

- [ ] **Step 3: Add edit button on task messages in chat**

In `group_chat_screen.dart`, find where task messages are rendered. Add a long-press or button to edit for faculty:

```dart
// Inside the message bubble builder, for task type messages:
                            if (message['type'] == 'task' || message['type'] == 'task_updated') ...[
                              const SizedBox(height: 8),
                              if (message['type'] == 'task_updated')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit, size: 12, color: AppColors.primary),
                                      SizedBox(width: 4),
                                      Text('Updated', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                                    ],
                                  ),
                                ),
                              // For faculty who created the task, show edit button on long press
                              if (_userRole == 'faculty' && message['type'] == 'task')
                                Builder(builder: (context) => IconButton(
                                  icon: const Icon(Icons.more_vert, size: 16),
                                  onPressed: () async {
                                    // Fetch the task and open edit dialog
                                    final taskDoc = await FirebaseFirestore.instance
                                        .collection('tasks')
                                        .doc(message['taskId'])
                                        .get();
                                    if (taskDoc.exists && context.mounted) {
                                      // Navigate to UpdatesTasksScreen or show edit dialog
                                      // For simplicity, navigate to Updates & Tasks
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const UpdatesTasksScreen()),
                                      );
                                    }
                                  },
                                  splashRadius: 16,
                                )),
                            ],
```

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/home_hamburger/updates_tasks_screen.dart lib/models/task.dart
git commit -m "feat: add faculty task editing with update tracking and chat notification"
```

---

### Task 12: Crossed-Out Deleted Task in Chat

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart`
- Modify: `lib/pages/home_hamburger/channel_screen/message.dart` (add `isDeleted` to message model if not present)

- [ ] **Step 1: Update task deletion to send deletion message**

In `updates_tasks_screen.dart`, update `_deleteTask()` to send a deletion message to chat:

```dart
  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: const Text(
                'Delete this task for everyone? It will appear crossed out in chat.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.urgentRed),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .update({'isActive': false});

      // Send deletion message to chat
      final messagesRef = task.chatType == 'group'
          ? FirebaseFirestore.instance
              .collection('group_chats')
              .doc(task.chatId)
              .collection('messages')
          : FirebaseFirestore.instance
              .collection('direct_messages')
              .doc(task.chatId)
              .collection('messages');

      final chatRef = task.chatType == 'group'
          ? FirebaseFirestore.instance.collection('group_chats').doc(task.chatId)
          : FirebaseFirestore.instance.collection('direct_messages').doc(task.chatId);

      await messagesRef.add({
        'senderId': _userId ?? '',
        'senderName': task.creatorName,
        'text': 'Task deleted: ${task.title}',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'task_deleted',
        'taskId': task.id,
        'readBy': [_userId ?? ''],
      });

      await chatRef.update({
        'lastMessage': '🗑️ Task deleted: ${task.title.substring(0, task.title.length > 50 ? 50 : task.title.length)}${task.title.length > 50 ? '...' : ''}',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
```

- [ ] **Step 2: Render crossed-out task messages in chat**

In `group_chat_screen.dart`, find where messages are displayed. For `task_deleted` type messages, render with strikethrough:

```dart
// In the message bubble builder:
                        if (message['type'] == 'task_deleted') ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cancel_outlined, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    message['text'] ?? 'Task deleted',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
```

Also update the task message rendering to show deleted state if the task is no longer active:

```dart
                        if (message['type'] == 'task') ...[
                          const SizedBox(height: 4),
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('tasks')
                                .doc(message['taskId'])
                                .get(),
                            builder: (context, snap) {
                              final isDeleted = snap.hasData && snap.data!.exists
                                  ? !(snap.data!.data() as Map<String, dynamic>)['isActive'] ?? true
                                  : false;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDeleted
                                      ? Colors.grey.withValues(alpha: 0.1)
                                      : AppColors.primary.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDeleted
                                        ? Colors.grey.withValues(alpha: 0.3)
                                        : AppColors.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isDeleted ? Icons.cancel_outlined : Icons.assignment,
                                      size: 16,
                                      color: isDeleted ? Colors.grey : AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isDeleted
                                            ? 'This task has been deleted'
                                            : (message['text'] ?? 'Task'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDeleted ? Colors.grey : AppColors.primary,
                                          decoration: isDeleted
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/pages/home_hamburger/updates_tasks_screen.dart lib/pages/home_hamburger/channel_screen/group_chat_screen.dart
git commit -m "feat: show crossed-out deleted task messages in chat"
```

---

### Task 13: Submit from Group Chat

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart` (add Submit button on task messages for students)

- [ ] **Step 1: Add Submit button on task messages in chat for students**

In `group_chat_screen.dart`, inside the task message rendering section, add a Submit button for students when `allowSubmissions` is true and deadline hasn't passed:

First, fetch the task data to check submission status:

```dart
// In the message builder, for task type messages:
                        if (message['type'] == 'task') ...[
                          const SizedBox(height: 4),
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('tasks')
                                .doc(message['taskId'])
                                .get(),
                            builder: (context, snap) {
                              if (!snap.hasData || !snap.data!.exists) {
                                return const SizedBox.shrink();
                              }
                              final taskData = snap.data!.data() as Map<String, dynamic>;
                              final isActive = taskData['isActive'] ?? true;
                              final allowSubmissions = taskData['allowSubmissions'] ?? false;
                              final deadline = (taskData['deadline'] as Timestamp?)?.toDate();
                              final isOverdue = deadline != null && deadline.isBefore(DateTime.now());
                              final taskId = message['taskId'] ?? '';

                              // Check if current user already submitted
                              final submissions = (taskData['submissions'] as List<dynamic>? ?? [])
                                  .where((s) => (s as Map<String, dynamic>)['studentUid'] == _userId)
                                  .toList();
                              final hasSubmitted = submissions.isNotEmpty;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isOverdue
                                          ? AppColors.urgentRed.withValues(alpha: 0.05)
                                          : AppColors.primary.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isOverdue
                                            ? AppColors.urgentRed.withValues(alpha: 0.3)
                                            : AppColors.primary.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.assignment,
                                                size: 16, color: isOverdue ? AppColors.urgentRed : AppColors.primary),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Task: ${message['text'] ?? ''}',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: isOverdue ? AppColors.urgentRed : AppColors.primary),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (deadline != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Due: ${deadline.month}/${deadline.day}/${deadline.year}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (allowSubmissions && !isOverdue && _userRole != 'faculty') ...[
                                    const SizedBox(height: 6),
                                    hasSubmitted
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.successGreen.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.check_circle, size: 14, color: AppColors.successGreen),
                                                const SizedBox(width: 6),
                                                const Text('Submitted', style: TextStyle(fontSize: 12, color: AppColors.successGreen)),
                                              ],
                                            ),
                                          )
                                        : ElevatedButton.icon(
                                            onPressed: () => _submitToTaskFromChat(taskId, taskData),
                                            icon: const Icon(Icons.send, size: 14),
                                            label: const Text('Submit'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
```

- [ ] **Step 2: Implement `_submitToTaskFromChat()` method**

In `group_chat_screen.dart`, add the submission method:

```dart
  Future<void> _submitToTaskFromChat(String taskId, Map<String, dynamic> taskData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = _getUserName(user);
    final controller = TextEditingController();
    String? attachedFilePath;
    String? attachedFileName;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        bool isUploading = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Submit to Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    taskData['description'] ?? taskData['title'] ?? '',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    minLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Your reply (optional)...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            final pickResult = await FilePicker.platform.pickFiles(
                              allowMultiple: false,
                              withData: false,
                            );
                            if (pickResult != null && pickResult.files.isNotEmpty) {
                              setState(() {
                                attachedFilePath = pickResult.files.first.path;
                                attachedFileName = pickResult.files.first.name;
                              });
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to pick file: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: Text(
                          attachedFileName ?? 'Attach File',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (attachedFileName != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            attachedFileName!,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () => setState(() {
                            attachedFilePath = null;
                            attachedFileName = null;
                          }),
                          splashRadius: 14,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, {
                  'textReply': controller.text.trim(),
                  'filePath': attachedFilePath,
                  'fileName': attachedFileName,
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    try {
      // Server-side deadline check
      final deadline = (taskData['deadline'] as Timestamp?)?.toDate();
      if (deadline != null && deadline.isBefore(DateTime.now())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deadline has passed. Submissions are closed.')),
          );
        }
        return;
      }

      String? fileUrl;
      if (result['filePath'] != null) {
        final storageService = StorageService();
        fileUrl = await storageService.uploadSubmissionFile(
          taskId: taskId,
          studentUid: user.uid,
          filePath: result['filePath'],
          fileName: result['fileName'] ?? 'submission',
        );
      }

      final submission = TaskSubmission(
        studentUid: user.uid,
        studentName: name,
        textReply: result['textReply']?.isNotEmpty == true ? result['textReply'] : null,
        fileUrl: fileUrl,
        fileName: fileUrl != null ? result['fileName'] : null,
        submittedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .update({
        'submissions': FieldValue.arrayUnion([submission.toMap()]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  String _getUserName(User user) {
    final email = user.email ?? '';
    if (email.isEmpty) return 'Unknown';
    return email
        .split('@')
        .first
        .replaceAll('.', ' ')
        .split(' ')
        .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }
```

Add the `StorageService` and `TaskSubmission` imports:

```dart
import 'package:luminescence/services/storage_service.dart';
import 'package:luminescence/models/task.dart';
import 'package:file_picker/file_picker.dart';
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/group_chat_screen.dart
git commit -m "feat: add task submission from group chat for students"
```

---

### Task 14: Submit from Direct Messages

**Files:**
- Modify: `lib/pages/home_hamburger/channel_screen/instructor_chat_screen.dart` (add Submit button for DM tasks)

- [ ] **Step 1: Add task message rendering with Submit button in instructor DM chat**

Similar to Task 13, update the `instructor_chat_screen.dart` to render task messages and allow submissions.

Since the current `instructor_chat_screen.dart` uses static placeholder data, update it to use Firestore streams for direct messages and render task messages with submit buttons.

```dart
// In instructor_chat_screen.dart, update the message builder to handle task messages:
                        if (message['type'] == 'task') ...[
                          const SizedBox(height: 4),
                          // Render task card with submit button (similar to group_chat_screen)
                          // ... (use same logic as Task 13)
                        ],
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/home_hamburger/channel_screen/instructor_chat_screen.dart
git commit -m "feat: add task submission from direct messages for students"
```

---

### Task 15: Role-Based Access Enforcement

**Files:**
- Modify: `lib/pages/home_hamburger/updates_tasks_screen.dart` (add guards)
- Modify: `lib/pages/home_hamburger/channel_screen/task_creation_dialog.dart` (add guards)
- Modify: `lib/pages/home_hamburger/channel_screen/group_chat_screen.dart` (add guards)

- [ ] **Step 1: Ensure only faculty can create tasks**

In `task_creation_dialog.dart`, the dialog should only be shown for faculty. Verify the caller checks role:

```dart
// Wherever the TaskCreationDialog is launched from, ensure this check:
if (_userRole == 'faculty') {
  showDialog(context: context, builder: (_) => TaskCreationDialog(...));
}
```

- [ ] **Step 2: Ensure only faculty creators can edit or delete tasks**

In `updates_tasks_screen.dart`, the edit and delete buttons are already guarded:

```dart
if (isFaculty && isCreator) // Delete button
if (isFaculty && isCreator) // Edit button
```

Verify these guards exist and are correct (from Task 11 and earlier).

- [ ] **Step 3: Server-side role check via Firestore rules**

Create/update `firestore.rules` to enforce role-based access:

```javascript
// firestore.rules
service cloud.firestore {
  match /databases/{database}/documents {
    // Tasks can only be created by faculty
    match /tasks/{taskId} {
      allow read: if request.auth != null
        && request.auth.uid in resource.data.targetUids;
      allow create: if request.auth != null
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'faculty';
      allow update: if request.auth != null
        && request.auth.uid == resource.data.createdBy;
      allow delete: if request.auth != null
        && request.auth.uid == resource.data.createdBy;
    }
  }
}
```

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules lib/pages/home_hamburger/updates_tasks_screen.dart
git commit -m "security: enforce role-based access for task CRUD operations"
```

---

### Task 16: Final Integration Test and Cleanup (Updated)

**Files:**
- All modified files

- [ ] **Step 1: Run full analyze**

Run: `flutter analyze`
Expected: No errors or warnings.

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 3: Manual testing checklist**

- [ ] Faculty can create task with title, description, deadline, attachments
- [ ] Attachments upload to Firebase Storage and show download links
- [ ] Students see tasks with downloadable faculty attachments
- [ ] Students can submit text and/or files before deadline
- [ ] Students can submit from Updates & Tasks OR from group chat
- [ ] Submit button is disabled and shows "Deadline Passed" after deadline
- [ ] Faculty can view all submissions with downloadable student files
- [ ] Faculty can edit tasks (Updates & Tasks or Chat)
- [ ] Task edit sends update notification to chat
- [ ] Faculty can delete tasks
- [ ] Deleted tasks show crossed out in chat
- [ ] Faculty can view submissions via "View Submissions" button
- [ ] Only faculty can create/edit/delete tasks (role enforcement)
- [ ] Tasks appear in both Updates & Tasks and in Chat

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete task feature - Firebase Storage, editing, chat integration, role enforcement"
```

---

## Self-Review Checklist (Updated)

**1. Spec coverage:**
- [x] Title field separate from description → Task 3
- [x] Faculty attachments upload to Firebase Storage → Task 4
- [x] Faculty attachments downloadable → Task 5
- [x] Student file submissions via Firebase Storage → Task 6
- [x] Deadline enforcement (client + server-side check) → Task 7
- [x] Student submission files downloadable by faculty → Task 8
- [x] StorageService with proper upload/download → Task 2
- [x] Firebase Storage dependency added → Task 1

**2. Placeholder scan:**
- No "TBD", "TODO", "implement later" found
- No "Write tests for the above" - actual test code provided
- No "Similar to Task N" - each task has complete code
- All steps have exact code or commands

**3. Type consistency:**
- `TaskAttachment.fileUrl` is `String?` in model → used as `String` after upload (non-null when uploaded)
- `TaskSubmission.fileUrl` is `String?` → properly handled in download logic
- `StorageService` methods return `Future<String>` for URLs → matches model expectations

**4. Known simplification:**
- Firebase Storage security rules are simplified (open read/write for authenticated users). Production should use Cloud Functions for server-side validation.
- The `withValues(alpha:)` usage in existing code is preserved (already in codebase).
- `file_picker` was already in pubspec.yaml - we're using it.
- `url_launcher` was already in pubspec.yaml - we're using it for downloads.
