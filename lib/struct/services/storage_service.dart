import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const int maxDocumentFileSizeBytes = 50 * 1024 * 1024;
const String learningDocumentsBucket = 'learning-documents';

const Map<String, String> _contentTypes = {
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'xls': 'application/vnd.ms-excel',
  'xlsx':
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'txt': 'text/plain',
  'zip': 'application/zip',
};

class StorageUploadResult {
  final String fullPath;
  final String fileName;
  final int fileSize;
  final String contentType;

  const StorageUploadResult({
    required this.fullPath,
    required this.fileName,
    required this.fileSize,
    required this.contentType,
  });
}

abstract interface class StorageBackend {
  Future<void> upload({
    required String fullPath,
    required Uint8List bytes,
    required String contentType,
  });

  Future<String> createSignedUrl({
    required String fullPath,
    required int expiresInSeconds,
  });

  Future<bool> delete(String fullPath);
}

class SupabaseStorageBackend implements StorageBackend {
  final SupabaseClient _client;
  final String _bucket;

  SupabaseStorageBackend(
    this._client, {
    this._bucket = learningDocumentsBucket,
  });

  @override
  Future<void> upload({
    required String fullPath,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _client.storage.from(_bucket).uploadBinary(
          fullPath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
  }

  @override
  Future<String> createSignedUrl({
    required String fullPath,
    required int expiresInSeconds,
  }) =>
      _client.storage.from(_bucket).createSignedUrl(
            fullPath,
            expiresInSeconds,
          );

  @override
  Future<bool> delete(String fullPath) async {
    final removed = await _client.storage.from(_bucket).remove([fullPath]);
    return removed.isNotEmpty;
  }
}

/// Stores private document objects in Supabase Storage.
class StorageService {
  final StorageBackend _backend;
  final String? Function() _currentUid;

  StorageService({
    StorageBackend? backend,
    String? Function()? currentUid,
    SupabaseClient? client,
  })  : _backend = backend ??
            SupabaseStorageBackend(client ?? Supabase.instance.client),
        _currentUid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  Future<StorageUploadResult> uploadDocument({
    required String documentId,
    required File file,
  }) async {
    final fileName = file.uri.pathSegments.isEmpty
        ? ''
        : file.uri.pathSegments.last;
    final bytes = await file.readAsBytes();
    return uploadDocumentBytes(
      documentId: documentId,
      bytes: bytes,
      fileName: fileName,
    );
  }

  Future<StorageUploadResult> uploadDocumentBytes({
    required String documentId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final uid = _requireCurrentUid();
    final contentType = contentTypeForFileName(fileName);
    validateFileSize(bytes.length);

    final path = buildStoragePath(
      userUid: uid,
      documentId: documentId,
      extension: extensionForFileName(fileName),
    );

    await _backend.upload(
      fullPath: path,
      bytes: Uint8List.fromList(bytes),
      contentType: contentType,
    );

    return StorageUploadResult(
      fullPath: path,
      fileName: fileName,
      fileSize: bytes.length,
      contentType: contentType,
    );
  }

  /// Creates a short-lived link; Storage policies still enforce owner/share access.
  Future<String> createDocumentDownloadUrl({
    required String documentId,
    required String ownerUid,
    required String storagePath,
    int expiresInSeconds = 300,
  }) async {
    _requireCurrentUid();
    validateOwnedStoragePath(
      userUid: ownerUid,
      documentId: documentId,
      storagePath: storagePath,
    );
    if (expiresInSeconds <= 0) {
      throw ArgumentError.value(
        expiresInSeconds,
        'expiresInSeconds',
        'Thời hạn liên kết phải lớn hơn 0.',
      );
    }
    return _backend.createSignedUrl(
      fullPath: storagePath,
      expiresInSeconds: expiresInSeconds,
    );
  }

  /// Deletes one object in the authenticated owner's document folder.
  /// Returns false when Supabase reports that no object was removed.
  Future<bool> deleteDocument({
    required String documentId,
    required String storagePath,
  }) async {
    final uid = _requireCurrentUid();
    validateOwnedStoragePath(
      userUid: uid,
      documentId: documentId,
      storagePath: storagePath,
    );
    return _backend.delete(storagePath);
  }

  String _requireCurrentUid() {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      throw StateError('Đăng nhập trước khi thao tác với Supabase Storage.');
    }
    if (!_isSafePathSegment(uid)) {
      throw ArgumentError.value(uid, 'userUid', 'UID không hợp lệ.');
    }
    return uid;
  }

  static String buildStoragePath({
    required String? userUid,
    required String documentId,
    required String extension,
  }) {
    if (userUid == null || userUid.isEmpty) {
      throw StateError('Đăng nhập trước khi tải tệp lên.');
    }
    if (!_isSafePathSegment(userUid)) {
      throw ArgumentError.value(userUid, 'userUid', 'UID không hợp lệ.');
    }
    if (!_isSafePathSegment(documentId)) {
      throw ArgumentError.value(
        documentId,
        'documentId',
        'ID tài liệu không hợp lệ.',
      );
    }
    final normalizedExtension = extension.toLowerCase();
    if (!_contentTypes.containsKey(normalizedExtension)) {
      throw ArgumentError.value(
        extension,
        'extension',
        'Loại tệp không hỗ trợ.',
      );
    }
    return 'documents/$userUid/$documentId/original.$normalizedExtension';
  }

  static void validateOwnedStoragePath({
    required String userUid,
    required String documentId,
    required String storagePath,
  }) {
    if (!_isSafePathSegment(userUid) || !_isSafePathSegment(documentId)) {
      throw ArgumentError('UID hoặc ID tài liệu không hợp lệ.');
    }
    final prefix = 'documents/$userUid/$documentId/';
    if (!storagePath.startsWith(prefix)) {
      throw ArgumentError.value(
        storagePath,
        'storagePath',
        'Đường dẫn không thuộc tài liệu đã xác định.',
      );
    }
    final fileName = storagePath.substring(prefix.length);
    if (fileName.contains('/') ||
        fileName.contains('\\') ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9 _().-]{0,119}\.[a-z0-9]+$')
            .hasMatch(fileName) ||
        !_contentTypes.containsKey(fileName.split('.').last.toLowerCase())) {
      throw ArgumentError.value(
        storagePath,
        'storagePath',
        'Đường dẫn tệp không hợp lệ.',
      );
    }
  }

  static int validateFileSize(int fileSize) {
    if (fileSize <= 0) {
      throw ArgumentError.value(fileSize, 'fileSize', 'Tệp không được rỗng.');
    }
    if (fileSize > maxDocumentFileSizeBytes) {
      throw ArgumentError.value(
        fileSize,
        'fileSize',
        'Dung lượng tệp vượt quá giới hạn 50 MiB.',
      );
    }
    return fileSize;
  }

  static String extensionForFileName(String fileName) {
    final separator = fileName.lastIndexOf('.');
    if (separator <= 0 || separator == fileName.length - 1) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'Tên tệp phải có phần mở rộng được hỗ trợ.',
      );
    }
    final extension = fileName.substring(separator + 1).toLowerCase();
    if (!_contentTypes.containsKey(extension)) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'Loại tệp không được hỗ trợ.',
      );
    }
    return extension;
  }

  static String contentTypeForFileName(String fileName) =>
      _contentTypes[extensionForFileName(fileName)]!;

  static bool _isSafePathSegment(String value) =>
      value.isNotEmpty &&
      value != '.' &&
      value != '..' &&
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);
}
