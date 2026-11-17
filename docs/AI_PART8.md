# Part 8 — Chat release acceptance

Part 8 is the Release 1 verification gate for Parts 1–7. The chat remains a standalone assistant. Application-record access and actions belong to later releases.

## Repeatable automated gate

From the repository root, with the locked dependencies already installed:

```sh
python3 tool/ai/verify_release.py
# On a Linux build host with the desktop toolchain:
python3 tool/ai/verify_release.py --linux-build
```

This runs scoped static analysis and the AI/home integration suite, optionally followed by Linux debug compilation. Each check has a log and exit code in `build/ai-release/report.json`. A failed check makes the command exit nonzero. Automated success never marks physical-device acceptance complete. No downloads, vendor credentials, paid API generation or cloud publication are part of this gate. HTTP contract tests use ephemeral loopback servers; embedded-runtime and speech unit tests use injected runtimes.

| Roadmap acceptance criterion | Automated evidence | Remaining device evidence |
| --- | --- | --- |
| Offline after installation | `ai_offline_provider_test`, `ai_model_management_test`: local loading, cancellation, integrity and lifecycle | Real installed GGUF; disable network, restart app, generate and cancel |
| Common online gateway | `ai_http_provider_test`, `ai_streaming_test`, `ai_foundation_test`: five real HTTP adapters against loopback fixtures | Authorized live accounts, quotas and model-specific behavior |
| Custom Ollama URL | HTTP tests: custom prefixes, authentication, stream protocol, settings | Real Ollama server at the intended URL, including LAN/TLS configuration |
| Model switching preserves chats | `ai_chat_screen_test`, `ai_release_acceptance_test`: saved turns, profile switch, reopen, continued generation | Change actual local/online models in a long conversation |
| Shared settings | `ai_settings_test`, `ai_model_settings_ui_test`, release integration: capabilities, persistence, language, instructions | Review chosen models' sampling and context behavior |
| Hardware recommendations | `ai_model_management_test`, `ai_mobile_hardware_test`: memory/storage tiers, uncertain and unsupported devices | Compare recommendations and measured memory with each target device |
| English, Urdu, Roman Urdu | HTTP and release integration tests preserve Unicode and history | Native quality/latency benchmark below; script transport is not a quality benchmark |
| Editable voice transcription | `ai_voice_test`: permission, cancellation, language, transcript review | Physical microphone, selected Whisper model or authorized transcription endpoint |
| Long conversation context | `ai_memory_test`: bounded context, recent turns and extractive summaries | Long real chats; verify earlier relevant details and inspect truncation limits |
| RAG with citations | Memory tests: extraction, hybrid search, source links, updates/deletion and configured assistant | Real embedding GGUF; representative documents, languages and citation relevance |
| Review/delete memory | Memory UI and index lifecycle tests | Restart after deletion; verify sources and search stay removed |
| Private online sharing | Gateway, memory and release integration: blocks before transport, including persisted answers after source deletion and remote switching | Inspect traffic while toggling both permissions on target devices |
| Supported platforms | Linux compilation plus responsive Flutter widget tests | Windows, macOS, Android, iOS builds and device runs; Linux runtime usability |

`ai_release_acceptance_test.dart` joins the saved-settings, configured-assistant, gateway, chat database and memory paths. Its multilingual fixtures verify wiring and text preservation. Its privacy case retrieves a private document, persists a cited answer, deletes the document, reopens the chat and verifies that switching to a remote profile fails with `permissionDenied` rather than attempting an HTTP connection.

## UI changes checked by this gate

Chat uses a compact model menu, the shared searchable model sheet, a bounded reading column, plain assistant messages and neutral user bubbles. The rounded composer gives text its own row, with attachments, voice and send/stop below. Sync and notification controls are in **Chat preferences**. Settings groups General, Model & connection, Personalization and Data & privacy, with section shortcuts and an always-visible Save button. Both screens inherit the application's light/dark colors.

Streaming refreshes are coalesced to display frames. Automatic following continues near the bottom and leaves older messages available while reading. The composer clears only after successful message persistence, before generation completes. Failed storage retains the draft. A new draft can be typed while the current reply streams, and remains after completion. Markdown is rendered during streaming as well as after completion. Tests cover those boundaries, model search, persistence, compact keyboard layout, edit/retry, Markdown, blocked remote images and desktop shell routing.

## Native multilingual benchmark

Use an already installed, compatible chat GGUF on the target device/host:

```sh
dart run tool/ai/benchmark_release.dart /absolute/path/model.gguf build/ai-release/language-benchmark.json
```

The tool makes only local inference calls. It records English, Urdu and Roman Urdu prompts, answers, elapsed milliseconds and available output-token counts. The first case includes cold model loading; later cases are warm. Keep the model identity/checksum, quantization, hardware, runtime version, memory, context size and network-disabled state alongside the report when comparing devices. Reports include a local model path and generated answers; review before sharing.

A reviewer must score every answer for the requested script/language, comprehensibility, relevance, factual accuracy and instruction following. Record first-load time, warm response time, peak memory, cancellation and acceptable latency for that device. Compare the same fixed prompts and settings across candidate models. The benchmark deliberately records quality review as pending; it cannot automatically certify natural-language quality.

## Physical-device sign-off

Use a separate row for each OS, device, model/runtime and app build. Record the tester, date, exact build, result and evidence path. All rows start **pending**; Linux compilation does not sign off Linux runtime behavior.

| Target | Native build | Offline chat / model switch | Voice / language quality | RAG / privacy / persistence |
| --- | --- | --- | --- | --- |
| Linux | See automated report | Pending | Pending | Pending |
| Windows | Pending | Pending | Pending | Pending |
| macOS | Pending | Pending | Pending | Pending |
| Android | Pending | Pending | Pending | Pending |
| iOS | Pending | Pending | Pending | Pending |

For each supported configuration: install a verified model, disconnect networking, cold-start and chat; switch models without losing turns; stop/retry generation; test English/Urdu/Roman Urdu; record and edit speech; retrieve a distinctive document fact and open its citation; disable/delete the source; restart and confirm persistence. Deny private-context online access, switch a chat containing a private derived answer to an online profile and confirm no content is transmitted. Then explicitly authorize both permissions and test only with approved sample content. Exercise phone keyboard, desktop resizing, light/dark theme, history search, exports and opted-in paired-device sync.

Previously documented native constraints remain relevant: the pinned CPU runtime was not usable on the earlier host without AVX2; Apple minimum-version/runtime packaging requires target validation. See `lib/ai/README.md` and Parts 3, 6 and 7. Do not mark Release 1 accepted until these device rows and model-quality checks have evidence.

## Validation on 17 November 2026

`python3 tool/ai/verify_release.py --linux-build` passed: scoped static analysis reported no issues, all 150 AI/home tests passed, and the Linux debug bundle compiled. Chat and settings desktop layouts were also inspected using local rendered previews. Native language benchmarking, physical microphone checks, live vendor accounts and the remaining OS/device matrix were not run in this session; full Release 1 acceptance remains pending those results.


## Chat navigation, organization and input recovery

AI settings has an explicit Back button: pushed screens pop normally; desktop shell and direct-route entry return to main Settings. The existing **Settings → AI settings** entry remains available.

Chat folders now have their own local metadata table, with a version-1-to-2 migration that preserves conversations. Empty folders can be created and pinned; legacy/synchronized folder assignments are also listed. New chats inherit the selected folder. Chats can be moved and pinned from their history menu, and the active chat's menu also supports moving. Folder pin metadata stays local; conversation folder assignments and chat pins continue to use existing opted-in chat sync.

Each message shows its local timestamp. Completed, failed and stopped assistant replies store elapsed generation milliseconds, including preparation inside the engine, and show response duration below the message. Existing messages without timing remain readable. Timing survives JSON storage and chat sync. Copy, edit, retry and regenerate use tooltip-labelled icons outside the bubble. Failed replies use a compact error-details icon; provisional failed output stays behind the diagnostics dialog.

TXT/Markdown convert to untrusted text. PDFs extract locally for models configured without native PDF support; scanned PDFs require OCR. Native images/PDFs remain available only where the provider's configured capabilities allow them. The composer explains these conversions and the fact that voice transcripts count toward the context budget. Input checks give the conservative UTF-8 budget and suggest a smaller input or a larger context window before creating a chat turn. This is an estimate, not model tokenizer measurement.

**Summarize in parts** is explicit and uses the selected profile through the same gateway and privacy permissions. It is available for text input when enough context remains. UTF-8-safe chunks cover the complete source; subsequent passes merge summaries rather than silently discarding remaining chunks. Cloud summary calls use a reduced output limit; local summary calls run until model completion or Stop. Summary requests disable supported thinking, exclude chat history and retrieval, and preserve private-content markers. The user sees progress, can cancel, and reviews an editable final prompt before sending. The original draft stays intact on cancellation, failure or dismissal. Limits are 64 chunks per pass and four passes; a model that fails to shorten the input produces a recovery message. Summarization quality still depends on the actual model and must be reviewed.

