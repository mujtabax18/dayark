import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';
import 'package:uuid/uuid.dart';

import '../../../controller/currency_notifier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../services/database_service.dart';
import '../../../utlis/app_router.dart';
import '../data/invoiceProvider.dart';
import '../data/invoice_model.dart';
import '../data/invoice_profile_model.dart';
import '../data/invoice_profile_service.dart';
import 'InvoiceDataManagementScreen.dart';
import 'PdfInvoiceService.dart';
import '../../navigation/widgets/desktop_content_frame.dart';

part 'parts/invoice_form_screen_state.dart';
part 'parts/invoice_form_screen_business_selection_sheet.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  final Invoice? invoice;
  final bool desktopEmbedded;

  const InvoiceFormScreen({
    super.key,
    this.invoice,
    this.desktopEmbedded = false,
  });

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

