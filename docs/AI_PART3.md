# Part 3 — Hardware and local models (steps 16–21)

This extends the standalone AI module. Nothing loads, downloads or probes hardware
at app startup. All inference continues through the existing offline provider and
shared gateway. The settings and chat interfaces remain subsequent roadmap parts.

| Step | Implementation |
| --- | --- |
| 16 | `detectAiHardware(storagePath:)`: CPU, logical cores, physical/available memory, destination storage, available GPU/VRAM counters and runtime notes |
| 17 | `AiModelCatalogue`: 48 pinned downloads across Gemma 4/3, Qwen3, Llama 3, Phi, SmolLM2 and LFM2; custom entries; quantization, context, languages, adapter capabilities, license/source and pinned artifact metadata |
| 18 | `AiModelRecommender`: available RAM and storage reserves, runtime support, context-sensitive unknown status, and advisory compatibility reasons |
| 19 | `AiLocalModelManager.install`: explicit download authorization, streamed bounded writes, progress, cancellation, length/GGUF/SHA-256 checks and atomic manifest commit |
| 20 | Persistent restore and integrity checks, explicit load/unload, install a new revision to update, and delete; all file mutations exclude native inference |
| 21 | `benchmarkLocalModel`: model load time, generation duration, output-token throughput and process RSS before/after plus sampled peak |

## Usage

Native file management has a separate explicit import (also conditionally
exported by the main barrel). Use an app-owned models directory from
`path_provider`; create it before probing its destination volume. Own a single
manager per directory, and the same provider instance registered in `AiGateway`.

```dart
import 'dart:io';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/model_manager/native_models.dart';

final modelsDirectory = Directory('/app/support/ai-models');
await modelsDirectory.create(recursive: true);
final hardware = await detectAiHardware(storagePath: modelsDirectory.path);
final catalogue = AiModelCatalogue.candidates();
final recommendations = const AiModelRecommender().recommend(hardware, catalogue);

final offline = OfflineAiProvider(models: []);
final gateway = AiGateway(providers: [offline]);
final manager = AiLocalModelManager(directory: modelsDirectory, provider: offline);
await manager.restore(); // Rehashes stored files before registration.

// Only after the user chooses a model, reviews its license and authorizes download:
final cancel = AiCancellationToken();
final installed = await manager.install(catalogue.models.first,
  allowDownload: true, cancellationToken: cancel,
  onProgress: (received, total) => print('$received / $total'));
await manager.load(installed.model.id);
// Send ordinary AiRequest objects through gateway, selecting this model ID.
final measured = await benchmarkLocalModel(provider: offline,
  modelId: installed.model.id, prompt: 'Aaj ka din kaise plan karun?');
await manager.unload();
// install() with the same ID and a new verified artifact updates the model.
await manager.delete(installed.model.id);
manager.close(); // Wait for outstanding manager work first.
await offline.dispose();
```

Custom catalogue entries accept an `AiModelArtifact` with an HTTPS URL, exact
byte length, SHA-256 and revision obtained from a trusted publisher manifest.
Unverified candidates cannot be installed. Never take integrity metadata from an
AI response. Downloads permit only explicit HTTPS redirect hosts, with a maximum
of five redirects. Use a dedicated Dio instance if injecting one for testing;
production defaults have no credentials or logging. Provider credentials are not
used for downloads. Interrupted downloads restart from zero; there is no
background/resume service yet.

The built-in catalogue contains 48 single-file GGUF downloads, including Q4 and
Q8 variants where available. Each artifact is pinned to its publisher repository
revision, LFS SHA-256 and exact length (metadata verified 2026-11-17). See
`lib/ai/model_manager/model_catalogue_entries.dart` for URLs and provenance.
Vision projectors, draft models and LiteRT-LM files are excluded because the
current installation and inference adapter handles text GGUF models.

Settings → AI settings → Local model manager lists all catalogue entries on
both desktop and mobile. Resource and runtime recommendations are advisory:
low RAM, low storage and a negative compatibility estimate do not disable
Download, Load or Benchmark. Size, checksum and GGUF verification still apply.
Installed models have Use model, Load, Unload, Benchmark and Delete controls;
Delete asks for confirmation and releases the engine before removing files.
The original planning-only saved catalogue upgrades while preserving custom
entries and provider settings. Subsequent saved catalogue edits are respected.

Estimates apply at 4096 context tokens and are engineering starting points,
not measured model requirements. Adapter vision/tool support remains false.

## Storage and lifecycle

