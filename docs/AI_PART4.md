# Part 4 — AI settings and local model management (steps 22–28)

Open **Settings → AI settings**. Two entries at the top open:

- **Local model manager**: device hardware, recommendations, downloadable models,
  installed models, download progress/cancellation, load/unload, benchmark,
  updates and deletion. “Use model” returns the installed selection to settings;
  save the profile to activate it. Choosing a local model from an online profile
  creates a new offline draft and preserves the existing online profile.
- **Provider and model defaults**: update model choices, default endpoints,
  temperature and token presets. Offline defaults also expose an advanced,
  validated catalogue editor for adding/updating pinned GGUF artifacts. Changes
  prefill future profiles; saved profiles are changed only by editing and saving.

The main screen uses model/language dropdowns, a temperature slider, token
presets and populated endpoints. Custom IDs and profile URL overrides remain
under Advanced profile configuration. Instructions, profile names and credentials
are editable. Compatible APIs have no universal model ID; their local-server
example must be discovered or changed for the user's actual endpoint.

| Step | Implementation |
| --- | --- |
| 22 | Saved profiles for all six provider kinds; populated model pickers; paginated discovery adds selectable IDs; connection checks use the existing gateway |
| 23 | Profile-scoped FlutterSecureStorage credentials; masked input; blank preserves existing keys; explicit removal/deletion; changed destinations never reuse an old key |
| 24 | Shared generation controls with numeric validation, concrete defaults, custom presets and output/context consistency checks |
| 25 | Custom instructions remain beneath protected DayArk instructions |
| 26 | Automatic, English, Urdu and Roman Urdu input/output choices; custom output language and preserved legacy custom input preferences |
| 27 | Controls follow adapter/model capabilities; unsupported parameters omitted; model temperature ceilings respected |
| 28 | Online processing and private-context sharing are separately opt-in; gateway enforces permissions before remote calls |

## Local models

A shared lazy session owns the Part 3 manager and offline provider, using the
app-support `ai-models` directory. Settings restores verified installations when
an offline profile is opened; switching to offline or opening the manager can
also initialize it. Nothing starts during ordinary app startup. Leaving Settings
does not dispose an engine needed by chat. Configured offline sends automatically
reuse the same session unless the caller explicitly supplies an existing provider.
Concurrent maintenance/inference remains guarded by the Part 3 provider.

The catalogue initially offers the existing pinned Gemma 4 E4B Q4_0 artifact.
Other Gemma 4 sizes are visible candidates without verified download artifacts;
their Download buttons are disabled. Unsupported runtimes or insufficient
measured RAM/storage also disable downloading. Unknown compatibility stays
unknown and requires a successful load test. Device, quantization, language,
license, context and resource information are visible before downloading.

Each download has a review dialog with publisher, license, exact bytes, revision
and SHA-256. The user's confirmation authorizes only that artifact download;
it does not authorize sending chats online. Part 3 performs bounded streaming,
redirect checks, checksum verification and atomic installation. The UI reports
progress and supports cancellation; it blocks leaving during an active operation.
Changing the pinned hash or revision in the defaults screen enables Update for
an installed catalogue entry. Delete requires confirmation. Benchmark results
include output throughput, load time and process-wide sampled peak RAM.

The advanced catalogue editor accepts only validated metadata. Use exact
publisher-provided hashes, lengths and revisions; metadata is not fetched from
model-generated text. Saving defaults does not download anything. No automatic
publisher refresh, background download or resume service is introduced.

## Built-in choices and provenance

