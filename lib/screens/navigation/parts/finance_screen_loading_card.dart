part of '../finance_screen.dart';

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('Financial summary is unavailable.')),
          IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
        ],
      ),
    );
  }
}

