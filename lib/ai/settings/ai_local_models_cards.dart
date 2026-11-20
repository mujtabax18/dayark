part of 'ai_local_models_screen.dart';

extension _AiModelCards on _AiLocalModelsScreenState {
  Widget _row(
    AiCatalogueModel? model, {
    AiLocalInstallation? installed,
    bool recommended = false,
  }) {
    final session = widget.models;
    final fit = model == null ? null : _fit(model);
    final id = model?.id ?? installed!.id;
    recommended = fit?.fit.recommended ?? false;
    final active = session.loadedId == id;
    final selected = widget.selectedId == id;
    final theme = Theme.of(context);
    return Card(
      color: active ? theme.colorScheme.primaryContainer : null,
      shape: active || recommended
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.primary,
                width: active ? 2 : 1,
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (active)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.check_circle,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                Expanded(
                  child: Text(
                    model?.name ?? installed!.name,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (recommended)
                  Tooltip(
                    message: 'Best model and quantization for this family on your device',
                    child: Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (model?.parameters case final count?)
                  '${count < 1 ? '${(count * 1000).round()}M' : '${count}B'} params',
                if (model != null) model.quantization,
                '${model?.artifact == null && installed == null ? '≈' : ''}${_size(installed?.bytes ?? model?.artifact?.bytes ?? model?.estimatedDiskBytes)}',
                if (fit != null) '≈${_size(fit.memoryBytes)} RAM',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (fit != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _fitIcon(fit.fit),
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(fit.label, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (active || selected || recommended)
                  Text(
                    active
                        ? 'Active'
                        : selected
                        ? 'Selected'
                        : 'Recommended',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                IconButton(
                  tooltip: 'Compare model',
                  onPressed: () => _toggleCompare(id),
                  icon: Icon(
                    _comparison.contains(id)
                        ? Icons.check_box_outlined
                        : Icons.compare_arrows,
                    size: 19,
                  ),
                ),
                IconButton(
                  tooltip: 'Favourite model',
                  onPressed: () => _favourite(id),
                  icon: Icon(
                    _favourites.contains(id) ? Icons.star : Icons.star_border,
                    size: 19,
                  ),
                ),
                TextButton(
                  onPressed: () => _details(model, installed: installed),
                  child: const Text('View More'),
                ),
                if (installed != null) ...[
                  IconButton(
                    tooltip: 'Use model',
                    onPressed: session.busy ? null : () => _use(id),
                    icon: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                  ),
                  IconButton(
                    tooltip: active ? 'Model active' : 'Load model',
                    onPressed: session.busy || active
                        ? null
                        : () => session.load(id),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                  IconButton(
                    tooltip: 'Delete model',
                    onPressed: session.busy ? null : () => _delete(installed),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ] else
                  IconButton(
                    tooltip: 'Download ${model!.quantization}',
                    onPressed: session.busy || !model.downloadable
                        ? null
                        : () => _install(model),
                    icon: const Icon(Icons.download_outlined),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Iterable<Widget> _downloadRows(AiModelFamily family) sync* {
    final groups = <String, List<AiCatalogueModel>>{};
    for (final model in family.models) {
      groups.putIfAbsent(model.name, () => []).add(model);
    }
    for (final group in groups.entries) {
      final variants = group.value;
      final recommended = variants
          .where((m) => m.id == family.recommendedId)
          .firstOrNull;
      final selected =
          variants
              .where((m) => m.id == _selectedVariants[group.key])
              .firstOrNull ??
          recommended ??
          variants.first;
      Widget recommendation(AiCatalogueModel model) =>
          model.id == family.recommendedId
          ? Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.auto_awesome,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : const SizedBox.shrink();
      yield Column(
        key: ValueKey('download-model-${group.key}'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.key,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      DropdownButton<String>(
                        key: ValueKey('model-version-${group.key}'),
                        value: selected.id,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        menuMaxHeight: 420,
                        borderRadius: BorderRadius.circular(16),
                        items: variants
                            .map(
                              (model) => DropdownMenuItem(
                                value: model.id,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${model.quantization} · ${model.artifact == null ? '≈' : ''}${_size(model.artifact?.bytes ?? model.estimatedDiskBytes)}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    recommendation(model),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: widget.models.busy
                            ? null
                            : (id) {
                                if (id != null) {
                                  _update(
                                    () => _selectedVariants[group.key] = id,
                                  );
                                }
                              },
                      ),
                      Row(
                        children: [
                          Icon(_fitIcon(_fit(selected).fit), size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _fit(selected).label,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Compare model',
                  onPressed: () => _toggleCompare(selected.id),
                  icon: Icon(
                    _comparison.contains(selected.id)
                        ? Icons.check_box_outlined
                        : Icons.compare_arrows,
                    size: 19,
                  ),
                ),
                IconButton(
                  tooltip: 'Favourite model',
                  onPressed: () => _favourite(selected.id),
                  icon: Icon(
                    _favourites.contains(selected.id)
                        ? Icons.star
                        : Icons.star_border,
                    size: 19,
                  ),
                ),
                IconButton(
                  tooltip: 'Model details',
                  onPressed: () => _details(selected),
                  icon: const Icon(Icons.info_outline, size: 20),
                ),
                IconButton.filled(
                  tooltip: 'Download ${selected.quantization}',
                  onPressed: widget.models.busy || !selected.downloadable
                      ? null
                      : () => _install(selected),
                  icon: const Icon(Icons.download_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      );
    }
  }
}
