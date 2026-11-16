# Part 4 — Complete AI settings (steps 22–28)

Open **Settings → AI settings**. Create named offline, OpenAI, Gemini,
Anthropic, Ollama or compatible API profiles, enter the model ID, and save to
select that profile. Existing profiles can be edited, selected or deleted.
Online profiles offer connection tests and model discovery through the existing
gateway. Discovery shows the first provider page and indicates additional pages.
The screen performs no network requests until an authorized test/discovery action.

| Step | Implementation |
| --- | --- |
| 22 | Versioned, validated provider profiles and selected profile in SharedPreferences; adapter factory; connection testing and model discovery |
| 23 | Profile-scoped FlutterSecureStorage credentials, resolved at request time; masked input; blank preserves saved credentials; explicit removal and profile deletion; destination changes clear old keys |
| 24 | Persisted temperature, output and context limits; positive/finite validation; output cannot exceed configured context |
| 25 | Saved custom instructions composed beneath protected DayArk instructions |
| 26 | Automatic or custom input language; automatic, English, Urdu, Roman Urdu or custom output language |
| 27 | Controls follow existing adapter/model capabilities; unsupported parameters omitted and temperature bounded when applying saved settings |
| 28 | Online processing and private-context online sharing are independently opt-in; gateway enforces both before invoking a remote provider |

## Integration

`AiSettingsStore` separates ordinary JSON preferences from the OS credential
store. Credentials are neither exported with profiles nor displayed on reload.
Storage failures surface to the user; malformed preferences fail closed rather
than silently enabling remote access. URLs reject embedded authentication,
query strings and fragments. HTTP is limited to localhost. Self-hosted servers
are remote processing, including local Ollama endpoints outside the app process.

`AiConfiguredAssistant` loads the selected profile and saved settings for each
send and uses the existing `AiOrchestrator` / `AiGateway`. The caller retains
history across model switches. Offline calls reuse the model manager's supplied
provider (including its actual provider ID) and installed model IDs; the settings
screen does not create, download or load another native engine.

```dart
import 'package:metersystem/ai/settings/ai_flutter_settings.dart';

final store = AiSettingsStore(
  preferences: await SharedPreferences.getInstance(),
);
final response = await AiConfiguredAssistant(store).send(
  message: AiMessage(role: AiRole.user, text: 'Salam'),
  history: previousMessages,
  offline: existingModelManagerProvider,
  containsPrivateContext: false,
);
```

Future memory/RAG callers must mark private retrieved context with
`containsPrivateContext: true`. Online requests with that flag require both
`allowRemoteProcessing` and `allowPrivateContextOnline`; raw gateway callers
continue to default to no remote authorization. These flags are application-owned
permissions, never values parsed from model output or custom instructions.
The stored privacy choices authorize subsequent configured sends until revoked.
No RAG, voice, chat database or application-record access is introduced here.

The capability controls use the adapters' conservative metadata, including
reasoning-model temperature restrictions. They do not assert newly discovered
vision/tool support or infer reliable model context limits from model names.

## Verification and limits

`test/ai/ai_settings_test.dart` checks persistence, credential separation/removal,
URL validation, malformed selections, capability filtering, protected prompts,
the private-context permission matrix, reuse of the offline provider with a
separate profile ID, and settings-screen persistence/capability visibility.
Credentials are mocked for automated tests. Actual OS keychain integration and
cross-platform visual/native packaging need device validation; no real provider
keys or paid generation are used by these tests. Existing dependencies are reused.

The Flutter settings barrel is separate from `ai.dart`, keeping the existing
pure Dart inspection/provider CLI tools usable without `dart:ui`.

Validation on 2026-11-16: all 72 Flutter tests passed; the six settings tests
also passed after the final credential-destination assertion and Flutter barrel
separation. Scoped analysis and `git diff --check` passed. The existing local
hardware inspection CLI produced its hardware/recommendation report successfully.
