import 'dart:io';
import 'package:flutter/material.dart';
import '../../../navigation/widgets/desktop_content_frame.dart';

class ShopManagementEntryScreen extends StatelessWidget {
  const ShopManagementEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Management'),
        centerTitle: MediaQuery.sizeOf(context).width < 1100,
      ),
      body: DesktopContentFrame(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShopHeaderCard(),
            const SizedBox(height: 24),
            Text(
              "Management",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _ManagementGrid(),
          ],
        ),
      ),
      ),
    );
  }
}

class _ShopHeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.storefront_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "My Super Shop",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Best grocery & daily needs store",
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Main Street, Block A, City Center",
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ManagementGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 760
                ? 3
                : 2;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: columns >= 3 ? 1.35 : 1.1,
          ),
          children: const [
        _ManagementButton(
          icon: Icons.store_rounded,
          label: "Shop Details",
        ),
        _ManagementButton(
          icon: Icons.category_rounded,
          label: "Categories",
        ),
        _ManagementButton(
          icon: Icons.account_tree_rounded,
          label: "Sub Categories",
        ),
        _ManagementButton(
          icon: Icons.straighten_rounded,
          label: "Units",
        ),
        _ManagementButton(
          icon: Icons.inventory_2_rounded,
          label: "Products",
        ),
        _ManagementButton(
          icon: Icons.local_offer_rounded,
          label: "Deals",
        ),
          ],
        );
      },
    );
  }
}

class _ManagementButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ManagementButton({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        // TODO: Add navigation later
      },
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: theme.colorScheme.surfaceVariant,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primaryContainer,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
