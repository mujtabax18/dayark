# Automatic offline model configuration

- Installed/restored GGUF v2/v3 files supply architecture, context length, layer count and relevant scalar attention dimensions. Header scanning runs in a native Dart isolate and skips tokenizer arrays and tensor weights. Existing verified downloads are rescanned; no redownload is needed.
- Native context is an upper bound; selected context is calculated using detected memory and estimated KV usage. The engine's actual allocated context governs token fitting. If KV fields are missing (e.g. hybrid architectures), a conservative generic policy is used. Context values from shared online settings no longer cause local request rejection.
- GPU offload is estimated using detected GPU/shared-memory budget and model layer count; CPU fallback may progressively reduce context. Native process termination cannot be caught by Dart.
- Before download, artifact size estimates are used. After download, actual file size and metadata drive resource estimates. The generic performance bands are policy thresholds, not a table of model names or platform-specific recommendations. RAM estimates are not guarantees, particularly for nonstandard KV architectures. Manual benchmark remains optional.
- Successful normal generation saves numeric-only `.perf` telemetry beside the model, keyed by content-addressed path. This includes context, throughput, sampled process RAM (not isolated GPU/model usage), and load duration. No prompts or replies are stored in telemetry. A prior successful run remains visible even if context changes; throughput only affects the current classification if context matches.
- Extra prompt switch, custom instructions and language preferences remain in AI Settings. The chat-specific request preview is available in AI Settings opened from chat; it is unavailable from global settings because no chat request is in scope.
- Catalogue context/RAM fields remain for compatibility with existing catalogue data and saved defaults; they are not authoritative for installed chat models. The separate embedding runtime was not modified.

## Validation

The supplied archive is a source tree, not a complete Flutter project (no pubspec or native build files). Dart/Flutter SDK was unavailable during editing. Run on your development machine after merging into lib/:

```
dart run lib/qa/test_ai_gguf_metadata.dart
flutter analyze
flutter test
```

Smoke test: launch with a previously installed TinyLlama model and old 4096 global context setting, send `test`, ensure a response and that automatic context does not exceed the model's native limit. Reopen local model manager and verify the run status and performance details. Restart and check that prior success is retained. Switch to another model and verify that its context is detected independently. Open AI Settings from chat to check all prompt controls. Test online provider settings and local CPU/GPU fallback on each target platform.

## Compatibility update

- `AiModelFit.candidate` and `AiModelFit.insufficient` are deprecated static aliases for `smooth` and `veryHeavy`. They do not participate in `AiModelFit.values`, switches or recommendation calculations. Migrate old binary classification tests to assert the new graded policy and distinguish unavailable runtime from memory pressure.
- `AiLocalModel.contextSize` is optional and nullable. Managed downloads still supply the GGUF/device-derived value. Direct native registrations without a context resolve it during load with the same metadata reader and hardware probe. `activeContextSize` reports the allocated context.
- The supplied archive contains only library sources, not the external `test/ai` or `tool/ai` files. This patch preserves the reported constructor and enum references, but does not assert that old test expectations pass.
