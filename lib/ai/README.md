# DayArk AI — roadmap Parts 1–5

Import `package:metersystem/ai/ai.dart`. All providers share `AiGateway` and
`AiOrchestrator`. No provider is registered or activated during app startup.
AI settings are available from Settings. Existing application records, schema, sync and backup paths are unchanged.
See `docs/AI_PART4.md` for saved profiles, secure credentials and privacy integration.

## Implemented scope

| Roadmap step | Implementation |
| --- | --- |
| 1–6 | Immutable shared messages/settings/attachments, provider interface, gateway, prompt composition, standard errors, bounded retries, timeouts and cancellation |
| 7 | `OfflineAiProvider`: embedded CPU llama.cpp via pinned `llamadart`, explicitly configured local GGUF files, lazy loading, safe exclusive engine ownership and disposal |
| 8 | `OpenAiProvider`: official Chat Completions API, bearer credentials, modern output-token limit and response usage |
| 9 | `GeminiProvider`: GenerateContent, API-key header, separate system instructions and model-role history |
| 10 | `AnthropicProvider`: Messages API, API-key/version headers, required output limit and merged adjacent turns |
| 11 | `OllamaProvider`: custom API base URL, optional bearer authentication and runtime options |
| 12 | `CompatibleApiProvider`: custom Chat Completions base URL, optional key and selectable output-token field |
| 13 | `AiGateway.testConnection`: safe status/error result, no chat data or paid generation; offline actually loads the model |
| 14 | `AiGateway.listModels`: immutable provider model pages; Gemini/Anthropic cursors, Gemini generation-method filtering, Ollama tags and configured local files |
| 15 | Per-request model/provider selection with the same supplied conversation history |

Part 1's `AiProvider` contract remains source-compatible. The optional
`AiManagedProvider` interface adds discovery and connection checks. HTTP adapters
use existing Dio; only `llamadart` and its `dinja` dependency were added to the
lockfile. Existing locked package versions were retained. CPU-only native hook
configuration avoids enabling untested GPU backends or unrelated runtimes.

## Usage

```dart
final local = OfflineAiProvider(models: [
  AiLocalModel(id: 'my-local-model', path: '/absolute/path/to/model.gguf'),
]);
final online = OpenAiProvider(
  // Supply a loader from your secure credential store. No credential persistence
  // or plaintext settings file is introduced by these adapters.
  credentials: () => secureStorage.read(key: 'dayark.openai.apiKey'),
);
final gateway = AiGateway(providers: [local, online]);
final assistant = AiOrchestrator(gateway: gateway);
final cancel = AiCancellationToken();
final reply = await assistant.send(
  selection: AiModelSelection(providerId: 'offline', modelId: 'my-local-model'),
  message: AiMessage(role: AiRole.user, text: 'Hello'),
  history: previousMessages,
  cancellationToken: cancel,
);
// Append the user message and reply.message only after success.
// Pass the same history with another selection to switch models/providers.
```

Each online profile may have a distinct provider `id`. Provide the full API base
prefix: OpenAI/compatible `/v1/`, Gemini `/v1beta/`, Anthropic `/v1/`, Ollama
`/api/`. Prefixes are preserved, and a missing trailing slash is normalized.
Close HTTP providers with `close()` and await `local.dispose()` when their owner
is destroyed. Do not share one native runtime between offline provider instances.

Discovery and connection checks go through the same gateway:

```dart
final page = await gateway.listModels(
  providerId: 'openai', allowRemoteProcessing: userAuthorizedRemoteAccess,
);
final status = await gateway.testConnection(
  providerId: 'openai', modelId: selectedModelId,
  allowRemoteProcessing: userAuthorizedRemoteAccess,
);
```

Pass `page.nextCursor` as `cursor` for the next page. A connection test without a
model verifies endpoint authentication/reachability; with a model it also checks
catalog membership across pages. Neither proves generation permissions, quota,
or model-specific capabilities. Some compatible endpoints may omit discovery;
they return a standard error while explicit model-ID generation remains usable.
Local discovery lists configured files, and connection testing verifies loading.

## Privacy, capabilities and lifecycle

- Remote processing requires explicit per-request authorization, including for
  custom/self-hosted endpoints. Obtain this from the user, never model output.
- Credential loaders run for every operation. Secrets, raw HTTP error bodies and
  provider exceptions are never included in standard errors. No HTTP logging
  interceptor is installed. Redirects are disabled to prevent key forwarding.
- HTTPS is required for remote URLs; loopback HTTP is accepted for local servers.
  Unencrypted LAN/custom HTTP requires explicit `allowInsecureHttp: true`.
  URLs containing credentials, query strings or fragments are rejected.
