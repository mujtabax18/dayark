import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_tokens.dart';
import '../models/family_tree_models.dart';
import '../services/family_tree_repository.dart';
import 'family_photo_gallery.dart';

/// Manage all photographs of a person without altering their other details.
class FamilyMemberPhotosSheet extends StatefulWidget {
  const FamilyMemberPhotosSheet({
    super.key,
    required this.member,
    required this.repository,
  });

  final FamilyMember member;
  final FamilyTreeRepository repository;

  @override
  State<FamilyMemberPhotosSheet> createState() =>
      _FamilyMemberPhotosSheetState();
}

class _FamilyMemberPhotosSheetState extends State<FamilyMemberPhotosSheet> {
  final ImagePicker _picker = ImagePicker();
  late List<FamilyPhoto> _photos = widget.member.photos;
  String? _coverPath;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _coverPath = widget.member.profileImagePath;
  }

  Future<void> _addPhotos() async {
    final files = await _picker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1920,
    );
    if (!mounted || files.isEmpty) return;
    await _perform(() async {
      await widget.repository.addMemberPhotos(
        treeId: widget.member.treeId,
        memberId: widget.member.id,
        sourcePaths: files.map((file) => file.path).toList(),
      );
    });
  }

  Future<void> _makeCover(FamilyPhoto photo) async {
    await _perform(
      () => widget.repository.setMemberCoverPhoto(
        memberId: widget.member.id,
        path: photo.path,
      ),
    );
    if (mounted) setState(() => _coverPath = photo.path);
  }

  Future<void> _delete(FamilyPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove photo?'),
        content: const Text(
          'The selected photo will be deleted from this person’s gallery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _perform(
      () => widget.repository.deleteMemberPhoto(
        memberId: widget.member.id,
        photo: photo,
      ),
    );
    if (mounted && _coverPath == photo.path) setState(() => _coverPath = null);
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      final next = await widget.repository.getMemberPhotos(widget.member.id);
      if (!mounted) return;
      setState(() {
        _photos = next;
        _changed = true;
      });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update photos: $error')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPaths = <String>[
      if (_coverPath != null) _coverPath!,
      ..._photos
          .where((photo) => photo.path != _coverPath)
          .map((photo) => photo.path),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.member.fullName} · Photos',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_changed),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (allPaths.isNotEmpty)
                FamilyPhotoGallery(paths: allPaths, height: 190),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Select a photo as the profile picture, or add photos from different days.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _addPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add multiple photos'),
                ),
              ),
              if (_saving) const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.sm),
              if (_photos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No extra photos yet. Your profile photo is kept separately.',
                  ),
                ),
              ..._photos.map(
                (photo) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(photo.path),
                      width: 54,
                      height: 54,
                      cacheWidth: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  title: Text(
                    photo.path == _coverPath
                        ? 'Profile photo'
                        : 'Gallery photo',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Make profile photo',
                        onPressed: _saving || photo.path == _coverPath
                            ? null
                            : () => _makeCover(photo),
                        icon: Icon(
                          photo.path == _coverPath
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete photo',
                        onPressed: _saving ? null : () => _delete(photo),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_changed),
                  child: const Text('Done'),
                ),
              ),
              SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
            ],
          ),
        ),
      ),
    );
  }
}
