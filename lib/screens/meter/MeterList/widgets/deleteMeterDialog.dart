import 'package:flutter/material.dart';

import '../../../../core/widgets/common/app_dialogs.dart';

Future<bool> showDeleteMeterDialog(
  BuildContext context,
  String meterName,
  Function() onDeleteConfirmed,
) async {
  final confirmed = await showAppConfirmDialog(
    context,
    title: 'Delete meter?',
    message: 'Delete "$meterName" and all of its readings? This cannot be undone.',
    confirmLabel: 'Delete meter',
    destructive: true,
  );

  if (confirmed) onDeleteConfirmed();
  return confirmed;
}
