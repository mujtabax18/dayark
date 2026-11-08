import 'package:flutter/material.dart';

import '../controllers/ScanGroupViewController.dart';

class AddMoreTile extends StatelessWidget {
  final VoidCallback onTap;

  const AddMoreTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Icon(Icons.add, size: 36),
        ),
      ),
    );
  }
}

Future<void> confirmGroupDelete(
  BuildContext context,
  ScanGroupViewController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete group'),
      content: const Text(
        'This will permanently delete this group and all its scans.\n\nThis action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await controller.deleteGroup();
    if (context.mounted) Navigator.of(context).pop();
  }
}

Future<void> confirmDeleteScan(
  BuildContext context,
  ScanGroupViewController controller,
  int scanId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete scan'),
      content: const Text(
        'This scan will be permanently deleted.\n\nThis action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await controller.deleteScan(scanId);
  }
}

Future<void> editTitle(
  BuildContext context,
  ScanGroupViewController controller,
  String current,
) async {
  final textController = TextEditingController(text: current);

  final result = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Edit group name'),
      content: TextField(controller: textController),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, textController.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (result != null && result.isNotEmpty) {
    await controller.renameGroup(result);
  }
}
