import 'package:flutter/material.dart';

import '../../../core/widgets/common/app_dialogs.dart';

Future<bool?> confirmDelete(BuildContext context) async {
  return showAppConfirmDialog(
    context,
    title: 'Delete expense?',
    message: 'This expense will be permanently removed.',
    confirmLabel: 'Delete',
    destructive: true,
  );
}
