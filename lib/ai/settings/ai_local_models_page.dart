import 'dart:async';

import 'package:flutter/material.dart';

import 'ai_defaults.dart';
import 'ai_local_models.dart';
import 'ai_local_models_screen.dart';

/// Navigate immediately; native verification belongs to this visible page.
class AiLocalModelsPage extends StatefulWidget {
  const AiLocalModelsPage({
    super.key,
    required this.load,
    required this.defaults,
    this.selectedId,
  });
  final Future<AiLocalModels> Function() load;
  final AiDefaults defaults;
  final String? selectedId;
  @override
  State<AiLocalModelsPage> createState() => _AiLocalModelsPageState();
}

class _AiLocalModelsPageState extends State<AiLocalModelsPage> {
  late Future<AiLocalModels> _models;
  final _closed = Completer<AiLocalModels>();
  @override
  void initState() {
    super.initState();
    _models = _load();
  }

  Future<AiLocalModels> _load() async =>
      await Future.any([widget.load(), _closed.future])
          .timeout(const Duration(seconds: 60));
  @override
  void dispose() {
    _closed.completeError(StateError('Model page closed.'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AiLocalModels>(
    future: _models,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return AiLocalModelsScreen(
          models: snapshot.requireData,
          defaults: widget.defaults,
          selectedId: widget.selectedId,
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Local model manager')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!snapshot.hasError) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text(
                    'Checking hardware and installed models…',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Verifying large GGUF files can take a moment.',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const Text(
                    'Unable to open local models. Check available storage and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      final next = _load();
                      setState(() {
                        _models = next;
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
