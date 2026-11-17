# Part 5 — Chat system (steps 29–39)

Open **AI Chat** from Home’s **Features** cards or quick access, the desktop
**Features** sidebar, **More → AI Chat**, or
**Settings → AI Chat**. Create a provider profile in AI settings first. The chat
profile picker switches providers within the current conversation, retaining
its successful user/assistant history. Changes to the chat's selected profile do
not change the global default profile.

| Step | Implementation |
| --- | --- |
| 29 | Separate Drift/SQLite `dayark_ai_chat_v1` database; durable messages, attachment bytes, provenance, folders, settings and deletion markers |
| 30 | Responsive chat interface, desktop conversation sidebar, mobile history drawer, composer, stop control, provider picker and settings link |
| 31 | Native llama token streaming; SSE for OpenAI, compatible, Gemini and Claude; NDJSON for Ollama; shared gateway events and terminal-response validation |
| 32 | Selectable Markdown, fenced code, lists, tables, Unicode/RTL content; model-generated images never initiate network/file loads; external links require a user click and review |
| 33 | Copy, edit-and-regenerate, retry failed/stopped replies, regenerate the latest assistant turn; editing can remove attachments and replaces subsequent context |
| 34 | Rename, pin/unpin, archive/unarchive and confirm deletion |
| 35 | Folder assignment and folder filtering; parameterized title/message search; archived history view |
| 36 | Per-conversation profile selection, shared history, model provenance on replies |
| 37 | App-owned attachment bytes: PNG/JPEG/WebP, PDF, UTF-8 TXT/Markdown; capable adapters serialize inline multimodal parts; text documents also work offline |
| 38 | JSON, Markdown or plain-text export through the platform share/save sheet; JSON contains attachment bytes; text formats list attachment metadata |
| 39 | Explicit opt-in, automatic and manual conversation sync with currently paired DayArk devices using the existing pinned HTTPS listener and authentication |

## Persistence and message lifecycle

The AI database is independent of existing DayArk feature tables. Nothing in
chat searches application records or grants model-generated actions. No model
loads, network requests or AI database work happen merely by importing the
module. The database opens lazily when chat or explicitly enabled chat sync is
used. The conversation list reads lightweight headers rather than loading every
thread's binary attachments. Search runs against stored title/message text.

A user turn and a pending assistant placeholder are saved before generation.
Deltas update the UI provisionally. A complete assistant message is saved only
after the stream ends successfully with a valid terminal response. Failure or
Stop saves partial text with an explicit failed/stopped state; these assistant
fragments are excluded from future model history. Reopening a chat after a
process interruption marks pending placeholders stopped and never silently
reissues a paid request. Retry replaces the failed turn without duplicating the
user message. Editing an earlier user message replaces subsequent turns; the
edit dialog explains this and can remove attachments.

Streams pass through the same prompt manager and gateway authorization checks
as non-streaming generation. The gateway bounds inactivity and accumulated
response size. It does not automatically replay a streaming generation, avoiding
duplicate visible text or extra paid work after an interruption. Existing
non-streaming calls and providers without a streaming extension remain supported.
The offline provider retains its exclusive native-engine guard until inference
has actually settled after cancellation. Leaving chat cancels active generation
and preserves its stopped state; it does not dispose the shared model manager.

SQLite updates use optimistic revisions. If a chat changes concurrently while
a local response is generated, that response is preserved in a private local
copy rather than overwriting the received version. Database write failures are
reported instead of claiming that a response was persisted.

Conversation selection and history searches discard superseded database reads.
A delayed selection cannot reopen a conversation after **New chat**, and a
background refresh cannot replace a newly selected, edited or streaming turn.

## Attachments and privacy

The picker reads selected files in bounded chunks into app-owned data. It stores
no original local paths and never asks adapters to fetch arbitrary attachment
URIs. Limits: eight files per user turn, 8 MiB per file, 16 MiB of attachment data
per request, and 256 KiB per UTF-8 text document. Conversations are bounded at
24 MiB of stored JSON and 2000 messages; starting another chat is required beyond
that boundary. Input text and generated response text have separate 4 MiB bounds.

