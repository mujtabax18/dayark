# AI workspace implementation audit

The existing module uses a shared offline provider, llamadart 0.19.11, Dio HTTP adapters, Drift conversation records with revision/vector-clock synchronization, and optional local retrieval. Existing download, hardware/GGUF detection, document extraction, voice, benchmark and Markdown services are retained.

## Baseline findings

- Configured chat deliberately removed offline/Ollama output limits; Ollama always sent `num_predict: -1`. The settings UI also discarded offline output limits.
- Exact native template context fitting trimmed history only at full context, leaving no guaranteed output reservation.
- Offline `create` inherited thinking enabled, while capabilities hid that option.
- Native loading reused the model path/context but ignored changed GPU layers.
- Native telemetry sampled process RSS for every chunk. Existing throughput includes prompt evaluation and must not be called decode-only speed.
- Streaming already batches 50–200 ms, yields for input, and uses lazy reverse lists with incremental Markdown. Preserve these optimizations.
- Conversation records already support pinning, folders, archives, export, edit/retry and synchronization. Reuse these records rather than creating another chat database.

## Validation boundaries

No portable timing claim can be made from widget tests or synthetic providers. Real cold/warm model, CPU/GPU, thermal, battery, native memory and cancellation-latency measurements require each target device. Unknown hardware and missing provider metrics remain unknown. Organization features require no inference; cloud processing retains existing explicit permissions.

## Implemented behavior

- Chat entry is independent of native GGUF restoration, hardware probes and memory setup. Those services initialize lazily for requests; pending preparation is cancellable. Required startup storage reads time out after 15 seconds with Retry, while history refresh does not hide the composer. Back to DayArk lives inside the sidebar/drawer and targets the outer application route in loading/error/ready states; direct links return Home. The mobile toolbar menu opens the drawer without a toolbar Back button.

- Local/Ollama output budgets reach the adapters. Ollama sends a positive `num_predict`; native generation reserves an output budget before trimming old exchanges. System instructions and the latest input are retained or an actionable context error is returned.
- Native thinking defaults off. Installed GGUF templates advertise the thinking switch only when they declare `enable_thinking`; Ollama uses its existing provider capabilities. Fast/Balanced/Quality/Custom profiles retain personalization and clamp request ceilings against the loaded context. Quality is a request ceiling, not a promise of a larger allocation.
- Native prompt-prefix reuse is explicit. Overflow fitting searches whole exchanges logarithmically rather than repeatedly retokenizing every shorter history. The final fitted template is reused for counting rather than rendered again. Changing GPU layers invalidates native model reuse. Context allocations are capped conservatively at 4,096 mobile / 8,192 desktop during detection, subject to lower model and RAM limits.
- Process RSS sampling is throttled to 500 ms during native streaming. Response records retain available input/output counts, finish reason, first streamed token latency and first visible token latency. The latter include preparation/loading until the first observed stream token; they are not native prompt-evaluation or decode-only timings. Nonstreaming runtimes leave unavailable token timings absent.
- Existing batched streaming and incremental Markdown remain. Completed message widgets are reused by identity, with invalidation for conversation, theme, busy state and structural changes. Chat history and messages use lazy list rendering. Scrolling upwards stops following and exposes a return-to-bottom action.
- Device-local drafts are limited to 20 entries of 32,000 characters. PDF extraction uses a content-hashed session cache limited to eight entries / 1,048,576 characters, cleared on memory pressure. Hashing yields between slices. Native PDF extraction itself may finish before cancellation is observed; cancellation is checked before generation.
- Offline models unload after an adjustable idle period (five minutes by default; zero keeps them loaded). Idle release uses the existing exclusive provider. Memory pressure clears caches and attempts to unload an idle model. No extra inference engine is created.
- The responsive workspace has a drawer on phones, a resizable/collapsible desktop sidebar, a bounded reading column, a passive optional inspector and a multiline composer. Sidebar width, collapse and inspector preferences persist on the device. Inspector values remain unknown when adapters do not report them; no backend or throughput is fabricated.
- Keyboard controls cover new conversation, chat search, model selection, saved responses, sidebar visibility, send/queue and Stop. Enter adds a new line by default. The device-local Enter to send switch in AI Settings → General enables sending with Enter; Shift+Enter remains a new line and Ctrl/Cmd+Enter sends or queues. The overflow menu lists shortcuts.
- Existing pinning, folders, archives, export and paired-device synchronization remain. Pinned conversations are exposed as favourites. Bookmarks, notes, tags and response versions use existing conversation records. Saved responses search active and archived conversations. User-authored prompt templates support create, edit text, duplicate, favourite, category, delete and insertion; starter templates are deterministic.
- Regeneration preserves up to ten previous answer texts. Previous versions can be viewed/copied/made current. Branching copies messages through the chosen response into a private conversation and retains conversation instructions.
- Generation tracks preparation, prompt processing, thinking, output, cancellation and terminal states. Request IDs reject stale events. Stop preserves partial output. Continue and explicit transformations append requests using the same provider. Answer now cancels, settles and restarts with a concise-answer instruction and thinking disabled where supported; it does not inject instructions into a live native request.
- Queues are limited to ten messages, support editing, ordering, removal and manual resumption after interruption. Successful completion drains the queue sequentially. Failure/Stop pauses it. Leaving the conversation clears its queue; queued messages are session-only.
- Global, conversation and next-response preferences have explicit precedence, with protected application instructions above them. Memory retrieval can be disabled from the composer. Fast/Balanced/Quality bound retrieval to two/four/eight hits, while existing privacy permissions and memory opt-ins remain authoritative.
- Fenced code blocks show language, copy, save, wrap and expand/collapse controls. Code remains inert text. The Markdown parser already installed transitively is now declared as a direct dependency; no new package version was downloaded.
- Model management adds recommended/installed/favourites/recent/all/download sections, search, quantization and memory-fit filters, sorting, storage totals and comparison of up to three models. Quantization family grouping, download consent, cancellation, integrity checks, delete, load and benchmark remain. Native GGUF import copies and hashes the source into owned storage, validates metadata and commits an atomic manifest without moving the source.
- Choosing an installed model from chat creates/reuses an offline profile and selects it. Existing catalogue entries and publisher verification remain; no unverified newer models were added. Memory-fit estimates explicitly do not claim measured speed.

