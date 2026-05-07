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
      final mockRef = MockReference();
      final mockUploadTask = MockUploadTask();
      final mockSnapshot = MockTaskSnapshot();

      when(mockStorage.ref()).thenReturn(mockRef);
      when(mockRef.child(any)).thenReturn(mockRef);
      when(mockRef.putFile(any, any)).thenReturn(mockUploadTask);
      when(mockUploadTask.snapshotEvents).thenAnswer((_) => const Stream.empty());
      when(mockUploadTask.then(any)).thenAnswer((inv) => Future.value(mockSnapshot));
      when(mockSnapshot.ref).thenReturn(mockRef);
      when(mockRef.getDownloadURL()).thenAnswer((_) async => 'https://storage.googleapis.com/test-url');

      final url = await service.uploadTaskAttachment(
        taskId: 'task123',
        filePath: '/tmp/test.pdf',
        fileName: 'test.pdf',
      );

      expect(url, 'https://storage.googleapis.com/test-url');
    });

    test('uploadSubmissionFile returns download URL on success', () async {
      final mockRef = MockReference();
      final mockUploadTask = MockUploadTask();
      final mockSnapshot = MockTaskSnapshot();

      when(mockStorage.ref()).thenReturn(mockRef);
      when(mockRef.child(any)).thenReturn(mockRef);
      when(mockRef.putFile(any, any)).thenReturn(mockUploadTask);
      when(mockUploadTask.snapshotEvents).thenAnswer((_) => const Stream.empty());
      when(mockUploadTask.then(any)).thenAnswer((inv) => Future.value(mockSnapshot));
      when(mockSnapshot.ref).thenReturn(mockRef);
      when(mockRef.getDownloadURL()).thenAnswer((_) async => 'https://storage.googleapis.com/submission-url');

      final url = await service.uploadSubmissionFile(
        taskId: 'task123',
        studentUid: 'student456',
        filePath: '/tmp/submission.pdf',
        fileName: 'submission.pdf',
      );

      expect(url, 'https://storage.googleapis.com/submission-url');
    });

    test('deleteFile calls ref.delete', () async {
      final mockRef = MockReference();
      when(mockStorage.refFromURL(any)).thenReturn(mockRef);
      when(mockRef.delete()).thenAnswer((_) async => {});

      await service.deleteFile('https://storage.googleapis.com/test-url');

      verify(mockRef.delete()).called(1);
    });
  });
}
