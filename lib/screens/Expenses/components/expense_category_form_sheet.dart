import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../controller/ExpensesController.dart';
import 'expense_category_style.dart';
import '../../../core/widgets/common/centered_fa_icon.dart';

Future<void> showExpenseCategoryFormSheet(
  BuildContext context,
  WidgetRef ref, {
  Map<String, dynamic>? existing,
}) async {
  final isDesktop = MediaQuery.sizeOf(context).width >= 1100;
  if (isDesktop) {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: SizedBox(
          width: 680,
          height: 720,
          child: _ExpenseCategoryFormSheet(
            existing: existing,
            desktopMode: true,
          ),
        ),
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExpenseCategoryFormSheet(existing: existing),
  );
}

class _ExpenseCategoryFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final bool desktopMode;

  const _ExpenseCategoryFormSheet({
    this.existing,
    this.desktopMode = false,
  });

  @override
  ConsumerState<_ExpenseCategoryFormSheet> createState() =>
      _ExpenseCategoryFormSheetState();
}

class _ExpenseCategoryFormSheetState
    extends ConsumerState<_ExpenseCategoryFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _selectedColor;
  late int _selectedIconCode;
  late bool _hidden;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );
    _selectedColor = existing?['color']?.toString() ??
        ExpenseCategoryStyle.defaultColorHex;
    _selectedIconCode = ExpenseCategoryStyle.normalizeIconCode(
      existing?['icon_code'],
      title: existing?['title']?.toString(),
    );
    _hidden = ((existing?['hidden'] as num?)?.toInt() ?? 0) == 1;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      final service = ref.read(dbExpenseServiceProvider);
      if (_isEditing) {
        await service.editExpensesTitle(
          (widget.existing!['id'] as num).toInt(),
          {
            'title': title,
            'description': _descriptionController.text.trim(),
            'color': _selectedColor,
            'icon_code': _selectedIconCode,
            'icon_font_family': ExpenseCategoryStyle.materialFontFamily,
            'hidden': _hidden,
          },
        );
      } else {
        await service.addExpensesTitle(
          title,
          _descriptionController.text.trim(),
          color: _selectedColor,
          iconCode: _selectedIconCode,
          hidden: _hidden,
        );
      }

      ref.invalidate(expenseSummaryProvider);
      ref.invalidate(expenseCategoriesProvider);
      if (_isEditing) {
        ref.invalidate(
          expenseCategoryProvider((widget.existing!['id'] as num).toInt()),
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final selectedColor = ExpenseCategoryStyle.colorFromHex(_selectedColor);
    final selectedIcon = ExpenseCategoryStyle.iconFromCode(
      _selectedIconCode,
      title: _titleController.text,
    );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: neutral.background,
          borderRadius: widget.desktopMode
              ? BorderRadius.circular(20)
              : const BorderRadius.vertical(top: Radius.circular(24)),
          border: widget.desktopMode
              ? Border.all(color: neutral.divider.withOpacity(0.75))
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (!widget.desktopMode) ...[
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: neutral.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selectedColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: CenteredFaIcon(selectedIcon, color: selectedColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit category' : 'New category',
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose a clear icon and color for faster scanning.',
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: neutral.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.words,
                      autofocus: !_isEditing,
                      decoration: _decoration(
                        context,
                        label: 'Category name',
                        icon: Icons.category_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoration(
                        context,
                        label: 'Description (optional)',
                        icon: Icons.notes_outlined,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionTitle(context, 'Color'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: ExpenseCategoryStyle.colorOptions.map((hex) {
                        final color = ExpenseCategoryStyle.colorFromHex(hex);
                        final selected = hex == _selectedColor;
                        return InkWell(
                          onTap: () => setState(() => _selectedColor = hex),
                          borderRadius: BorderRadius.circular(18),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? neutral.textPrimary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 19,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),
                    _sectionTitle(context, 'Icon'),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ExpenseCategoryStyle.iconOptions.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (_, index) {
                        final icon = ExpenseCategoryStyle.iconOptions[index];
                        final selected = icon.codePoint == _selectedIconCode;
                        return InkWell(
                          onTap: () => setState(
                            () => _selectedIconCode = icon.codePoint,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: selected
                                  ? selectedColor.withOpacity(0.16)
                                  : neutral.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? selectedColor
                                    : neutral.divider.withOpacity(0.6),
                              ),
                            ),
                            child: CenteredFaIcon(
                              icon,
                              color: selected
                                  ? selectedColor
                                  : neutral.textSecondary,
                              size: 22,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: neutral.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: neutral.divider),
                      ),
                      child: SwitchListTile.adaptive(
                        value: _hidden,
                        onChanged: (value) => setState(() => _hidden = value),
                        secondary: Icon(
                          _hidden
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: selectedColor,
                        ),
                        title: Text(
                          'Hide from category list',
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Hidden categories remain included in totals, closings, backups, and reports.',
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isEditing ? 'Save changes' : 'Create category'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final neutral = context.themeColors.neutral;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: neutral.textSecondary),
      prefixIcon: Icon(icon, color: AppColors.expense),
      filled: true,
      fillColor: neutral.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: neutral.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: neutral.divider),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final neutral = context.themeColors.neutral;
    return Text(
      title,
      style: TextStyle(
        color: neutral.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    );
  }
}