## Storage and migrations

The existing Drift schema remains version 2 and conversation JSON remains version 1. New message fields (`bookmarked`, `note`, `tags`, `versions`, token counts, finish reason, first-token timings) and conversation `instructions` are optional, defaulting safely when absent. Existing IDs, revisions, clocks, deletion tombstones, sharing consent, attachments and provider references are preserved. Metadata travels through the existing sync payload; provider credentials and device-only drafts/layout/templates do not. An older client can read the unchanged base records but may discard unfamiliar optional metadata when rewriting them.

AI settings gain optional profile, memory-use and idle-timeout fields with backward-compatible defaults. New device-only preferences use `dayark.ai.workspace.*` and `dayark.ai.models.*`; no database migration or data rewrite is performed at startup. Model imports use the existing manifest format and integrity validation.

## Measurements and limitations

Tests validate deterministic behavior; they do not establish a token/s or first-token improvement on a physical CPU/GPU. No real-device baseline or cross-platform thermal/battery measurements were taken. Native throughput and benchmark output continue to include prompt processing. Independent native prompt-evaluation throughput, decode-only throughput, reasoning-token counts, GPU memory and cancellation latency remain unreported when the adapter does not supply them.

The following portions of the broader brief remain follow-up work, rather than implemented or simulated controls:

- Per-backend CPU thread/batch/sampling tuning UI, explicit backend/GPU-layer overrides, reasoning budgets and measured CPU-versus-GPU auto-selection.
- Platform thermal/battery integration and validation on the requested physical hardware classes.
- Temporary conversations with dedicated retention/indexing semantics, optional tabs, current-conversation search and wider-reading preferences.
- Model grid view, capability filters beyond available metadata, benchmark-speed/TTFT sorting and pausable/resumable downloads. Existing downloader supports cancellation/retry by starting a new download.
- OS drag-and-drop integration, mathematical typesetting and response read-aloud. Existing voice input is retained.
- Independent prompt/KV cache benchmarks and deeper provider-specific lifecycle diagnostics. Cache reuse delegates to llamadart; there is no duplicate KV-cache implementation.

## Validation

Validation executed on 2026-11-20:

- `flutter test --no-pub`: 218 tests passed across the full project before the final history-fitting optimization; subsequent context/controller and responsive UI checks cover that final work.
- `flutter analyze --no-pub lib/ai test/ai`: no issues found.
- Full-project analysis ran and reported 955 warnings/style notices at that point, including four AI notices subsequently fixed. The unrelated existing repository notices were left outside this change; there were no analyzer errors.
- Eight rendered layout checks passed at 320×600, 600×800, 960×640 and 1400×900 in light/dark mode, including persisted inspector/sidebar controls. Optional PNG previews were visually inspected.
- Context fitting was tested against 1,001 messages with fewer than fifteen tokenizer calls, preserving the latest input and whole exchanges. This measures algorithmic work, not device inference speed.

The unchanged HEAD snapshot was tested separately: legacy GGUF test files contained only marker text, GPU fakes lacked `getContextSize`, and several assertions predated graded memory recommendations and local output settings. Tests now use valid metadata-only GGUF fixtures and explicit runtime configuration; none were disabled.

The repository's existing Postman provider simulation was reused locally. All five real HTTP adapters passed discovery, connection, generation, streaming and continued-history checks against synthetic contract-derived mocks. This establishes local wiring, not live vendor entitlement or native model performance. No provider credentials, paid requests, model downloads or cloud publication were used.

## Added and modified files

