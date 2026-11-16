# AI foundation — roadmap Part 1 (steps 1–6)

Import `package:metersystem/ai/ai.dart`. This module is pure Dart and has no
application database, widget, startup, or network dependencies. Existing DayArk
features are unchanged. Provider adapters and the chat UI belong to later parts;
no provider is registered and no network request occurs by default.

- `AiRequest`, `AiResponse`, messages, attachment references, usage, model
  selection and `AiSettings` define the shared logical contract. Collection
  inputs are copied into immutable snapshots. Credentials are not model fields.
- Implement `AiProvider` to translate this contract into a provider protocol.
  Declare per-model capabilities and whether processing leaves the device.
  Translate failures into safe `AiException` values without raw error bodies.
  Observe the attempt cancellation token to abort underlying work. The gateway
  can stop waiting for an uncooperative provider, but cannot kill its work.
- Construct `AiGateway(providers: [...])` once. Selection is per request; unknown
  providers, unsupported settings/attachments and unauthorized remote requests
  fail before generation. Remote includes self-hosted endpoints. Authorization
  must come from the calling UI/user, never from model text.
- `AiOrchestrator.send` composes protected instructions, user preferences,
  language, supplied history and the new user message through `PromptManager`,
  then uses the gateway. It has no mutable conversation state. Callers append
  successful replies to their own history and may switch selection each turn.
  Cancellation/failure never mutates caller history. System history is rejected.
- Retries are bounded (three attempts by default) with exponential delays and a
  per-attempt timeout. Only explicitly retryable adapter failures/timeouts retry;
  unknown exceptions are sanitized and fail immediately. Use a fresh
  `AiCancellationToken` for each send and call `cancel()` to stop it.

Prompt instructions describe the chat-only boundary; actual protection comes
from having no application-data or action APIs in this module. Attachments are
references, not automatic file reads/uploads. Token budgeting, provider-specific
settings translation, persistence, streaming, memory and RAG remain later work.

Validation: `flutter test --no-pub test/ai` and
`dart analyze lib/ai test/ai`.
