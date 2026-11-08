import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';
import 'package:uuid/uuid.dart';

import '../../../controller/currency_notifier.dart';
import '../../../services/database_service.dart';
import '../../../utlis/app_router.dart';
import '../data/invoice_profile_model.dart';
import '../data/invoice_profile_service.dart';
import '../../navigation/widgets/desktop_content_frame.dart';

part 'parts/invoice_data_management_screen_state.dart';
part 'parts/invoice_data_management_screen_preferences_tab_state.dart';
part 'parts/invoice_data_management_screen_business_editor_screen_state.dart';
part 'parts/invoice_data_management_screen_asset_tile.dart';

class InvoiceDataManagementScreen extends StatefulWidget {
  const InvoiceDataManagementScreen({super.key});

  @override
  State<InvoiceDataManagementScreen> createState() =>
      _InvoiceDataManagementScreenState();
}

