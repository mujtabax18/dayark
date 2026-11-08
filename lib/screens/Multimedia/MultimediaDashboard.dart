import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide MediaQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_x.dart';
import '../../controller/mediaController.dart';
import '../../models/MediaCollection.dart';
import '../../models/MediaFile.dart';
import 'MediaBackupRestoreScreen.dart';
import 'MediaViewerScreen.dart';
import 'OfflineTtsScreen.dart';
import 'PdfEditorScreen.dart';
import 'VideoEditorScreen.dart';
import 'media_linked_libraries.dart';
import '../family_tree/view/family_tree_detail_screen.dart';
import '../scanner/view/ScanGroupViewScreen.dart';
import '../scanner/controllers/provideers/scanGroupRepoProvider.dart';
import '../scanner/data/models/ScanGroupPreview.dart';

part 'parts/multimedia_dashboard_state.dart';
part 'parts/multimedia_dashboard_view_mode_toggle.dart';
part 'parts/multimedia_dashboard_collection_empty_state.dart';
part 'parts/multimedia_dashboard_media_collections_sheet_state.dart';
part 'parts/multimedia_dashboard_media_card.dart';

enum _MediaHomeView { collections, library }

class MultimediaDashboard extends ConsumerStatefulWidget {
  const MultimediaDashboard({super.key, this.initialAction});

  final String? initialAction;

  @override
  ConsumerState<MultimediaDashboard> createState() =>
      _MultimediaDashboardState();
}

