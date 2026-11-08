import 'package:flutter/material.dart';

import '../../../../core/widgets/common/app_dialogs.dart';

Future<bool> showDeleteReadingDialog(
  BuildContext context,
  num reading,
  Function() onDeleteConfirmed,
) async {
  final confirmed = await showAppConfirmDialog(
    context,
    title: 'Delete reading?',
    message: 'Delete reading ${_format(reading)}? This cannot be undone.',
    confirmLabel: 'Delete reading',
    destructive: true,
  );

  if (confirmed) onDeleteConfirmed();
  return confirmed;
}

String _format(num value) {
  final number = value.toDouble();
  return number == number.roundToDouble()
      ? number.toStringAsFixed(0)
      : number.toStringAsFixed(2);
}