- `CHANGELOG.md`
- `docs/AI_WORKSPACE.md`
- `lib/ai/chat/ai_chat_actions.dart`
- `lib/ai/chat/ai_chat_composer.dart`
- `lib/ai/chat/ai_chat_controller.dart`
- `lib/ai/chat/ai_chat_dialogs.dart`
- `lib/ai/chat/ai_chat_history.dart`
- `lib/ai/chat/ai_chat_library.dart`
- `lib/ai/chat/ai_chat_management.dart`
- `lib/ai/chat/ai_chat_message.dart`
- `lib/ai/chat/ai_chat_preferences.dart`
- `lib/ai/chat/ai_chat_preparation.dart`
- `lib/ai/chat/ai_chat_screen.dart`
- `lib/ai/chat/ai_chat_workspace.dart`
- `lib/ai/chat/ai_conversation.dart`
- `lib/ai/chat/ai_generation_state.dart`
- `lib/ai/chat/ai_workspace_store.dart`
- `lib/ai/chat/widgets/ai_chat_welcome.dart`
- `lib/ai/chat/widgets/ai_workspace_inspector.dart`
- `lib/ai/core/ai_document_cache.dart`
- `lib/ai/core/ai_input_preparation.dart`
- `lib/ai/memory/memory_context_service.dart`
- `lib/ai/model_manager/gguf_metadata.dart`
- `lib/ai/model_manager/local_model_manager.dart`
- `lib/ai/model_manager/model_catalogue.dart`
- `lib/ai/performance/performance_profile.dart`
- `lib/ai/providers/http/http_ai_provider.dart`
- `lib/ai/providers/offline/llamadart_runtime.dart`
- `lib/ai/providers/offline/offline_provider.dart`
- `lib/ai/providers/offline/offline_runtime.dart`
- `lib/ai/settings/ai_configured_assistant.dart`
- `lib/ai/settings/ai_local_models.dart`
- `lib/ai/settings/ai_local_models_cards.dart`
- `lib/ai/settings/ai_local_models_details.dart`
- `lib/ai/settings/ai_local_models_library.dart`
- `lib/ai/settings/ai_local_models_native.dart`
- `lib/ai/settings/ai_local_models_screen.dart`
- `lib/ai/settings/ai_preferences.dart`
- `lib/ai/settings/ai_settings.dart`
- `lib/ai/settings/ai_settings_screen.dart`
- `lib/ai/widgets/ai_code_block.dart`
- `lib/ai/widgets/ai_response_text.dart`
- `postman/simulations/ai-providers/ai-providers.context.yaml`
- `pubspec.lock`
- `pubspec.yaml`
- `test/ai/ai_catalogue_families_test.dart`
- `test/ai/ai_chat_controller_test.dart`
- `test/ai/ai_chat_screen_test.dart`
- `test/ai/ai_code_block_test.dart`
- `test/ai/ai_gpu_runtime_test.dart`
- `test/ai/ai_http_provider_test.dart`
- `test/ai/ai_local_context_regression_test.dart`
- `test/ai/ai_model_management_test.dart`
- `test/ai/ai_model_settings_ui_test.dart`
- `test/ai/ai_offline_provider_test.dart`
- `test/ai/ai_release_acceptance_test.dart`
- `test/ai/ai_stream_responsiveness_test.dart`
- `test/ai/ai_streaming_test.dart`
- `test/ai/ai_workspace_layout_test.dart`
- `test/ai/ai_workspace_test.dart`
- `test/ai/fixtures/gguf_fixture.dart`
- `update.md`

Startup fix validation: `flutter test --no-pub` passed all 224 tests, and `flutter analyze --no-pub lib/ai test/ai` reported no issues. Regression coverage: `test/ai/ai_chat_startup_test.dart`.

## Follow-up navigation fixes

The message pane and viewport have stable keys across sidebar and responsive layout changes. Scroll controls read only a single attached position, preventing the reported two-client assertion during rebuilding. Tests verify position identity and a single controller attachment while toggling and resizing an active conversation.

Models opens a route immediately and initializes inside a cancellable loading view. Initialization failure/timeout exposes Retry; closing the page releases the waiting view without cancelling a shared session needed elsewhere. Settings uses the same model loading page. AI settings no longer eagerly waits for model verification at entry.

AI settings opened from chat is pushed inside chat's nested navigator, with Back restoring the caller and its draft. Desktop no longer shows Back to DayArk, even in a narrow-window drawer. The mobile exit remains available.

The Enter to send switch persists as `dayark.ai.workspace.enterToSend` (default false), independently of provider credentials/settings and sync. Hardware Enter and software keyboard Send respect it; Shift+Enter inserts a newline and does not send. IME composition is not interrupted. Regression coverage: `test/ai/ai_chat_navigation_regression_test.dart`.

Follow-up validation: all 229 Flutter tests passed; `flutter analyze --no-pub lib/ai test/ai` reported no issues. Added `lib/ai/settings/ai_local_models_page.dart` for visible asynchronous model initialization.