Added regression coverage includes folder migration/reopening, timing sync/backward compatibility, moving chats without losing messages, all Back navigation paths, PDF/TXT conversion, Unicode chunk coverage, multi-pass reduction, cancellation, failed reduction, private online blocking and opt-in prompt review. The final automated gate passed all 143 tests, clean scoped analysis and Linux compilation. A dark-theme preview of the folder list, message footers and error icon was also rendered and inspected.


## Pane-scoped dialogs and local reasoning

Summarization consent, progress and prompt review are compact dialogs within the AI chat pane. A nested navigator confines their scrim and content to that pane, and closing the pane cancels summarization. The consent and review views explicitly say: “I don’t recommend summarizing with this AI tool because it might miss important information.”

The composer separates document upload (**+**, for PDF/TXT/Markdown, including local text conversion) from image upload (shown only for recognized/configured vision models). Voice remains a separate transcription-to-text feature for selected chat profiles. Qwen3.5 image capability matches [Ollama’s published model information](https://ollama.com/library/qwen3.5); unknown models retain conservative defaults.

Pending/stopped status appears in the small neutral message footer. Exposed model thoughts render as selectable Markdown, automatically expand during generation, and persist locally with the assistant turn. They are not promoted to the answer, fed into subsequent model history or included in paired-device sync. Thinking-only completion carries a separate status flag, so a model/server that ends without a final answer leaves its thinking readable without a fabricated answer or the previous generation-limit error.

Configured local chat and local summarization ignore the shared output-token cap. Ollama receives `num_predict: -1`; the embedded llama.cpp adapter uses the runtime’s positive integer ceiling instead of the previous 1024-token default. EOS, the model/runtime’s physical context constraints and the user’s Stop control govern completion. File-size, input-context, transport and storage safeguards remain. Native llama.cpp reasoning deltas are forwarded alongside answer deltas. Live native model performance still needs target-device validation.

Validation of these refinements on 17 November 2026: all 143 AI/home tests passed, scoped analysis found no issues, and Linux debug compilation passed. Tests cover compact dialog surface bounds within a desktop chat pane, sidebar interaction during summarization, cancellation, formatted live thoughts, full thought retention beyond the former diagnostics bound, local-only reasoning persistence, thinking-only terminal responses, capability-based image controls and uncapped Ollama requests including summary overrides. Actual native model quality and device performance remain pending.

## Long-stream responsiveness

Long external Ollama streams exposed app-side work that grew with every fragment: repeated full-string snapshots, repeated Markdown parsing/layout of the entire reply and thinking, and seeking to the estimated end of variable-height lists. The streaming controller now collects every delta in buffers, publishes display snapshots at 50–200 ms intervals according to accumulated size, flushes the first content and terminal/stopped state promptly, and yields to the event loop at least every 64 events or 8 ms of receipt work. Timer-based publishing is cancelled on completion, failure and disposal. This changes display cadence rather than model output limits.

`AiResponseText` retains formatted normal layouts for small replies. Large answers and thoughts use bounded scroll areas with incrementally sealed 2048-character Markdown blocks and cached widgets for sealed prefixes. Code-fence state carries across blocks, remote images remain blocked, and the complete source remains available for copying/storage. Live text and the conversation list anchor at the newest end using reversed lists, avoiding an expensive seek that measures all earlier blocks. Following pauses while the user reads older content. Large chat payloads (64 KiB and above) are encoded/decoded with Flutter background computation, including attachment encoding and payload-size checks, so completion and reopening do not require large JSON work on the UI isolate.

`ai_stream_responsiveness_test.dart` covers 24,000 mixed answer/thinking events with concurrent timer heartbeats and bounded publication counts, 6,000 Ollama NDJSON frames through a real loopback HTTP connection and gateway, prompt cancellation of a hot producer, Unicode/code-fence preservation, megabyte-scale lazy rendering, reuse of sealed widgets and a live-tail regression that would otherwise measure 5,000 earlier Markdown image markers. The chat-screen suite also tests the actual Stop button while a large answer and thoughts are visible, then verifies the complete received text is saved and the composer becomes available again.

Validation: all 150 AI/home tests passed, scoped analysis reported no issues, and the Linux debug build succeeded. HTTP tests use a local Ollama-protocol fixture, not a live model server. Existing target-device/native-model acceptance requirements remain separate.
