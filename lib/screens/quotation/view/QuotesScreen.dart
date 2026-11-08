import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../models/quotation.dart';
import '../../HomeScreen/controller/home_quote_provider.dart';
import '../controller/quotation_controller.dart';
import '../services/quotation_prompt_service.dart';
import '../services/quotation_service.dart';
import 'OnlineQuotationLibrarySheet.dart';
import 'QuotationEditorScreen.dart';
import 'QuotationManagementSheet.dart';
import '../../../core/widgets/common/centered_fa_icon.dart';
import '../../navigation/widgets/desktop_content_frame.dart';

part 'parts/quotes_screen_state.dart';
part 'parts/quotes_screen_desktop_quotation_prompt_builder_page.dart';
part 'parts/quotes_screen_desktop_paste_generated_quotations_page_state.dart';
part 'parts/quotes_screen_desktop_quotation_form_page.dart';
part 'parts/quotes_screen_quotation_card.dart';

class QuotesScreen extends ConsumerStatefulWidget {
  const QuotesScreen({
    super.key,
    this.openCreateOnStart = false,
    this.desktopEmbedded = false,
    this.onOpenOnlineLibrary,
    this.onOpenManagement,
  });

  final bool openCreateOnStart;
  final bool desktopEmbedded;
  final VoidCallback? onOpenOnlineLibrary;
  final VoidCallback? onOpenManagement;

  @override
  ConsumerState<QuotesScreen> createState() => QuotesScreenState();
}

