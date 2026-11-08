import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';

import '../database_service.dart';
import '../db/drift_database.dart';
import '../backupService.dart';
import '../portable_backup_crypto.dart';
import '../restoreService.dart';
import 'local_sync_tls.dart';

part 'parts/device_sync_service_sync_role.dart';
part 'parts/device_sync_service_device_sync_service.dart';

