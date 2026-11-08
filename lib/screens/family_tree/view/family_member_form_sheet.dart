import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_tokens.dart';
import '../models/family_tree_models.dart';
import '../services/family_tree_media_service.dart';
import '../services/family_tree_repository.dart';

class FamilyMemberFormSheet extends StatefulWidget {
  const FamilyMemberFormSheet({
    super.key,
    required this.treeId,
    required this.repository,
    this.member,
  });

  final int treeId;
  final FamilyTreeRepository repository;
  final FamilyMember? member;

  @override
  State<FamilyMemberFormSheet> createState() => _FamilyMemberFormSheetState();
}

class _FamilyMemberFormSheetState extends State<FamilyMemberFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _nickname;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _occupation;
  late final TextEditingController _description;
  late final TextEditingController _notes;

  String _gender = 'unspecified';
  DateTime? _birthDate;
  DateTime? _deathDate;
  String? _pickedImagePath;
  bool _removeExistingImage = false;
  final List<String> _additionalPhotos = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final member = widget.member;
    _firstName = TextEditingController(text: member?.firstName ?? '');
    _lastName = TextEditingController(text: member?.lastName ?? '');
    _nickname = TextEditingController(text: member?.nickname ?? '');
    _phone = TextEditingController(text: member?.phone ?? '');
    _email = TextEditingController(text: member?.email ?? '');
    _address = TextEditingController(text: member?.address ?? '');
    _occupation = TextEditingController(text: member?.occupation ?? '');
    _description = TextEditingController(text: member?.description ?? '');
    _notes = TextEditingController(text: member?.notes ?? '');
    _gender = member?.gender ?? 'unspecified';
    _birthDate = member?.birthDate;
    _deathDate = member?.deathDate;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _nickname.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _occupation.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (image == null || !mounted) return;
    setState(() {
      _pickedImagePath = image.path;
      _removeExistingImage = false;
    });
  }

  Future<void> _pickAdditionalPhotos() async {
    final images = await _picker.pickMultiImage(imageQuality: 82, maxWidth: 1920);
    if (!mounted || images.isEmpty) return;
    setState(() {
      for (final image in images) {
        if (!_additionalPhotos.contains(image.path)) _additionalPhotos.add(image.path);
      }
    });
  }

  Future<DateTime?> _pickDate(DateTime? current) async {
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1800),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    String? finalImagePath = widget.member?.profileImagePath;
    String? newlyCopiedPath;
    var memberSaved = false;
    try {
      if (_pickedImagePath != null) {
        newlyCopiedPath = await FamilyTreeMediaService.copyImage(
          treeId: widget.treeId,
          sourcePath: _pickedImagePath!,
          category: 'members',
        );
        finalImagePath = newlyCopiedPath;
      } else if (_removeExistingImage) {
        finalImagePath = null;
      }

      final values = <String, Object?>{
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'nickname': _nickname.text.trim(),
        'gender': _gender,
        'birth_date': _birthDate?.toIso8601String(),
        'death_date': _deathDate?.toIso8601String(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'occupation': _occupation.text.trim(),
        'description': _description.text.trim(),
        'notes': _notes.text.trim(),
        'profile_image_path': finalImagePath,
      };

      final memberId = widget.member == null
          ? await widget.repository.createMember(treeId: widget.treeId, values: values)
          : widget.member!.id;
      if (widget.member != null) {
        await widget.repository.updateMember(memberId: memberId, values: values);
      }
      memberSaved = true;
      // A member can have many photos independent of the main portrait.
      if (_additionalPhotos.isNotEmpty) {
        await widget.repository.addMemberPhotos(
          treeId: widget.treeId, memberId: memberId,
          sourcePaths: _additionalPhotos,
        );
      }
      if (widget.member != null &&
          (_pickedImagePath != null || _removeExistingImage) &&
          widget.member!.profileImagePath != null &&
          widget.member!.profileImagePath != finalImagePath &&
          !widget.member!.photos.any((p) => p.path == widget.member!.profileImagePath)) {
        await FamilyTreeMediaService.deleteFile(widget.member!.profileImagePath);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      // Avoid orphaning a newly saved member image when an additional photo
      // import fails after the profile itself was committed.
      if (!memberSaved) {
        await FamilyTreeMediaService.deleteFile(newlyCopiedPath);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this person.')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingPath = widget.member?.profileImagePath;
    final selectedDisplayPath = _pickedImagePath ?? (_removeExistingImage ? null : existingPath);
    final displayPath = selectedDisplayPath != null && File(selectedDisplayPath).existsSync()
        ? selectedDisplayPath
        : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.member == null ? 'Add person' : 'Edit person',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundImage: displayPath == null ? null : FileImage(File(displayPath)),
                        child: displayPath == null ? const Icon(Icons.person_outline_rounded, size: 42) : null,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.xs,
                        children: [
                          TextButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(displayPath == null ? 'Add photo' : 'Change photo'),
                          ),
                          if (displayPath != null)
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _pickedImagePath = null;
                                _removeExistingImage = true;
                              }),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Remove'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickAdditionalPhotos,
                  icon: const Icon(Icons.collections_outlined),
                  label: Text(_additionalPhotos.isEmpty
                      ? 'Add more photos to this person'
                      : 'Add more photos (${_additionalPhotos.length} selected)'),
                ),
                if (widget.member != null && widget.member!.photos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Text('${widget.member!.photos.length} gallery photos saved. '
                        'Open Photos from the person details to manage them.',
                      style: Theme.of(context).textTheme.bodySmall),
                  ),
                if (_additionalPhotos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8,
                    children: _additionalPhotos.map((path) => Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(path), width: 70, height: 70,
                          cacheWidth: 200, fit: BoxFit.cover)),
                      Positioned(right: 0, top: 0, child: IconButton.filledTonal(
                        iconSize: 14,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(() => _additionalPhotos.remove(path)),
                        icon: const Icon(Icons.close_rounded),
                      )),
                    ])).toList(),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'First name *'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _lastName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Last name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _nickname,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nickname'),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'unspecified', child: Text('Prefer not to specify')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => _gender = value ?? 'unspecified'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Birth date',
                        value: _birthDate,
                        onTap: () async {
                          final date = await _pickDate(_birthDate);
                          if (date != null && mounted) setState(() => _birthDate = date);
                        },
                        onClear: _birthDate == null ? null : () => setState(() => _birthDate = null),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _DateField(
                        label: 'Death date',
                        value: _deathDate,
                        onTap: () async {
                          final date = await _pickDate(_deathDate);
                          if (date != null && mounted) setState(() => _deathDate = date);
                        },
                        onClear: _deathDate == null ? null : () => setState(() => _deathDate = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _address,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined)),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _occupation,
                  decoration: const InputDecoration(labelText: 'Occupation', prefixIcon: Icon(Icons.work_outline_rounded)),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Description / biography',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Private notes', alignLabelWithHint: true),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save member'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap, this.onClear});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.small,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded, size: 18)),
        ),
        child: Text(value == null ? 'Not set' : DateFormat.yMMMd().format(value!)),
      ),
    );
  }
}
