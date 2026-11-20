part of 'ai_local_models_screen.dart';

extension _AiModelLibrary on _AiLocalModelsScreenState {
  Future<void> _loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _update(() {
      _favourites.addAll(
        prefs.getStringList('dayark.ai.models.favourites') ?? [],
      );
      _recent = prefs.getStringList('dayark.ai.models.recent') ?? [];
    });
  }

  Future<void> _favourite(String id) async {
    _update(() {
      if (!_favourites.remove(id)) _favourites.add(id);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'dayark.ai.models.favourites',
      _favourites.toList(),
    );
  }

  Future<void> _use(String id) async {
    final prefs = await SharedPreferences.getInstance();
    _recent = [id, ..._recent.where((value) => value != id)].take(20).toList();
    await prefs.setStringList('dayark.ai.models.recent', _recent);
    if (mounted) Navigator.pop(context, id);
  }

  bool _matches(String id, String name, Set<String?> recommendations) {
    final model = _entry(id);
    if (!'$name ${model?.metadata['family'] ?? ''} ${model?.quantization ?? ''}'
        .toLowerCase()
        .contains(_query.toLowerCase())) {
      return false;
    }
    if (_quantization != null && model?.quantization != _quantization) {
      return false;
    }
    if (_compatibleOnly && (model == null || !_fit(model).fit.recommended)) {
      return false;
    }
    return switch (_section) {
      'Installed' => widget.models.installed.any((m) => m.id == id),
      'Favourites' => _favourites.contains(id),
      'Recently used' => _recent.contains(id),
      'Recommended' => recommendations.contains(id),
      'Downloads' => false,
      _ => true,
    };
  }

  int _compare(AiCatalogueModel a, AiCatalogueModel b) {
    final result = switch (_sort) {
      'Download size' => (a.artifact?.bytes ?? a.estimatedDiskBytes).compareTo(
        b.artifact?.bytes ?? b.estimatedDiskBytes,
      ),
      'Memory estimate' => a.estimatedRamBytes.compareTo(b.estimatedRamBytes),
      'Favourites' => (_favourites.contains(b.id) ? 1 : 0).compareTo(
        _favourites.contains(a.id) ? 1 : 0,
      ),
      'Recently used' =>
        (_recent.contains(a.id) ? _recent.indexOf(a.id) : 999).compareTo(
          _recent.contains(b.id) ? _recent.indexOf(b.id) : 999,
        ),
      _ => a.name.compareTo(b.name),
    };
    return result == 0 ? a.name.compareTo(b.name) : result;
  }


  Future<void> _compareModels() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Compare models'),
      content: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Property')),
            for (final id in _comparison)
              DataColumn(
                label: SizedBox(
                  width: 150,
                  child: Text(_entry(id)?.name ?? id, maxLines: 2),
                ),
              ),
          ],
          rows: [
            for (final property in [
              'Quantization',
              'Parameters',
              'Download',
              'Estimated memory',
              'Memory fit',
              'Measured throughput',
            ])
              DataRow(
                cells: [
                  DataCell(Text(property)),
                  for (final id in _comparison)
                    DataCell(Text(_comparisonValue(id, property))),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  String _comparisonValue(String id, String property) {
    final model = _entry(id);
    final installed = widget.models.installed
        .where((m) => m.id == id)
        .firstOrNull;
    final speed = installed?.detectedModel?.performance?.tokensPerSecond;
    return switch (property) {
      'Quantization' => model?.quantization ?? 'Unknown',
      'Parameters' => model?.parameters?.toString() ?? 'Unknown',
      'Download' => _size(
        model?.artifact?.bytes ?? model?.estimatedDiskBytes ?? installed?.bytes,
      ),
      'Estimated memory' => _size(
        installed?.detectedModel?.estimatedMemoryBytes ??
            model?.estimatedRamBytes,
      ),
      'Memory fit' => model == null ? 'Unknown' : _fit(model).label,
      _ =>
        speed == null
            ? 'Not measured'
            : '${speed.toStringAsFixed(1)} tok/s · includes prompt',
    };
  }

  void _toggleCompare(String id) => _update(() {
    if (!_comparison.remove(id) && _comparison.length < 3) _comparison.add(id);
  });
}
