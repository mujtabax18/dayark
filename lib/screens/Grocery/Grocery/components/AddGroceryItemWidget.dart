import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme_x.dart';
import '../controller/grocery_controller.dart';
import '../shared/grocery_catalog.dart';
import '../../../../core/widgets/common/centered_fa_icon.dart';
part 'parts/existing_grocery_items_sheet.dart';
part 'parts/grocery_item_editor_sheet.dart';

class AddGroceryItemWidget extends ConsumerWidget {
  const AddGroceryItemWidget({super.key, required this.groceryId});

  final int groceryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neutral = context.themeColors.neutral;

    final addExistingButton = OutlinedButton.icon(
      onPressed: () => showExistingGroceryItemsSelector(
        context,
        ref,
        groceryId: groceryId,
      ),
      icon: const CenteredFaIcon(FontAwesomeIcons.listCheck, size: 15),
      label: const Text('Existing items'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: neutral.divider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );

    final addNewButton = FilledButton.icon(
      onPressed: () => showGroceryItemEditor(
        context,
        ref,
        groceryId: groceryId,
      ),
      icon: const CenteredFaIcon(FontAwesomeIcons.plus, size: 15),
      label: const Text('New item'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 350) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: double.infinity, child: addNewButton),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: addExistingButton),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: addExistingButton),
                const SizedBox(width: 10),
                Expanded(child: addNewButton),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<void> showGroceryItemEditor(
  BuildContext context,
  WidgetRef ref, {
  required int groceryId,
  Map<String, dynamic>? item,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GroceryItemEditorSheet(
      groceryId: groceryId,
      item: item,
    ),
  ).then((_) => refreshGroceryDashboard(ref, groceryId: groceryId));
}


Future<void> showExistingGroceryItemsSelector(
  BuildContext context,
  WidgetRef ref, {
  required int groceryId,
}) {
  ref.invalidate(reusableGroceryItemsProvider(groceryId));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ExistingGroceryItemsSheet(groceryId: groceryId),
  ).then((_) => refreshGroceryDashboard(ref, groceryId: groceryId));
}

