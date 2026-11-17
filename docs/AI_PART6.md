# Part 6 — Voice input (steps 40–48)

The microphone button in AI chat opens push-to-talk recording, transcription and an editable transcript. Use transcript inserts text into the existing composer; sending continues through the same gateway. Audio is mono 16 kHz WAV, capped at two minutes and deleted after transcription or cancellation. The recorder is disposed when the dialog closes. The dialog shows recording amplitude and transcription progress.

Offline transcription uses sherpa_onnx multilingual Whisper on a worker isolate. The native stream and recognizer are always freed after each job to avoid retaining a speech model alongside a large chat model. English, Urdu and automatic recognition are available. English-only Whisper models cannot recognize Urdu.

Install/update a model from a local JSON manifest in the voice dialog. The manifest must contain exactly `encoder.onnx`, `decoder.onnx` and `tokens.txt`, each with `url` (HTTPS) and `sha256` (trusted 64-character hex checksum). These are sherpa-compatible ONNX files, not GGUF. Downloads are staged and verified before replacing the installed bundle. Delete model removes the installed speech bundle. Model files are separate from chat models and are never downloaded automatically.

Online transcription supports OpenAI and OpenAI-compatible saved profiles. The dialog has a separate speech model ID (default `whisper-1`); chat model IDs are not reused. The adapter posts multipart `file`, `model`, optional ISO language and `response_format=json` to `/audio/transcriptions`, resolves credentials through secure storage, and requires the existing online-processing permission. Redirects are disabled for credentialed requests. Recordings are not attached to chats or synchronized.

Reference contract: https://developers.openai.com/api/reference/resources/audio/subresources/transcriptions/methods/create
Runtime reference: https://pub.dev/documentation/sherpa_onnx/latest/sherpa_onnx/OfflineRecognizer-class.html

Verification: voice privacy, missing models, invalid installation and real multipart HTTP success/rate-limit/malformed-response tests. Run the local simulation with:

```
postman simulation run postman/simulations/speech/speech.sim.yaml --port 4018 --no-history
flutter test --no-pub --dart-define=DAYARK_AI_SIMULATION=true test/ai/ai_voice_test.dart
```

Live vendor requests, physical microphones, native model inference and multilingual accuracy need device validation with an installed model. Android/iOS/macOS microphone declarations are included. Linux recording requires the record package's native audio prerequisites. Postman CLI 1.74 supports simulations here but `postman status` is unavailable; authenticated owner discovery was skipped. Orbit DNS was unavailable; the mock uses the official API contract. No cloud resources were published.
