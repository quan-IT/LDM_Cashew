import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_material_app/struct/services/storage_service.dart';

class FakeStorageBackend implements StorageBackend {
  String? uploadedPath;
  Uint8List? uploadedBytes;
  String? uploadedContentType;
  String? signedPath;
  int? signedUrlExpiry;
  String? deletedPath;
  bool objectDeleted = true;
  Object? uploadError;
  Object? signedUrlError;
  Object? deleteError;

  @override
  Future<void> upload({
    required String fullPath,
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploadedPath = fullPath;
    uploadedBytes = bytes;
    uploadedContentType = contentType;
    if (uploadError != null) throw uploadError!;
  }

  @override
  Future<String> createSignedUrl({
    required String fullPath,
    required int expiresInSeconds,
  }) async {
    signedPath = fullPath;
    signedUrlExpiry = expiresInSeconds;
    if (signedUrlError != null) throw signedUrlError!;
    return 'https://supabase.example/storage/object/sign/$fullPath';
  }

  @override
  Future<bool> delete(String fullPath) async {
    deletedPath = fullPath;
    if (deleteError != null) throw deleteError!;
    return objectDeleted;
  }
}

void main() {
  group('Supabase Storage upload', () {
    test(
      'uploads bytes using the authenticated UID and canonical object path',
      () async {
        final backend = FakeStorageBackend();
        final result =
            await StorageService(
              backend: backend,
              currentUid: () => 'firebase-user-A',
            ).uploadDocumentBytes(
              documentId: 'doc-001',
              bytes: [1, 2, 3],
              fileName: 'my notes.PDF',
            );

        expect(
          result.fullPath,
          'documents/firebase-user-A/doc-001/original.pdf',
        );
        expect(result.fileName, 'my notes.PDF');
        expect(result.fileSize, 3);
        expect(result.contentType, 'application/pdf');
        expect(backend.uploadedPath, result.fullPath);
        expect(backend.uploadedBytes, [1, 2, 3]);
        expect(backend.uploadedContentType, 'application/pdf');
      },
    );

    test('uploads local files using their actual file name and contents', () async {
      final file = File(
        '${Directory.systemTemp.path}\\storage_service_test_${DateTime.now().microsecondsSinceEpoch}.docx',
      );
      await file.writeAsBytes([1, 2, 3, 4]);
      addTearDown(() async {
        if (await file.exists()) await file.delete();
      });

      final backend = FakeStorageBackend();
      final result = await StorageService(
        backend: backend,
        currentUid: () => 'firebase-user-A',
      ).uploadDocument(documentId: 'doc-002', file: file);

      expect(
        result.fullPath,
        'documents/firebase-user-A/doc-002/original.docx',
      );
      expect(result.fileName, file.uri.pathSegments.last);
      expect(result.fileSize, 4);
      expect(backend.uploadedBytes, [1, 2, 3, 4]);
    });

    test(
      'rejects unauthenticated and invalid uploads before storage access',
      () async {
        final backend = FakeStorageBackend();
        final unauthenticated = StorageService(
          backend: backend,
          currentUid: () => null,
        );

        await expectLater(
          unauthenticated.uploadDocumentBytes(
            documentId: 'doc-001',
            bytes: [1],
            fileName: 'notes.pdf',
          ),
          throwsA(isA<StateError>()),
        );
        expect(backend.uploadedPath, isNull);

        final authenticated = StorageService(
          backend: backend,
          currentUid: () => 'firebase-user-A',
        );
        await expectLater(
          authenticated.uploadDocumentBytes(
            documentId: 'doc-001',
            bytes: [1],
            fileName: 'notes.exe',
          ),
          throwsArgumentError,
        );
        await expectLater(
          authenticated.uploadDocumentBytes(
            documentId: 'doc-001',
            bytes: [],
            fileName: 'notes.pdf',
          ),
          throwsArgumentError,
        );
        expect(backend.uploadedPath, isNull);
      },
    );

    test('surfaces Supabase upload failures', () async {
      final backend = FakeStorageBackend()
        ..uploadError = StateError('upload failed');
      final service = StorageService(
        backend: backend,
        currentUid: () => 'firebase-user-A',
      );

      await expectLater(
        service.uploadDocumentBytes(
          documentId: 'doc-001',
          bytes: [1],
          fileName: 'notes.pdf',
        ),
        throwsStateError,
      );
    });
  });

  group('Supabase Storage download and deletion', () {
    test(
      'creates an expiring signed URL for an owned or shared document',
      () async {
        final backend = FakeStorageBackend();
        final service = StorageService(
          backend: backend,
          currentUid: () => 'shared-user',
        );
        const path = 'documents/document-owner/doc-001/original.pdf';

        final url = await service.createDocumentDownloadUrl(
          documentId: 'doc-001',
          ownerUid: 'document-owner',
          storagePath: path,
        );

        expect(url, startsWith('https://supabase.example/'));
        expect(backend.signedPath, path);
        expect(backend.signedUrlExpiry, 300);
      },
    );

    test('rejects unauthenticated or unsafe download paths', () async {
      final backend = FakeStorageBackend();
      final unauthenticated = StorageService(
        backend: backend,
        currentUid: () => null,
      );
      await expectLater(
        unauthenticated.createDocumentDownloadUrl(
          documentId: 'doc-001',
          ownerUid: 'firebase-user-A',
          storagePath: 'documents/firebase-user-A/doc-001/original.pdf',
        ),
        throwsA(isA<StateError>()),
      );

      final authenticated = StorageService(
        backend: backend,
        currentUid: () => 'shared-user',
      );
      await expectLater(
        authenticated.createDocumentDownloadUrl(
          documentId: 'doc-001',
          ownerUid: 'firebase-user-A',
          storagePath: 'documents/firebase-user-B/doc-001/original.pdf',
        ),
        throwsArgumentError,
      );
      expect(backend.signedPath, isNull);
    });

    test('deletes only a path owned by the authenticated user', () async {
      final backend = FakeStorageBackend();
      final service = StorageService(
        backend: backend,
        currentUid: () => 'firebase-user-A',
      );
      const path = 'documents/firebase-user-A/doc-001/original.pdf';

      expect(
        await service.deleteDocument(documentId: 'doc-001', storagePath: path),
        isTrue,
      );
      expect(backend.deletedPath, path);

      backend.objectDeleted = false;
      expect(
        await service.deleteDocument(documentId: 'doc-001', storagePath: path),
        isFalse,
      );
      await expectLater(
        service.deleteDocument(
          documentId: 'doc-001',
          storagePath: 'documents/firebase-user-B/doc-001/original.pdf',
        ),
        throwsArgumentError,
      );
    });

    test('surfaces Supabase signed URL and delete failures', () async {
      final backend = FakeStorageBackend()
        ..signedUrlError = StateError('signed URL failed')
        ..deleteError = StateError('delete failed');
      final service = StorageService(
        backend: backend,
        currentUid: () => 'firebase-user-A',
      );
      const path = 'documents/firebase-user-A/doc-001/original.pdf';

      await expectLater(
        service.createDocumentDownloadUrl(
          documentId: 'doc-001',
          ownerUid: 'firebase-user-A',
          storagePath: path,
        ),
        throwsStateError,
      );
      await expectLater(
        service.deleteDocument(documentId: 'doc-001', storagePath: path),
        throwsStateError,
      );
    });
  });

  group('Storage path and size validation', () {
    test('creates distinct canonical paths for different owners', () {
      final ownerA = StorageService.buildStoragePath(
        userUid: 'firebase-user-A',
        documentId: 'doc-001',
        extension: 'pdf',
      );
      final ownerB = StorageService.buildStoragePath(
        userUid: 'firebase-user-B',
        documentId: 'doc-001',
        extension: 'pdf',
      );

      expect(ownerA, 'documents/firebase-user-A/doc-001/original.pdf');
      expect(ownerB, 'documents/firebase-user-B/doc-001/original.pdf');
      expect(ownerA, isNot(ownerB));
      expect(
        () => StorageService.buildStoragePath(
          userUid: 'firebase-user-A',
          documentId: '../other',
          extension: 'pdf',
        ),
        throwsArgumentError,
      );
      expect(
        () => StorageService.buildStoragePath(
          userUid: 'firebase-user-A',
          documentId: 'doc-001',
          extension: 'exe',
        ),
        throwsArgumentError,
      );
    });

    test('enforces nonempty files and the 50 MiB size limit', () {
      expect(() => StorageService.validateFileSize(0), throwsArgumentError);
      expect(
        () => StorageService.validateFileSize(maxDocumentFileSizeBytes + 1),
        throwsArgumentError,
      );
      expect(
        StorageService.validateFileSize(maxDocumentFileSizeBytes),
        maxDocumentFileSizeBytes,
      );
    });
  });
}
