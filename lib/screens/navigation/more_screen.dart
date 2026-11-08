import 'package:flutter/material.dart';

import '../../core/design/app_tokens.dart';
import '../../core/design/responsive_layout.dart';
import '../../core/widgets/common/app_surface.dart';
import '../../utlis/app_router.dart';
import 'widgets/desktop_navigation_scope.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ResponsivePageFrame(
          maxWidth: 1320,
          child: CustomScrollView(
            key: const PageStorageKey<String>('more-section-scroll'),
            slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'More',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.4,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tools, learning and application management',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: _MoreGroup(
                  title: 'Tools',
                  items: [
                    _MoreItem(
                      title: 'Life Archives',
                      subtitle: 'Private people, friendships, milestones and photo memories',
                      icon: Icons.account_tree_outlined,
                      color: const Color(0xFF7C3AED),
                      onTap: () => openResponsiveModule(context, RoutesStr.familyTrees),
                    ),
                    _MoreItem(
                      title: 'Media Studio',
                      subtitle: 'Images, PDFs, videos and offline TTS',
                      icon: Icons.perm_media_outlined,
                      color: const Color(0xFFE11D48),
                      onTap: () => openResponsiveModule(context, RoutesStr.multimedia),
                    ),
                    _MoreItem(
                      title: 'Document Scanner',
                      subtitle: 'Scan, organize and export documents',
                      icon: Icons.document_scanner_outlined,
                      color: const Color(0xFF0EA5E9),
                      onTap: () => openResponsiveModule(context, RoutesStr.scannerGallery),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: _MoreGroup(
                  title: 'Learning',
                  items: [
                    _MoreItem(
                      title: 'Tutorial Center',
                      subtitle: 'Learn how to use each application module',
                      icon: Icons.school_outlined,
                      color: const Color(0xFF0F766E),
                      onTap: () => openResponsiveModule(context, RoutesStr.tutorials),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                context.mainShellBottomPadding,
              ),
              sliver: SliverToBoxAdapter(
                child: _MoreGroup(
                  title: 'Application',
                  items: [
                    _MoreItem(
                      title: 'Home & navigation',
                      subtitle: 'Layout, summaries, actions and shortcuts',
                      icon: Icons.dashboard_customize_outlined,
                      color: const Color(0xFF6366F1),
                      onTap: () => openResponsiveModule(context, RoutesStr.homeSetting),
                    ),
                    _MoreItem(
                      title: 'Settings',
                      subtitle: 'Currency, theme, language, backup and restore',
                      icon: Icons.settings_outlined,
                      color: const Color(0xFF64748B),
                      onTap: () => openResponsiveModule(context, RoutesStr.settings),
                    ),
                    _MoreItem(
                      title: 'Backup & restore',
                      subtitle: 'Portable database and media backups',
                      icon: Icons.settings_backup_restore_rounded,
                      color: const Color(0xFFF59E0B),
                      onTap: () => openResponsiveModule(context, RoutesStr.backup),
                    ),
                    _MoreItem(
                      title: 'Theme & language',
                      subtitle: 'Appearance, color style and localization',
                      icon: Icons.palette_outlined,
                      color: const Color(0xFF8B5CF6),
                      onTap: () => openResponsiveModule(context, RoutesStr.settings),
                    ),
                    _MoreItem(
                      title: 'Database Inspector',
                      subtitle: 'Advanced local database viewer',
                      icon: Icons.storage_outlined,
                      color: const Color(0xFF0891B2),
                      onTap: () => openResponsiveModule(context, RoutesStr.dataBaseViewer),
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreGroup extends StatelessWidget {
  const _MoreGroup({required this.title, required this.items});

  final String title;
  final List<_MoreItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              // Preserve the existing mobile/tablet list presentation.
              return AppSurface(
                padding: EdgeInsets.zero,
                borderRadius: AppRadius.large,
                child: Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      _MoreRow(item: items[index]),
                      if (index != items.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              );
            }

            const gap = AppSpacing.sm;
            final columns = constraints.maxWidth >= 1180 ? 3 : 2;
            final itemWidth =
                (constraints.maxWidth - ((columns - 1) * gap)) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: items
                  .map(
                    (item) => SizedBox(
                      width: itemWidth,
                      child: AppSurface(
                        padding: EdgeInsets.zero,
                        borderRadius: AppRadius.large,
                        child: _MoreRow(item: item, desktop: true),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.item, this.desktop = false});

  final _MoreItem item;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: desktop ? AppSpacing.md : AppSpacing.sm,
        vertical: desktop ? 10 : 3,
      ),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: item.color.withOpacity(.12),
          borderRadius: AppRadius.small,
        ),
        child: Icon(item.icon, color: item.color, size: 21),
      ),
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        item.subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: scheme.onSurfaceVariant,
      ),
      onTap: item.onTap,
    );
  }
}

class _MoreItem {
  const _MoreItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
