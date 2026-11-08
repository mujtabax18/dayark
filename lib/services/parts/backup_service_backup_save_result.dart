part of '../backupService.dart';

class BackupSaveResult {
  const BackupSaveResult._({
    required this.status,
    required this.message,
    this.location,
    this.assetCount = 0,
    this.fileSize = 0,
  });

  final BackupSaveStatus status;
  final String message;
  final String? location;
  final int assetCount;
  final int fileSize;

  bool get isSaved => status == BackupSaveStatus.saved;

  factory BackupSaveResult.saved(
    String? location, {
    int assetCount = 0,
    int fileSize = 0,
  }) {
    return BackupSaveResult._(
      status: BackupSaveStatus.saved,
      message: 'Backup saved successfully.',
      location: location,
      assetCount: assetCount,
      fileSize: fileSize,
    );
  }

  factory BackupSaveResult.cancelled() {
    return const BackupSaveResult._(
      status: BackupSaveStatus.cancelled,
      message: 'Save cancelled.',
    );
  }

  factory BackupSaveResult.permissionDenied([String? message]) {
    return BackupSaveResult._(
      status: BackupSaveStatus.permissionDenied,
      message: message ?? 'Write access was not granted. Select a writable folder and tap Save.',
    );
  }

  factory BackupSaveResult.failed(String message) {
    return BackupSaveResult._(
      status: BackupSaveStatus.failed,
      message: message,
    );
  }
}

class PortableBackupPackage {
  const PortableBackupPackage({
    required this.bytes,
    required this.fileName,
    required this.scope,
    required this.assetCount,
    required this.missingAssetCount,
  });

  final Uint8List bytes;
  final String fileName;
  final PortableBackupScope scope;
  final int assetCount;
  final int missingAssetCount;
}

