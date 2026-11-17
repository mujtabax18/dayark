# Part 7 — Memory and retrieval (steps 49–62)

Open **Memory & knowledge** from AI chat or AI settings. Document retrieval, approved memory retrieval, chat indexing and automatic extractive summaries are separate opt-in switches. None reads existing DayArk feature records. This release does not add application database access, actions, SQL generation or external retrieval tools.

| Steps | Implementation |
| --- | --- |
| 49–50 | `EmbeddingProvider` and CPU `LocalEmbeddingProvider` use a dedicated compatible GGUF through the existing llamadart runtime. The selected file is fingerprinted with SHA-256 and checked before loading. Models are released after each embedding batch. |
| 51–52 | Local PDF/TXT/Markdown extraction, Unicode-safe overlapping chunks with stable ordinals and rune offsets. PDFs use the existing PDF libraries, with extraction off the UI isolate. |
| 53–55 | Separate AI SQLite database; persisted model-tagged vector rows, exact cosine search, FTS5/BM25 keyword search and reciprocal-rank fusion. Enabled source categories are filtered before ranking. |
| 56–57 | Conservative UTF-8 context budgets, recent turns and optional bounded extractive summaries of earlier turns. Full original chat history remains in its chat database. |
| 58–59 | Facts require an explicit **Approve and save** action. Review, search, disable, edit, replace and delete sources through the knowledge screen. |
| 60 | Answers include a deterministic list of sources supplied to the model, with local links to source text, hash, chunk and offset. |
| 61 | Source updates atomically replace chunks, FTS entries and vectors. Deletion removes all three. Chat revisions/deletions reconcile before retrieval. Vector rebuilds preserve originals and commit only after successful embedding. |
| 62 | Sources and summaries enter as untrusted user-level JSON, with protected retrieval instructions. Every retrieved request is private. The gateway marks derived answers private; that marker persists through storage, sync, attachment preparation and later model switches. |

## Setup and behavior

Upload UTF-8 TXT/Markdown or a PDF with a text layer. Files are limited to 8 MiB, PDFs to 300 pages, and extracted text to 1 MiB. Scanned PDFs need OCR first; no OCR or cloud extraction happens automatically. Original file bytes and extracted text are stored independently of vector rows.

Keyword retrieval works immediately without installing a model. **Select embedding model / rebuild** selects a local, embedding-capable GGUF and builds its vector index. This is a dedicated embedding model, not a chat-model selection. The provider uses raw text consistently for queries and passages; choose a model supporting symmetric/raw text embeddings. Model-specific task-prefix profiles are not inferred. A changed or missing file fails explicitly; choose the replacement and rebuild. **Use keyword search** stops using the embedding model without deleting documents.

Vectors use a SQLite table plus exact cosine ranking in Dart. This intentionally reuses the existing SQLite stack instead of adding an unvalidated native vector extension. It is suitable for a personal local corpus; large collections need profiling and may warrant sqlite3_vec/ANN later. There are no remote embedding calls or downloads implicit in retrieval.

Facts are never inferred or saved automatically. Saving and enabling retrieval are separate controls. Chat indexing includes complete AI conversation text only, excludes answers derived from private retrieval, and keeps a bounded tail for very large conversations. Attachments need an explicit knowledge upload to become cross-conversation sources. Removing chat knowledge excludes that conversation from reindexing; deleting or updating the underlying chat also removes or refreshes its source before the next retrieval. Memories and documents stay local and do not participate in paired-device chat sync. A synchronized chat can contain a previously approved answer; source files themselves do not sync.

Both **online processing** and **private context online** must be enabled before any retrieved content or a previously derived private answer can go to a remote provider, including self-hosted profiles. Turning off retrieval does not clear the privacy marker in earlier answers. A blocked request uses the existing permission error and sends no provider request. The user can choose an offline profile or change the existing AI privacy permissions.

Citations identify evidence supplied to the model, not a guarantee that every model claim is supported. They are appended by the application, not trusted from model output. Local links open a text viewer. If the source changed or was deleted, the viewer reports that the cited version is unavailable. Disabling/deleting a source removes future source retrieval; it does not erase past conversation answers or user exports. Source excerpts cannot grant access to DayArk feature records or invoke actions, and model-generated remote images remain blocked by chat rendering.

## Verification

```
flutter analyze lib/ai test/ai/ai_memory_test.dart test/ai/ai_voice_test.dart
flutter test --no-pub test/ai test/home_ai_feature_test.dart
flutter build linux --debug --no-pub
```

Tests cover approval/defaults, Urdu FTS, hostile search strings, semantic synonym retrieval with deterministic test embeddings, source authorization, replacement/deletion, vector-model isolation and failed rebuild rollback, original file preservation, chat reconciliation, context bounds, untrusted prompt placement, private-context blocking on send/stream and across persisted history, local PDF extraction, citations through the configured assistant, and knowledge UI review/disable/search.

The deterministic embedding fixture establishes indexing/ranking behavior, not real-model quality. Native multilingual Whisper, actual GGUF embedding inference, physical microphone behavior and other OS builds require target-device validation with chosen models. Linux debug compilation validates native plugin linkage; it does not establish speech accuracy or multilingual retrieval quality. Part 8 remains the release acceptance gate.

Validation on 2026-11-17: scoped analysis reported no issues; all 121 AI/home integration tests passed; Linux debug build completed. Part 6 also passed the real HTTP Postman speech simulation (four voice tests with simulation enabled).
