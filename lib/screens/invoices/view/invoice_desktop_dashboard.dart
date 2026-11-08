import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../data/invoiceProvider.dart';
import '../data/invoice_model.dart';
import 'InvoiceDataManagementScreen.dart';
import 'InvoiceFormScreen.dart';
import 'InvoiceViewScreen.dart';
import 'invoiceListScreen.dart';

part 'parts/invoice_desktop_dashboard_invoice_desktop_section.dart';
part 'parts/invoice_desktop_dashboard_sidebar_item.dart';

/// Desktop-only invoice workspace.
///
/// Owns a second-level sidebar and nested navigator so every invoice screen is
/// kept inside the desktop admin shell's right content area. Mobile routing is
/// intentionally left unchanged.
class InvoiceDesktopDashboard extends ConsumerStatefulWidget {
  const InvoiceDesktopDashboard({
    super.key,
    this.openCreateOnStart = false,
    this.openEditOnStart = false,
    this.initialInvoiceId,
    this.initialEditInvoice,
  });

  final bool openCreateOnStart;
  final bool openEditOnStart;
  final String? initialInvoiceId;
  final Invoice? initialEditInvoice;

  @override
  ConsumerState<InvoiceDesktopDashboard> createState() =>
      _InvoiceDesktopDashboardState();
}

