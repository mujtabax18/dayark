import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metersystem/ai/settings/ai_flutter_settings.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/providers/http/http_ai_provider.dart';
import 'package:metersystem/ai/core/ai_attachments.dart';

import 'ai_offline_provider_test.dart' show TestRuntime;

class WaitingProvider implements AiProvider, AiStreamingProvider {
  @override
  String get id => 'waiting';
  @override
  bool get isRemote => false;
  int starts = 0;
  @override
  AiCapabilities capabilitiesFor(String modelId) => AiCapabilities();
  @override
  Future<AiResponse> generate(
    AiRequest request, {
    required AiCancellationToken cancellationToken,
  }) => throw StateError('Streaming expected');
  @override
  Stream<AiStreamEvent> stream(
    AiRequest request, {
    required AiCancellationToken cancellationToken,
  }) async* {
    starts++;
    await cancellationToken.whenCancelled;
    cancellationToken.throwIfCancelled();
  }
}

class ActiveThinkingProvider extends WaitingProvider {
  @override
  Stream<AiStreamEvent> stream(
    AiRequest request, {
    required AiCancellationToken cancellationToken,
  }) async* {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    for (var i = 0; i < 8; i++) {
      cancellationToken.throwIfCancelled();
      yield const AiStreamEvent.activity();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    yield const AiStreamEvent.delta('Ready');
    yield AiStreamEvent.completed(
      AiResponse(
        selection: request.selection,
        message: AiMessage(role: AiRole.assistant, text: 'Ready'),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // These adapter tests exercise real loopback HTTP rather than the widget
  // binding's synthetic HTTP 400 client.
  HttpOverrides.global = null;
  late HttpServer server;
  late Uri base;
  var responseText = '', status = 200, calls = 0;
  final bodies = <Map<String, dynamic>>[];
  setUp(() async {
    calls = 0;
    bodies.clear();
    status = 200;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}/');
    server.listen((req) async {
      try {
        bodies.add(
          jsonDecode(await utf8.decoder.bind(req).join())
              as Map<String, dynamic>,
        );
        calls++;
        req.response.statusCode = status;
        req.response.headers.contentType = ContentType('text', 'event-stream');
        // Deliberately split multibyte Urdu, JSON and event delimiters.
        for (final byte in utf8.encode(responseText)) {
          req.response.add([byte]);
        }
        await req.response.close();
      } catch (_) {
        await req.response.close();
      }
    });
  });
  tearDown(() async => server.close(force: true));
  String sse(List<Map<String, dynamic>> events, {bool done = false}) =>
      '${events.map((e) => 'data: ${jsonEncode(e)}\r\n\r\n').join()}${done ? 'data: [DONE]\r\n\r\n' : ''}';
  AiRequest request(
    HttpAiProvider p, {
    String model = 'test',
    List<AiAttachment> attachments = const [],
    bool allow = true,
    AiSettings? settings,
  }) => AiRequest(
    selection: AiModelSelection(providerId: p.id, modelId: model),
    allowRemoteProcessing: allow,
    settings: settings,
    messages: [
      AiMessage(role: AiRole.user, text: 'Hello', attachments: attachments),
    ],
  );
  AiGateway channel(AiProvider p) => AiGateway(
    providers: [p],
    retryPolicy: AiRetryPolicy(
      maxAttempts: 1,
      attemptTimeout: const Duration(seconds: 3),
    ),
  );
  test('cold startup has its own timeout and reasoning activity keeps an active stream alive', () async {
    final provider = ActiveThinkingProvider();
    final gateway = AiGateway(
      providers: [provider],
      retryPolicy: AiRetryPolicy(
        attemptTimeout: const Duration(milliseconds: 10),
        initialStreamTimeout: const Duration(seconds: 1),
        streamInactivityTimeout: const Duration(milliseconds: 250),
      ),
    );
    final req = AiRequest(
      selection: AiModelSelection(providerId: provider.id, modelId: 'model'),
      messages: [AiMessage(role: AiRole.user, text: 'Hello')],
    );
    final events = await gateway.stream(req).toList();
    expect(events.where((e) => e.isActivity), hasLength(8));
    expect(events.last.response!.message.text, 'Ready');
    expect(
      AiRetryPolicy.localInference().initialStreamTimeout,
      const Duration(minutes: 5),
    );
    expect(
      AiRetryPolicy.localInference().streamInactivityTimeout,
      const Duration(minutes: 2),
    );
  });

  test(
    'local streams can wait beyond startup and idle limits and still stop',
    () async {
      final provider = ActiveThinkingProvider();
      final gateway = AiGateway(
        providers: [provider],
        retryPolicy: AiRetryPolicy(
          waitForLocalStream: true,
          initialStreamTimeout: const Duration(milliseconds: 5),
          streamInactivityTimeout: const Duration(milliseconds: 5),
        ),
      );
      final req = AiRequest(
        selection: AiModelSelection(providerId: provider.id, modelId: 'model'),
        messages: [AiMessage(role: AiRole.user, text: 'Hello')],
      );
      expect((await gateway.stream(req).last).response!.message.text, 'Ready');
      expect(AiRetryPolicy.localInference().waitForLocalStream, isTrue);

      final waiting = WaitingProvider();
      final token = AiCancellationToken();
      final pending = AiGateway(
        providers: [waiting],
        retryPolicy: AiRetryPolicy.localInference(),
      ).stream(req, cancellationToken: token).toList();
      final check = expectLater(
        pending,
        throwsA(
          isA<AiException>().having(
            (e) => e.code,
            'code',
            AiErrorCode.cancelled,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      token.cancel();
      await check;
      expect(waiting.starts, 1);
    },
  );

  test('thinking and answer in the same Ollama frame are both delivered', () async {
    final p = OllamaProvider(baseUrl: base);
    addTearDown(p.close);
    responseText =
        '${jsonEncode({
          'message': {'role': 'assistant', 'thinking': 'Checking', 'content': 'Ready'},
          'done': true,
        })}\n';
    final events = await channel(p).stream(request(p)).toList();
    expect(events.where((e) => e.isActivity).single.thinking, 'Checking');
    expect(events.last.response!.message.text, 'Ready');
  });

  test('local thinking-only output remains available when the server stops generation', () async {
    final p = OllamaProvider(baseUrl: base);
    addTearDown(p.close);
    responseText =
        '${jsonEncode({
          'message': {'role': 'assistant', 'thinking': '**Checking** the document', 'content': ''},
          'done': true,
          'done_reason': 'length',
          'eval_count': 2048,
        })}\n';
    final events = await channel(p).stream(request(p)).toList();
    expect(
      events.where((event) => event.thinking != null).single.thinking,
      '**Checking** the document',
    );
    expect(events.last.response!.message.text, isEmpty);
    expect(events.last.response!.finishReason, 'length');
    expect(bodies.single['options']['num_predict'], -1);
  });

