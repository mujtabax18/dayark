import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


import '../../../core/design/app_tokens.dart';
import '../../../core/widgets/common/app_surface.dart';
import '../models/family_tree_models.dart';
import '../models/life_archive_models.dart';
import '../services/family_tree_repository.dart';
import '../services/life_archive_repository.dart';
import 'family_member_form_sheet.dart';
import 'life_connection_sheet.dart';
import 'life_event_form_sheet.dart';
import 'family_quick_relative_sheet.dart';
import 'family_constellation_view.dart';
import 'family_memory_form_sheet.dart';
import 'family_relationship_sheet.dart';
import 'family_member_photos_sheet.dart';
import 'family_photo_gallery.dart';
import 'life_archive_detail_pages.dart';
import 'life_archive_media.dart';
import 'life_archive_desktop_widgets.dart';
import 'life_archive_inspector_panel.dart';
import '../../navigation/widgets/desktop_content_frame.dart';

part 'parts/family_tree_detail_screen_state.dart';
part 'parts/family_tree_detail_screen_tree_tab.dart';
part 'parts/family_tree_detail_screen_life.dart';

class FamilyTreeDetailScreen extends StatefulWidget {
  const FamilyTreeDetailScreen({
    super.key,
    required this.treeId,
    this.initialTabIndex = 0,
    this.initialMemoryId,
  });

  final int treeId;
  /// Optional in-app entry point from Media Studio; normal archive opens on Network.
  final int initialTabIndex;
  final int? initialMemoryId;

  @override
  State<FamilyTreeDetailScreen> createState() => _FamilyTreeDetailScreenState();
}

