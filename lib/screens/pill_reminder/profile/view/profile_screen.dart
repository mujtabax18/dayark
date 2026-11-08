import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/pill_ui_helpers.dart';
import '../provider/profile_provider.dart';
import '../../../navigation/widgets/desktop_content_frame.dart';

class PillProfileScreen extends ConsumerWidget {
  const PillProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    Map<String, dynamic>? activeProfile;
    for (final profile in state.profiles) {
      if (profile['is_active'] == 1) {
        activeProfile = profile;
        break;
      }
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Profiles')),
      body: DesktopContentFrame(
        child: RefreshIndicator(
        onRefresh: controller.loadProfiles,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
          children: [
            _ProfileIntro(
              activeName: activeProfile?['name']?.toString(),
              profileCount: state.profiles.length,
            ),
            const SizedBox(height: 18),
            Text(
              'All profiles',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Switch between people who use this reminder.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null)
              _ProfileMessage(
                icon: Icons.error_outline_rounded,
                title: 'Could not load profiles',
                subtitle: state.error!,
                color: scheme.error,
              )
            else if (state.profiles.isEmpty)
              const _ProfileMessage(
                icon: Icons.person_add_alt_1_outlined,
                title: 'No profiles yet',
                subtitle: 'Create a profile to organize medicine reminders.',
              )
            else
              ...state.profiles.map((profile) {
                final isActive = profile['is_active'] == 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProfileCard(
                    profile: profile,
                    isActive: isActive,
                    onActivate: () =>
                        controller.setActiveProfile(profile['id'] as int),
                    onEdit: () => _showEditDialog(
                      context,
                      initial: profile['name'].toString(),
                      title: 'Edit profile',
                      onSave: (name) => controller.updateProfile(
                        profile['id'] as int,
                        name,
                      ),
                    ),
                    onDelete: () => _confirmDelete(
                      context,
                      profileName: profile['name'].toString(),
                      onConfirm: () =>
                          controller.deleteProfile(profile['id'] as int),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showEditDialog(
            context,
            initial: '',
            title: 'Add profile',
            onSave: controller.addProfile,
          );
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add profile'),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context, {
    required String initial,
    required String title,
    required Future<void> Function(String) onSave,
  }) {
    final textCtrl = TextEditingController(text: initial);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          initial.isEmpty
              ? Icons.person_add_alt_1_outlined
              : Icons.edit_outlined,
        ),
        title: Text(title),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Profile name',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          onSubmitted: (value) async {
            final name = value.trim();
            if (name.isEmpty) return;
            Navigator.pop(dialogContext);
            await onSave(name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = textCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogContext);
              await onSave(name);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(textCtrl.dispose);
  }

  void _confirmDelete(
    BuildContext context, {
    required String profileName,
    required Future<void> Function() onConfirm,
  }) {
    final scheme = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
        title: const Text('Delete profile?'),
        content: Text(
          '“$profileName” and its related reminder data will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await onConfirm();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ProfileIntro extends StatelessWidget {
  const _ProfileIntro({
    required this.activeName,
    required this.profileCount,
  });

  final String? activeName;
  final int profileCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PillUi.cardDecoration(
        context,
        color: PillUi.tintedSurface(context, scheme.primary, opacity: .07),
        borderColor: scheme.primary.withOpacity(.17),
        radius: 25,
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: PillUi.tintedSurface(
                context,
                scheme.primary,
                opacity: .13,
              ),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(
              Icons.people_outline_rounded,
              color: scheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeName == null ? 'Manage profiles' : 'Active profile',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activeName ?? 'No active profile',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$profileCount ${profileCount == 1 ? 'profile' : 'profiles'} available',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onActivate,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> profile;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: PillUi.cardDecoration(
        context,
        color: isActive
            ? PillUi.tintedSurface(context, scheme.primary, opacity: .05)
            : null,
        borderColor: isActive
            ? scheme.primary.withOpacity(.32)
            : scheme.outlineVariant.withOpacity(.75),
        radius: 20,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: PillUi.tintedSurface(
                context,
                isActive ? scheme.primary : scheme.onSurfaceVariant,
                opacity: isActive ? .12 : .07,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              isActive
                  ? Icons.check_circle_rounded
                  : Icons.person_outline_rounded,
              color: isActive ? scheme.primary : scheme.onSurfaceVariant,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile['name'].toString(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive ? 'Currently active' : 'Tap menu to activate',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isActive
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Profile options',
            onSelected: (value) {
              switch (value) {
                case 'activate':
                  onActivate();
                  break;
                case 'edit':
                  onEdit();
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (_) => [
              if (!isActive)
                const PopupMenuItem(
                  value: 'activate',
                  child: _ProfileMenuItem(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Set active',
                  ),
                ),
              const PopupMenuItem(
                value: 'edit',
                child: _ProfileMenuItem(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: _ProfileMenuItem(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: scheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 11),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = color ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: PillUi.cardDecoration(context, radius: 22),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: PillUi.tintedSurface(context, accent, opacity: .10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: accent, size: 27),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