Files are content-addressed by model ID and hash. The JSON manifest names the
current revision; it contains no arbitrary file path. A complete new file and
manifest are staged before replacement. Failed updates keep the old registration
and manifest. Old files are removed after commit. A process crash may leave an
unreferenced file or `.part` file; neither is restored as an installed model.
The dedicated directory should be private to the app and one manager owner.

The provider rejects concurrent inference/maintenance instead of freeing a model
while native code uses it. Maintenance unloads the current engine even when it
changes another installed model. Deleting a damaged model remains possible.
A checksum-verified GGUF is still subject to native runtime loading validation;
the header check alone is not a GGUF parser or inference compatibility test.

## Hardware and benchmark limits

Linux/Android use local `/proc` counters; Linux additionally probes `df`, `lspci`
and `nvidia-smi` when present. macOS uses `sysctl`, `vm_stat`, `df` and display
information. Windows uses PowerShell/CIM and destination-volume free storage.
Missing commands/counters produce unknown values, never invented measurements.
Commands use argument lists and bounded execution times.

Android adds ActivityManager/StatFs counters through `dayark/ai_hardware`. iOS
uses physical memory, available allocation budget, filesystem space and Metal
device name through the same channel. iOS allocation budget is not equivalent to
system-wide free RAM. GPU VRAM remains unknown for shared-memory GPUs and where
reliable counters are unavailable. Native hooks bundle CPU/Vulkan on Android,
Linux and Windows, plus CUDA on x64 desktops. Apple uses the runtime's combined
CPU/Metal build. Model loading requests 8 GPU layers on desktop and 4 on mobile;
Android explicitly prefers Vulkan. Failed accelerated loads retry once on CPU
with the same context size; cancellation prevents that retry. Driver/backend
availability can also cause the runtime to resolve a load to CPU directly.
A missing mobile plugin leaves
measurements unknown. Web reports local GGUF inference unsupported.

Known x86 AVX2 absence produces a negative recommendation for this runtime; it
does not block downloads or load attempts. A compatible custom native build may
still be required on older CPUs. Unknown runtime
compatibility or memory/storage yields an unknown fit; confirmed measured counters
plus a compatible runtime can yield a candidate. Different context sizes require
new measurements rather than an invented KV-cache estimate. RAM reserves default
to 2 GiB and disk reserves to 1 GiB. Actual loading is the final compatibility
check. The existing Apple deployment-target/runtime minimum mismatch documented
in `lib/ai/README.md` still needs release validation.

Throughput uses reported native output tokens divided by the complete generation
time, including prompt evaluation. Missing token usage produces no throughput
estimate. RSS is process-wide (includes Flutter/other work), with a 25 ms sampled
peak that may miss short spikes; it is not isolated model allocation or VRAM.
Benchmark prompts can be supplied in English, Urdu or Roman Urdu. Cancellation
and native errors propagate; the model stays loaded for subsequent chat.

## Verification

```sh
flutter test --no-pub
dart analyze lib/ai test/ai tool/ai
dart run tool/ai/inspect_local_models.dart /existing/model/destination
# Optional real inference benchmark, using an already installed GGUF:
dart run tool/ai/inspect_local_models.dart /existing/model/destination /path/model.gguf
```

Tests cover resource fit/unknowns, native channel routing, verified installation,
updates and failed updates, a new owner's restore, unload/deletion, corruption,
consent, redirects, size/hash/header failures, cancellation, engine exclusivity,
and benchmark metrics. Synthetic adapter tests exercise failure logic, and a
real loopback HTTP server exercises Dio streaming and redirect rejection; no
publisher inference or multi-gigabyte model download is involved. Existing
Postman provider simulations cover provider APIs rather than model file hosting
and were not changed or rerun for this part.

On this Linux host the manual inspection correctly reports an NVIDIA GPU with
unknown VRAM and an Intel Xeon E5-1650 without AVX2. The current native backend
cannot benchmark inference here. Android/iOS channel implementations and Windows/
macOS probes require device/platform build validation; a mocked channel test does
not establish native packaging compatibility. GPU modules are now enabled in configuration; real GPU inference on these
devices remains unverified.

Validation on 2026-11-16: all 66 Flutter tests passed, scoped static analysis
reported no issues, `git diff --check` passed, and the local hardware inspection
command completed successfully. No new package dependencies were required.

Update 2026-11-17: added advisory download controls, expanded verified downloads,
catalogue migration and partial GPU loading with CPU fallback. Regression tests
exercise GPU load success, CPU fallback, cancellation, failed loads, negative
hardware estimates, download consent and installed-model deletion using fakes.
These tests do not establish device-specific GPU or model compatibility.