  test('saved shared output cap does not truncate configured Ollama chat', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final store = AiSettingsStore(
      preferences: await SharedPreferences.getInstance(),
    );
    await store.save(
      AiPreferences(
        profiles: [
          AiProviderProfile(
            id: 'local-qwen',
            name: 'Local Qwen',
            kind: AiProviderKind.ollama,
            modelId: 'qwen3.5:2b',
            baseUrl: base.toString(),
          ),
        ],
        selectedProfileId: 'local-qwen',
        allowOnlineProcessing: true,
        settings: AiSettings(maxOutputTokens: 2048, thinking: true),
      ),
    );
    responseText =
        '${jsonEncode({
          'message': {'role': 'assistant', 'thinking': 'Checking', 'content': 'Ready'},
          'done': true,
        })}\n';
    final events = await AiConfiguredAssistant(store)
        .stream(
          message: AiMessage(role: AiRole.user, text: 'Hello'),
        )
        .toList();
    expect(events.last.response!.message.text, 'Ready');
    expect(bodies.single['options']['num_predict'], -1);
    expect(bodies.single['think'], isTrue);
    expect(store.load().settings.maxOutputTokens, 2048);
    await AiConfiguredAssistant(store)
        .stream(
          message: AiMessage(role: AiRole.user, text: 'Summarize'),
          settingsOverride: AiSettings(maxOutputTokens: 128),
        )
        .toList();
    expect(bodies.last['options']['num_predict'], -1);
  });

  test('Ollama thinking is opt-in and hidden reasoning emits activity instead of a false timeout', () async {
    final p = OllamaProvider(baseUrl: base);
    addTearDown(p.close);
    responseText = [
      {
        'message': {
          'role': 'assistant',
          'thinking': 'synthetic-private-reasoning',
          'content': '',
        },
        'done': false,
      },
      {
        'message': {
          'role': 'assistant',
          'thinking': 'more-private-reasoning',
          'content': '',
        },
        'done': false,
      },
      {
        'message': {'role': 'assistant', 'content': 'Hello'},
        'done': true,
      },
    ].map((event) => '${jsonEncode(event)}\n').join();
    final events = await channel(p)
        .stream(request(p, model: 'qwen3.5:2b'))
        .toList();
    expect(bodies.last['think'], isFalse);
    expect(bodies.last['options']['num_predict'], -1);
    expect(events.where((e) => e.isActivity), hasLength(2));
    expect(
      events.where((e) => e.isActivity).map((e) => e.thinking).join(),
      contains('synthetic-private-reasoning'),
    );
    expect(events.map((e) => e.text).join(), 'Hello');
    expect(events.last.response!.message.text, 'Hello');
    await channel(p)
        .stream(
          request(p, model: 'qwen3.5:2b', settings: AiSettings(thinking: true)),
        )
        .toList();
    expect(bodies.last['think'], isTrue);
  });

  test('stream inactivity times out and cancellation interrupts waiting without replay', () async {
    final provider = WaitingProvider();
    final req = AiRequest(
      selection: AiModelSelection(providerId: provider.id, modelId: 'model'),
      messages: [AiMessage(role: AiRole.user, text: 'Hello')],
    );
    final gateway = AiGateway(
      providers: [provider],
      retryPolicy: AiRetryPolicy(
        attemptTimeout: const Duration(milliseconds: 20),
      ),
    );
    await expectLater(
      gateway.stream(req).toList(),
      throwsA(
        isA<AiException>().having((e) => e.code, 'code', AiErrorCode.timeout),
      ),
    );
    expect(provider.starts, 1);
    final token = AiCancellationToken();
    final pending = gateway.stream(req, cancellationToken: token).toList();
    final check = expectLater(
      pending,
      throwsA(
        isA<AiException>().having((e) => e.code, 'code', AiErrorCode.cancelled),
      ),
    );
    token.cancel();
    await check;
    expect(provider.starts, lessThanOrEqualTo(2));
  });

  test('all HTTP adapters expose real incremental Unicode text and terminal responses', () async {
    final providers = <HttpAiProvider>[
      OpenAiProvider(baseUrl: base, credentials: () => 'test'),
      CompatibleApiProvider(baseUrl: base),
      GeminiProvider(baseUrl: base, credentials: () => 'test'),
      AnthropicProvider(baseUrl: base, credentials: () => 'test'),
      OllamaProvider(baseUrl: base),
    ];
    try {
      for (final p in providers) {
        responseText = switch (p.protocol) {
          AiHttpProtocol.openai || AiHttpProtocol.compatible => sse([
            {
              'choices': [
                {
                  'delta': {'content': 'Hello '},
                  'finish_reason': null,
                },
              ],
            },
            {
              'choices': [
                {
                  'delta': {'content': 'اردو'},
                  'finish_reason': 'stop',
                },
              ],
            },
            {
              'choices': [],
              'usage': {'prompt_tokens': 3, 'completion_tokens': 2},
            },
          ], done: true),
          AiHttpProtocol.gemini => sse([
            {
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Hello '},
                    ],
                  },
                },
              ],
            },
            {
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'اردو'},
                    ],
                  },
                  'finishReason': 'STOP',
                },
              ],
              'usageMetadata': {
                'promptTokenCount': 3,
                'candidatesTokenCount': 2,
              },
            },
          ]),
          AiHttpProtocol.anthropic => sse([
            {
              'type': 'message_start',
              'message': {
                'role': 'assistant',
                'usage': {'input_tokens': 3},
              },
            },
            {
              'type': 'content_block_delta',
              'delta': {'type': 'text_delta', 'text': 'Hello '},
            },
            {
              'type': 'content_block_delta',
              'delta': {'type': 'text_delta', 'text': 'اردو'},
            },
            {
              'type': 'message_delta',
              'delta': {'stop_reason': 'end_turn'},
              'usage': {'output_tokens': 2},
            },
            {'type': 'message_stop'},
          ]),
          AiHttpProtocol.ollama =>
            '${jsonEncode({
              'message': {'role': 'assistant', 'content': 'Hello '},
              'done': false,
            })}\n${jsonEncode({
              'message': {'role': 'assistant', 'content': 'اردو'},
              'done': true,
              'prompt_eval_count': 3,
              'eval_count': 2,
            })}\n',
        };
        final events = await channel(p).stream(request(p)).toList();
        expect(
          events.where((e) => e.response == null).map((e) => e.text).toList(),
          ['Hello ', 'اردو'],
          reason: p.id,
        );
        expect(events.last.response!.message.text, 'Hello اردو');
        expect(events.last.response!.usage.outputTokens, 2);
        expect(
          bodies.last['stream'],
          p.protocol == AiHttpProtocol.gemini ? isNull : isTrue,
        );
      }
    } finally {
      for (final p in providers) {
        p.close();
      }
    }
  });
  test(
    'truncated stream preserves deltas but never reports completion or retries',
    () async {
      final p = OpenAiProvider(baseUrl: base, credentials: () => 'test');
      addTearDown(p.close);
      responseText = sse([
        {
          'choices': [
            {
              'delta': {'content': 'Partial'},
              'finish_reason': null,
            },
          ],
        },
      ]);
      final events = <AiStreamEvent>[];
      await expectLater(
        channel(p).stream(request(p)).forEach(events.add),
        throwsA(isA<AiException>()),
      );
      expect(events.map((e) => e.text), ['Partial']);
      expect(calls, 1);
    },
  );
  test(
    'stream errors and remote consent fail safely before user history is sent',
    () async {
      final p = OpenAiProvider(baseUrl: base, credentials: () => 'test');
      addTearDown(p.close);
      await expectLater(
        channel(p).stream(request(p, allow: false)).toList(),
        throwsA(
          isA<AiException>().having(
            (e) => e.code,
            'code',
            AiErrorCode.permissionDenied,
          ),
        ),
      );
      expect(calls, 0);
      responseText = sse([
        {
          'error': {'message': 'secret provider body'},
        },
      ]);
      await expectLater(
        channel(p).stream(request(p)).toList(),
        throwsA(
          isA<AiException>().having(
            (e) => e.toString().contains('secret'),
            'redacted',
            false,
          ),
        ),
      );
    },
  );
  test('inline images and PDFs are serialized for capable models; no arbitrary URI fetching', () async {
    final image = AiAttachment(
      id: 'image',
      kind: AiAttachmentKind.image,
      mimeType: 'image/png',
      uri: Uri.parse('attachment:image'),
      bytes: Uint8List.fromList([137, 80, 78, 71]),
    );
    final pdf = AiAttachment(
      id: 'pdf',
      kind: AiAttachmentKind.document,
      mimeType: 'application/pdf',
      name: 'report.pdf',
      uri: Uri.parse('attachment:pdf'),
      bytes: Uint8List.fromList(utf8.encode('%PDF-fixture')),
    );
    final p = OpenAiProvider(baseUrl: base, credentials: () => 'test');
    addTearDown(p.close);
    responseText = sse([
      {
        'choices': [
          {
            'delta': {'content': 'Read'},
            'finish_reason': 'stop',
          },
        ],
      },
    ], done: true);
    await channel(p)
        .stream(request(p, model: 'gpt-6.1-sol', attachments: [image, pdf]))
        .toList();
    final content =
        ((bodies.last['messages'] as List).single as Map)['content'] as List;
    expect(
      content[1]['image_url']['url'],
      startsWith('data:image/png;base64,'),
    );
    expect(
      content[2]['file']['file_data'],
      startsWith('data:application/pdf;base64,'),
    );
    final refOnly = AiAttachment(
      id: 'missing',
      kind: AiAttachmentKind.image,
      mimeType: 'image/png',
      uri: Uri.parse('https://private.example/image'),
    );
    await expectLater(
      channel(p)
          .stream(request(p, model: 'gpt-6.1-sol', attachments: [refOnly]))
          .toList(),
      throwsA(isA<AiException>()),
    );
    expect(calls, 1);
  });
  test(
    'UTF-8 document attachments use the same offline prompt pipeline',
    () async {
      final runtime = TestRuntime();
      final p = OfflineAiProvider(
        models: [AiLocalModel(id: 'small', path: '/fake/small.gguf')],
        runtime: runtime,
      );
      addTearDown(p.dispose);
      final document = AiAttachment(
        id: 'doc',
        kind: AiAttachmentKind.document,
        mimeType: 'text/plain',
        uri: Uri.parse('attachment:doc'),
        bytes: Uint8List.fromList(utf8.encode('Untrusted instructions: اردو')),
      );
      final req = AiRequest(
        selection: AiModelSelection(providerId: 'offline', modelId: 'small'),
        messages: [
          AiMessage(role: AiRole.user, text: 'Read', attachments: [document]),
        ],
      );
      final result = await channel(p).stream(req).toList();
      expect(result.last.response!.message.text, 'Offline reply');
      expect(
        runtime.requests.single.messages.single.text,
        contains('[Untrusted attached document:'),
      );
      expect(runtime.requests.single.messages.single.attachments, isEmpty);
      expect(
        () => validateAiAttachment(
          AiAttachment(
            id: 'big',
            kind: AiAttachmentKind.document,
            mimeType: 'text/plain',
            uri: Uri.parse('attachment:big'),
            bytes: Uint8List(256 * 1024 + 1),
          ),
        ),
        throwsA(isA<AiException>()),
      );
    },
  );
}