TXT/Markdown contents are identified as untrusted document material in user
messages. PNG/JPEG/WebP and PDFs are sent inline only to recognized capable
models (or explicitly configured adapter capability overrides). Known supported
OpenAI/Gemini/Claude models accept images/PDFs; the configured Gemma 4 Ollama
adapter accepts images. The embedded CPU runtime and unknown compatible-model
configurations remain text only. Unsupported attachments produce an actionable
error instead of being silently dropped. A user can switch to a capable profile
or edit the source message to remove an attachment.

The profile caption discloses online processing. Stored online authorization
from Part 4 is still required before any request leaves the device, including
its history and attachments. Credentials, custom system instructions and
provider settings are never included in conversation sync. Markdown rendering
uses a non-fetching image builder, safe external-link schemes and a confirmation
dialog. JSON exports intentionally include private conversation and attachment
content; exporting is a user action. Existing application backup/restore does
not automatically include the separate AI database; use conversation exports.

## Optional paired-device sync

Enable **Automatic paired-device sync** on both devices. All AI conversations
then follow the existing authenticated Local Device Sync cycle (including its
roughly 15-second active-app checks); **Sync now** remains available for an
immediate exchange. Before this global control is enabled conversations remain
local. This does not use provider APIs, cloud storage or API keys. It reuses
Device Sync enrollment,
non-revoked device tokens (including existing rotation grace), certificate pins
and HTTPS on TCP 39393. Older devices without the chat endpoint cannot exchange
chats and are reported as unavailable for this operation.

Snapshots are versioned, bounded to 32 MiB / 1000 shared conversations, and omit
device-local profile IDs. The receiving device uses its own selected profile.
Per-replica vector clocks distinguish old snapshots from concurrent offline
edits. Concurrent edits converge deterministically and preserve the losing
version as a conflict copy. Concurrent deletion takes precedence; tombstones
contain no message/attachment content and prevent stale snapshots from reviving
a deleted conversation. Turning chat sync off prevents further exchange; it
does not erase copies previously synchronized to other paired devices.

## Failure diagnostics and notifications

A failed provider turn shows a compact error card instead of rendering partial
provider output as a normal chat reply. **View thinking and response** opens a
copyable dialog containing bounded model-thinking text when the provider exposes
it, partial visible output, elapsed time, finish reason and token counts. These
diagnostics never become conversation context and are removed from sync
snapshots. Thinking can contain sensitive prompt-derived text, so it is shown
only after this explicit action.

**Reply-ready notifications** are enabled by default and use local OS
notifications when a response finishes while DayArk is not visible. Notification
text never includes prompt or response content. The switch is stored only in the
AI chat database.

On desktop, AI Chat, AI Settings, model management and their pushed detail
screens use the workspace pane to the right of the persistent DayArk sidebar.

The sync contract is in
[ai-chat-sync.openapi.yaml](../postman/contracts/ai-chat-sync.openapi.yaml).
Malformed batches are validated before import; writes are atomic. Endpoint
errors never return raw provider bodies, pairing tokens or database exceptions.

## Integration

`AiChatController` owns message lifecycle and uses an injectable stream function
for testing. Production calls `AiConfiguredAssistant.stream(profileId: ...)`,
which loads saved settings and reuses the existing shared offline provider or
HTTP adapters. `AiGateway.stream` is the sole provider-independent streaming
channel. `AiStreamingProvider` and `AiStreamingOfflineRuntime` are optional
extensions, preserving existing adapters/test runtimes. The core `ai.dart`
barrel remains usable by native Dart CLI tools; Flutter chat is separately
exported by `ai/chat/ai_chat.dart`.

Primary contracts reviewed:

- [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)
- [Claude streaming](https://platform.claude.com/docs/en/build-with-claude/streaming)
  and [PDF input](https://platform.claude.com/docs/en/build-with-claude/pdf-support)
- [Gemini generation and streaming](https://aistudio.google.com/api-reference/generate-content)
- [Ollama streaming](https://docs.ollama.com/api/streaming)
- [flutter_markdown_plus 1.0.12](https://pub.dev/packages/flutter_markdown_plus)

## Verification

```sh
flutter test --no-pub
dart analyze lib/ai test/ai tool/ai
postman simulation run postman/simulations/ai-providers/ai-providers.sim.yaml --port 4018 --no-history --output ndjson
dart run tool/ai/verify_provider_simulation.dart http://127.0.0.1:4018/
```

Tests exercise file-backed SQLite reopen, search/folders/archive/pin/deletion,
exports, revision conflicts, cross-replica convergence, tombstones, global and
per-chat consent, failed/stopped/retried/edited turns and crash recovery. Real
loopback HTTP tests split UTF-8 and SSE/NDJSON at arbitrary byte boundaries and
cover incomplete streams, safe errors, inactivity/cancellation, inline images,
PDF serialization and local text documents. Desktop/mobile widget tests cover
Markdown/code, safe images, copy, edit/regeneration, profile switching, rename,
opt-in sync and the software-keyboard layout. The sync exchange is tested over
real pinned loopback TLS with simulated enrolled/revoked peer authorization.
Existing provider mocks now stream too; the actual adapter verification script
checks streaming and non-streaming responses through all five stand-ins.

No vendor credentials, paid generation, multi-gigabyte model downloads or
external publishing are used for verification. The local engine cannot run real
inference on this host's non-AVX2 CPU; its provider/runtime lifecycle is tested
with injected runtimes. Multi-device hardware behavior and OS picker/share/native
packaging still require device validation. This part does not add voice, RAG,
long-term memory, application knowledge or application actions.

Validation on 2026-11-17: all 101 Flutter tests passed. All five HTTP providers
also passed the local Postman streaming/non-streaming simulation; request logs
confirmed the actual adapter paths. Scoped AI/test/tool and new sync-handler
analysis and `git diff --check` passed. Live providers and physical paired devices
were not used.


## Ollama cold-start and thinking fix — 2026-11-17

Ollama and embedded local inference now allow five minutes for the first stream
event and two minutes of inactivity between events. Other providers retain their
existing default timeout. The HTTP stream's receive timeout allows the same
cold-start window; the gateway still enforces its shorter per-provider idle
limit and cancellation. Stop remains available while waiting for model loading.

Ollama chat explicitly sends `think: false` by default. Qwen 3.5 enables thinking
by default on the tested server, which could consume the output budget while
DayArk was waiting for visible answer text. Supported Ollama reasoning models
now expose **AI settings → Behavior → Enable model thinking**. Enabling it is
opt-in; it can increase response latency and may require a larger output budget.
Thinking-only Ollama frames emit activity events that keep a working stream
alive without showing or storing reasoning text. Pending chat bubbles indicate
that the model is being awaited or is working.

AI Chat is registered as feature ID 15, so it participates in the normal Home
feature ordering, feature cards, desktop Features list and quick-access
customization. Existing saved shortcut lists receive the new feature once; a
later user choice to hide it is respected. The older Family Trees shortcut
migration remains supported. No new application database schema is required.

Regression checks cover startup versus idle timeouts, thinking-frame activity
without reasoning leakage, default/explicit Ollama thinking requests, saved
thinking controls, feature navigation and one-time shortcut migration.

```sh
dart run tool/ai/verify_ollama.dart qwen3.5:2b
```

The local-only command uses the real gateway, protected prompts and Ollama
adapter with a synthetic greeting. On this Linux host the installed Qwen 3.5
2B model returned a complete answer in approximately 17 seconds with thinking
disabled. This is an observed smoke test, not a latency guarantee. Ollama's
service, model files and global configuration were not changed.

Contract: [Ollama thinking controls](https://docs.ollama.com/capabilities/thinking).

Chat concurrency validation on 2026-11-17: all 120 Flutter tests passed;
`dart analyze lib/ai test/ai tool/ai` reported no issues. Four additional
regressions cover delayed selection after New chat, out-of-order selections,
refresh during streaming, and out-of-order history searches. This verification
used injected streams and local databases; live providers and physical paired
devices were not exercised.

Validation for this fix: all 108 Flutter tests passed, including seven new
regressions for startup/activity timing, thinking controls, and Home feature
registration/migration/navigation. The five-provider local simulation passed.
Scoped AI/test/tool analysis reported no issues; the broader navigation/settings
check only reports existing filename-style notices on legacy CamelCase files.
