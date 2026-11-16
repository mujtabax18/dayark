# Part 5 — Chat system (steps 29–39)

Open **AI Chat** from the desktop sidebar, **More → AI Chat**, or
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
| 39 | Explicit opt-in, manual conversation sync with currently paired DayArk devices using the existing pinned HTTPS listener and authentication |

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

Enable **Chat sync (paired devices)** on both devices and mark individual
conversations **Share with paired devices** from their menu, then press **Sync
shared chats now**. New conversations are private by default. This does not
use provider APIs, cloud storage or API keys. It reuses Device Sync enrollment,
non-revoked device tokens (including existing rotation grace), certificate pins
and HTTPS on TCP 39393. Older devices without the chat endpoint cannot exchange
chats and are reported as unavailable for this operation. There is no automatic
chat synchronization timer in this part.

Snapshots are versioned, bounded to 32 MiB / 1000 shared conversations, and omit
device-local profile IDs. The receiving device uses its own selected profile.
Per-replica vector clocks distinguish old snapshots from concurrent offline
edits. Concurrent edits converge deterministically and preserve the losing
version as a conflict copy. Concurrent deletion takes precedence; tombstones
contain no message/attachment content and prevent stale snapshots from reviving
a deleted conversation. Stopping sharing prevents further exchange of that
local conversation; it does not erase copies previously shared to other devices.

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