Reviewed on 2026-11-16. These are starting choices, not guarantees of account
entitlement or live availability. Discover models checks the selected provider.
No extra tool/vision support is inferred from model names; the existing adapters
continue to define supported request capabilities. Current Claude families that
reject sampling overrides hide temperature and omit it from requests; see the
[Sonnet migration guide](https://platform.claude.com/docs/en/models/sonnet-5-5/migration-guide).

- OpenAI: GPT-6.1 Sol, GPT-6 Sol, GPT-5.6 Sol and GPT-5.4 mini;
  [GPT-6.1 API documentation](https://developers.openai.com/api/docs/models/gpt-6.1-sol.md)
  and [model catalogue](https://developers.openai.com/api/docs/models/all).
- Gemini: Gemini 4 Hydrogen, Argon and Carbon, plus Gemini 3.8 Flash;
  [Google's model catalogue](https://aistudio.google.com/docs/models).
- Anthropic: Claude Sonnet, Haiku and Opus 5.5, plus Fable 5.2;
  [Claude model overview](https://platform.claude.com/docs/en/models/overview).
- Ollama: Gemma 4 E4B, 12B, 26B and 31B tags;
  [Ollama publisher catalogue](https://ollama.com/library/gemma4).
- Embedded GGUF: [ggml-org Gemma 4 E4B](https://huggingface.co/ggml-org/gemma-4-E4B-it-GGUF);
  pinned artifact metadata and runtime limits remain documented in [Part 3](AI_PART3.md).

## Persistence, privacy and integration

Ordinary preferences, editable defaults and OS credentials are separate stores.
Defaults contain no API keys and do not enable network access. Malformed defaults
fall back visibly to built-in choices and can be repaired in the defaults screen.
Malformed profile/privacy preferences fail closed. Provider URLs reject embedded
credentials, query strings and fragments; HTTP is limited to loopback addresses.

```dart
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/settings/ai_flutter_settings.dart';

final store = AiSettingsStore(preferences: await SharedPreferences.getInstance());
final response = await AiConfiguredAssistant(store).send(
  message: AiMessage(role: AiRole.user, text: 'Salam'),
  history: previousMessages,
  containsPrivateContext: false,
);
```

Callers retain conversation history across provider switches. Future memory/RAG
callers must mark private retrieved context with `containsPrivateContext: true`.
That requires both online authorization flags. These are application-owned
permissions, never values parsed from model output or custom instructions.
Self-hosted servers count as remote processing. The Flutter settings barrel is
separate from `ai.dart`, preserving native Dart CLI tools.

## Verification and limits

```sh
flutter test --no-pub
# Static checks:
dart analyze lib/ai test/ai tool/ai
# Separate real HTTP/UI integration against local synthetic stand-ins:
postman simulation run postman/simulations/ai-providers/ai-providers.sim.yaml --port 4017 --no-history --output ndjson
flutter test --no-pub --dart-define=DAYARK_AI_SIMULATION=true test/ai/ai_settings_simulation_test.dart
dart run tool/ai/verify_provider_simulation.dart
```

Tests cover defaults persistence, invalid pinned metadata, secret separation,
privacy permissions, capability-aware settings, download confirmation/cancellation,
hardware/runtime restrictions, lifecycle controls, offline profile selection,
and a native UI session using the real Part 3 manager with a tiny synthetic file
and injected runtime. The separate simulation test drives the actual settings UI
through discovery, model selection, connection testing and saved choices for
all five remote provider kinds. OS credentials are mocked; no paid requests or
multi-gigabyte model downloads are made during automated verification.

Live account/model access and native inference require device validation.
This Linux host lacks AVX2, so the current pinned runtime cannot load real models
here; the UI reports that restriction. Web shows an unsupported local manager.
Existing Apple deployment target/runtime minimum limits from Part 3 remain;
this UI work does not establish Apple packaging compatibility. No persistent
chat database, voice, RAG or DayArk record access is added.

Validation on 2026-11-17: all 79 Flutter tests passed, the separate five-provider
settings UI simulation passed, the existing adapter simulation passed, scoped
analysis reported no issues, and `git diff --check` passed. The simulation request
log showed successful discovery/connection GETs and generation POSTs for every
provider. Live provider entitlement and native device inference were not tested.
