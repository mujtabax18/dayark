import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cross_file/cross_file.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:metersystem/utlis/constant.dart';
import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';
import 'package:share_plus/share_plus.dart';
import 'db/drift_database.dart';
import 'portable_backup_crypto.dart';

part 'parts/backup_service_backup_save_result.dart';
part 'parts/backup_service_backup_service.dart';

enum BackupSaveStatus { saved, cancelled, permissionDenied, failed }

enum PortableBackupScope { fullDatabase, mediaLibrary, documentScanner }

extension PortableBackupScopeX on PortableBackupScope {
  String get storageKey => switch (this) {
    PortableBackupScope.fullDatabase => 'full_database',
    PortableBackupScope.mediaLibrary => 'media_library',
    PortableBackupScope.documentScanner => 'document_scanner',
  };

  String get title => switch (this) {
    PortableBackupScope.fullDatabase => 'Full app backup',
    PortableBackupScope.mediaLibrary => 'Media studio backup',
    PortableBackupScope.documentScanner => 'Document scanner backup',
  };
}

