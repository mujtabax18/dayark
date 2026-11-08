import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../services/backupService.dart';
import '../../../services/database_service.dart';
import '../../../services/restoreService.dart';
import '../../Settings/components/backup_password_dialog.dart';
import '../../../utlis/platform_capabilities.dart';
import '../controllers/provideers/scanGroupRepoProvider.dart';
import '../controllers/provideers/scannerRepoProvider.dart';
import '../data/models/ScanGroupPreview.dart';
import '../services/scan_permission_service.dart';
import '../../navigation/widgets/desktop_content_frame.dart';

part 'parts/scanner_gallery_screen_state.dart';
part 'parts/scanner_gallery_screen_document_card.dart';

class ScannerGalleryScreen extends ConsumerStatefulWidget {
  const ScannerGalleryScreen({
    super.key,
    this.startWithCamera = false,
    this.desktopEmbedded = false,
    this.initialFavoritesOnly = false,
    this.onOpenGroup,
  });

  final bool startWithCamera;
  final bool desktopEmbedded;
  final bool initialFavoritesOnly;
  final ValueChanged<int>? onOpenGroup;

  @override
  ConsumerState<ScannerGalleryScreen> createState() =>
      _ScannerGalleryScreenState();
}

