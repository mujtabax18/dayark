import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';

void showSnackbar(
  BuildContext context,
  String title,
  String message,
  ContentType contentType,
) {
  final snackBar = SnackBar(
    padding: EdgeInsets.zero,
    backgroundColor: Colors.transparent,
    content: AwesomeSnackbarContent(
      title: title,
      message: message,
      contentType: contentType,
    ),
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}

void showBanner(
  BuildContext context,
  String title,
  String message,
  ContentType contentType,
) {
  final materialBanner = MaterialBanner(
    padding: EdgeInsets.zero,
    backgroundColor: Colors.transparent,
    forceActionsBelow: true,
    content: AwesomeSnackbarContent(
      title: title,
      message: message,
      contentType: contentType,
      inMaterialBanner: true,
    ),
    actions: [
      TextButton(
        onPressed: () =>
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
        child: const Text('Dismiss'),
      ),
    ],
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentMaterialBanner()
    ..showMaterialBanner(materialBanner);
}
