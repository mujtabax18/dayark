import 'package:flutter/material.dart';

import '../../../core/widgets/common/app_dialogs.dart';

Future<bool?> showConfirmDeleteDialog(BuildContext context) async {
  return showAppConfirmDialog(
    context,
    title: 'Delete row?',
    message: 'This database row will be permanently removed.',
    confirmLabel: 'Delete',
    destructive: true,
  );
}
