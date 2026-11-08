import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:photo_view/photo_view.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_x.dart';
import '../../controller/mediaController.dart';
import '../../models/MediaFile.dart';
import 'MediaHistoryScreen.dart';
import 'PdfEditorScreen.dart';
import 'VideoEditorScreen.dart';

part 'parts/media_viewer_screen_state.dart';
part 'parts/media_viewer_screen_info_row.dart';

class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.mediaFile,
  });

  final MediaFile mediaFile;

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