- Part 5 adds streaming and inline attachments for capable models, with UTF-8
  text documents also supported offline. Unsupported settings and attachments
  fail explicitly. Shared `AiSettings` values are translated per protocol; no provider sees
  another provider's wire format. Use `modelCapabilities` overrides for specific
  model restrictions; discovery catalogs do not reliably expose all capabilities.
- Unknown provider errors are sanitized. Only transient mapped failures retry,
  with bounded exponential delays and per-attempt deadlines. Request retries
  can incur additional provider inference charges after ambiguous timeouts.
  Discovery/connection probes use one bounded operation, without automatic retries.
- Cancellation aborts Dio requests and native generation. Scoped listeners are
  removed after completion. Model loading may finish before cancellation can
  settle; the provider stays busy until it does and never starts generation for
  that cancelled load. Disposal waits before freeing native memory.
- Prompt instructions describe the chat-only boundary. Actual protection comes
  from having no application-data or action APIs in this module. User-supplied
  system-role history is rejected. The orchestrator owns no mutable chat state.

Part 3 adds hardware reports, catalogue recommendations, verified model downloads,
model lifecycle management and benchmarks. See [Part 3](../../docs/AI_PART3.md)
for usage and platform limits. Part 4 adds Settings → AI settings, including
local model management, populated model pickers, editable provider/catalogue
defaults, secure credentials and privacy controls. See [Part 4](../../docs/AI_PART4.md).
Part 5 adds persistent AI Chat, streaming, message operations, folders/search,
attachments, export and optional paired-device sync. See [Part 5](../../docs/AI_PART5.md).
Voice, memory, RAG and DayArk record access remain later parts.

## Verification

```sh
flutter test --no-pub
dart analyze lib/ai test/ai tool/ai

# Local-only Postman stand-ins; no vendor credentials or paid calls.
postman simulation run postman/simulations/ai-providers/ai-providers.sim.yaml --port 4017 --no-history --output ndjson
# In another terminal:
dart run tool/ai/verify_provider_simulation.dart

# Real embedded inference, using an already-installed GGUF (never downloads):
dart run tool/ai/verify_offline.dart /absolute/path/to/instruct.gguf
```

The Postman fixtures are synthetic, derived from the published contracts below.
Their connection, discovery, generation, Unicode, usage and history-switching
paths are exercised by the script. Real loopback HTTP tests additionally cover
serialization, auth rotation, pagination, malformed replies, redirects, retries,
privacy, cancellation and timeouts. Offline unit tests inject a runtime to test
load selection, exclusivity, cancellation and disposal deterministically.

Validation on 2026-11-16: all 54 tests passed, scoped static analysis reported
no issues, and all five HTTP adapters passed the local Postman simulation.

No live provider credentials were used. The Linux native smoke test was attempted with a checksum-verified
SmolLM2-135M-Instruct Q2_K GGUF. This host's Xeon E5-1650 lacks AVX2; the pinned
CPU module reports compatibility score 0 and refuses to register, so real local
generation could not be established here. Unit tests cover the offline adapter
with an injected runtime. A compatible CPU/runtime build is required for the
manual inference check to pass. Other operating systems and acceleration also
require their own native validation.
The GGUF used for the smoke test is temporary and is not bundled in DayArk.
Apple and web runtime packaging is not validated by Linux tests. The pinned
runtime's published minimums are iOS 16.4/macOS 14, newer than DayArk's current
15/12 targets; those application targets have not been raised. Apple release
packaging and native minimum compatibility must be resolved before enabling
local inference on those platforms. Web returns an explicit unsupported error
for local GGUF inference. HTTP adapters remain available through the gateway.

## Contract references

Reviewed for this implementation on 2026-11-16:

- [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)
  and [models](https://developers.openai.com/api/reference/resources/models/methods/list).
- [Gemini generation](https://aistudio.google.com/api-reference/generate-content)
  and [models](https://aistudio.google.com/api-reference/models).
- [Anthropic Messages](https://platform.claude.com/docs/en/api/messages)
  and [models](https://platform.claude.com/docs/en/api/models/list).
- [Ollama chat](https://docs.ollama.com/api/chat) and
  [tags](https://docs.ollama.com/api/tags).
- [llamadart 0.19.11](https://pub.dev/packages/llamadart/versions/0.19.11)
  and its installed public Dart source for model loading, generation and cleanup.

Orbit supplied supplementary OpenAI/Anthropic/Ollama integration details.
Published-owner mock search was skipped because Postman was signed out. This
CLI version supports simulation but has no `postman status` command; `postman
whoami` confirmed the unsigned session. No cloud workspace was created or changed.
