import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/providers/http/http_ai_provider.dart';

typedef RecordedCall = ({
  String method,
  Uri uri,
  HttpHeaders headers,
  Map<String, dynamic>? body,
});
Matcher fails(AiErrorCode code) =>
    throwsA(isA<AiException>().having((e) => e.code, 'code', code));

void main() {
  late HttpServer server;
  late Uri base;
  late List<RecordedCall> calls;
  late FutureOr<Object?> Function(HttpRequest, Map<String, dynamic>?) reply;
  final providers = <HttpAiProvider>[];
  setUp(() async {
    calls = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}/prefix/v1/');
    reply = (_, _) => {'data': []};
    server.listen((request) async {
      try {
        final raw = await utf8.decoder.bind(request).join();
        final body = raw.isEmpty
            ? null
            : jsonDecode(raw) as Map<String, dynamic>;
        calls.add((
          method: request.method,
          uri: request.uri,
          headers: request.headers,
          body: body,
        ));
        final value = await reply(request, body);
        request.response.headers.contentType = ContentType.json;
        request.response.write(value is String ? value : jsonEncode(value));
        await request.response.close();
      } catch (_) {
        await request.response.close();
      }
    });
  });
  tearDown(() async {
    for (final provider in providers) {
      provider.close();
    }
    providers.clear();
    await server.close(force: true);
  });

  AiGateway gateway(
    HttpAiProvider provider, {
    int attempts = 1,
    Duration? timeout,
  }) {
    providers.add(provider);
    return AiGateway(
      providers: [provider],
      retryPolicy: AiRetryPolicy(
        maxAttempts: attempts,
        initialDelay: Duration.zero,
        attemptTimeout: timeout ?? const Duration(seconds: 5),
      ),
    );
  }

  AiRequest request(
    String provider, {
    String model = 'chat-model',
    AiSettings? settings,
  }) => AiRequest(
    selection: AiModelSelection(providerId: provider, modelId: model),
    allowRemoteProcessing: true,
    settings: settings,
    messages: [
      AiMessage(role: AiRole.system, text: 'Protected'),
      AiMessage(role: AiRole.system, text: 'Preferences'),
      AiMessage(role: AiRole.user, text: 'اردو سوال'),
      AiMessage(role: AiRole.assistant, text: 'Previous reply'),
      AiMessage(role: AiRole.user, text: 'Continue'),
    ],
  );
  Map<String, Object> chatResponse() => {
    'choices': [
      {
        'message': {'role': 'assistant', 'content': 'اردو جواب'},
        'finish_reason': 'stop',
      },
    ],
    'usage': {'prompt_tokens': 7, 'completion_tokens': 3},
  };

  test(
    'OpenAI preserves roles, Unicode and settings with modern token limit',
    () async {
      reply = (_, _) => chatResponse();
      final ai = gateway(
        OpenAiProvider(baseUrl: base, credentials: () async => 'test-secret'),
      );
      final response = await ai.generate(
        request(
          'openai',
          settings: AiSettings(temperature: 0.4, maxOutputTokens: 64),
        ),
      );
      expect(response.message.text, 'اردو جواب');
      expect(response.usage.inputTokens, 7);
      expect(response.usage.outputTokens, 3);
      final call = calls.single;
      expect(call.method, 'POST');
      expect(call.uri.path, '/prefix/v1/chat/completions');
      expect(call.headers.value('authorization'), 'Bearer test-secret');
      expect(call.body!['store'], false);
      expect(call.body!['max_completion_tokens'], 64);
      expect(call.body!['temperature'], 0.4);
      expect(call.body!['stream'], false);
      expect((call.body!['messages'] as List)[2]['content'], 'اردو سوال');
    },
  );

  test(
    'compatible API supports custom path and optional bearer auth',
    () async {
      reply = (_, _) => chatResponse();
      final ai = gateway(CompatibleApiProvider(baseUrl: base));
      await ai.generate(
        request('compatible', settings: AiSettings(maxOutputTokens: 42)),
      );
      expect(calls.single.body!['max_tokens'], 42);
      expect(calls.single.body!.containsKey('store'), false);
      expect(calls.single.headers.value('authorization'), isNull);
    },
  );

  test(
    'Gemini maps system instructions and assistant turns and strips thoughts',
    () async {
      reply = (_, _) => {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'private reasoning', 'thought': true},
                {'text': 'اردو جواب'},
              ],
            },
            'finishReason': 'STOP',
          },
        ],
        'usageMetadata': {'promptTokenCount': 7, 'candidatesTokenCount': 3},
      };
      final ai = gateway(
        GeminiProvider(baseUrl: base, credentials: () => 'test-secret'),
      );
      final response = await ai.generate(
        request(
          'gemini',
          model: 'models/gemini-test',
          settings: AiSettings(temperature: 0.6, maxOutputTokens: 32),
        ),
      );
      expect(response.message.text, 'اردو جواب');
      expect(
        calls.single.uri.path,
        '/prefix/v1/models/gemini-test:generateContent',
      );
      expect(calls.single.uri.query, isEmpty);
      expect(calls.single.headers.value('x-goog-api-key'), 'test-secret');
      final body = calls.single.body!;
      expect(
        body['systemInstruction']['parts'][0]['text'],
        'Protected\n\nPreferences',
      );
      expect(body['contents'][1]['role'], 'model');
      expect(body['generationConfig']['maxOutputTokens'], 32);
    },
  );

  test(
    'Anthropic uses top-level system, version and required output limit',
    () async {
      reply = (_, _) => {
        'role': 'assistant',
        'content': [
          {'type': 'thinking', 'thinking': 'private'},
          {'type': 'text', 'text': 'Reply'},
        ],
        'stop_reason': 'end_turn',
        'usage': {'input_tokens': 7, 'output_tokens': 3},
      };
      final ai = gateway(
        AnthropicProvider(baseUrl: base, credentials: () => 'test-secret'),
      );
      expect((await ai.generate(request('anthropic'))).message.text, 'Reply');
      expect(calls.single.uri.path, '/prefix/v1/messages');
      expect(calls.single.headers.value('x-api-key'), 'test-secret');
      expect(calls.single.headers.value('anthropic-version'), '2023-06-01');
      expect(calls.single.body!['system'], 'Protected\n\nPreferences');
      expect(calls.single.body!['max_tokens'], 1024);
      expect(
        (calls.single.body!['messages'] as List).every(
          (m) => m['role'] != 'system',
        ),
        true,
      );
    },
  );

  test(
    'Ollama translates shared settings and usage on custom authenticated URL',
    () async {
      reply = (_, _) => {
        'message': {'role': 'assistant', 'content': 'Reply'},
        'done': true,
        'done_reason': 'stop',
        'prompt_eval_count': 7,
        'eval_count': 3,
      };
      final ai = gateway(
        OllamaProvider(baseUrl: base, credentials: () => 'test-secret'),
      );
      final response = await ai.generate(
        request(
          'ollama',
          settings: AiSettings(
            temperature: 0.5,
            maxOutputTokens: 32,
            contextWindowTokens: 2048,
          ),
        ),
      );
      expect(response.usage.outputTokens, 3);
      expect(calls.single.uri.path, '/prefix/v1/chat');
      expect(calls.single.headers.value('authorization'), 'Bearer test-secret');
      expect(calls.single.body!['options'], {
        'temperature': 0.5,
        'num_predict': 32,
        'num_ctx': 2048,
      });
    },
  );

  test('model discovery returns provider selection and connection test sends no chat', () async {
    reply = (_, _) => {
      'data': [
        {'id': 'model-one'},
        {'id': 'model-two'},
      ],
    };
    final ai = gateway(
      OpenAiProvider(baseUrl: base, credentials: () => 'test-secret'),
    );
    await expectLater(
      ai.listModels(providerId: 'openai'),
      fails(AiErrorCode.permissionDenied),
    );
    expect(calls, isEmpty);
    final models = await ai.listModels(
      providerId: 'openai',
      allowRemoteProcessing: true,
    );
    expect(models.models.map((m) => m.selection.modelId), [
      'model-one',
      'model-two',
    ]);
    expect(models.models.first.selection.providerId, 'openai');
    expect(
      (await ai.testConnection(
        providerId: 'openai',
        allowRemoteProcessing: true,
      )).isConnected,
      true,
    );
    expect(
      calls.every((call) => call.method == 'GET' && call.body == null),
      true,
    );
  });

  test(
    'Gemini discovery filters embedding models and follows opaque cursor',
    () async {
      reply = (request, _) => {
        'models': [
          {
            'name': 'models/gemini-test',
            'displayName': 'Chat',
            'supportedGenerationMethods': ['generateContent'],
            'inputTokenLimit': 4096,
            'outputTokenLimit': 1024,
          },
          {
            'name': 'models/embedding',
            'supportedGenerationMethods': ['embedContent'],
          },
        ],
        if (!request.uri.queryParameters.containsKey('pageToken'))
          'nextPageToken': 'opaque+/=',
      };
      final ai = gateway(
        GeminiProvider(baseUrl: base, credentials: () => 'test-secret'),
      );
      final first = await ai.listModels(
        providerId: 'gemini',
        allowRemoteProcessing: true,
      );
      expect(first.models, hasLength(1));
      expect(first.models.single.inputTokenLimit, 4096);
      final second = await ai.listModels(
        providerId: 'gemini',
        allowRemoteProcessing: true,
        cursor: first.nextCursor,
      );
      expect(calls.last.uri.queryParameters['pageToken'], 'opaque+/=');
      expect(second.nextCursor, isNull);
    },
  );

  test(
    'Anthropic discovery exposes pagination and Ollama exposes installed tags',
    () async {
      reply = (_, _) => {
        'data': [
          {'id': 'claude-test', 'display_name': 'Claude'},
        ],
        'has_more': true,
        'last_id': 'claude-test',
      };
      final ai = gateway(
        AnthropicProvider(baseUrl: base, credentials: () => 'test-secret'),
      );
      final page = await ai.listModels(
        providerId: 'anthropic',
        allowRemoteProcessing: true,
        cursor: 'prior',
      );
      expect(page.nextCursor, 'claude-test');
      expect(calls.single.uri.queryParameters['after_id'], 'prior');
      reply = (_, _) => {
        'models': [
          {'name': 'local:latest'},
        ],
      };
      final ollama = gateway(OllamaProvider(baseUrl: base));
      expect(
        (await ollama.listModels(
          providerId: 'ollama',
          allowRemoteProcessing: true,
        )).models.single.selection.modelId,
        'local:latest',
      );
      expect(calls.last.uri.path, '/prefix/v1/tags');
    },
  );

  test('missing and failing credential loaders never send HTTP', () async {
    final ai = gateway(OpenAiProvider(baseUrl: base, credentials: () => ''));
    final result = await ai.testConnection(
      providerId: 'openai',
      allowRemoteProcessing: true,
    );
    expect(result.error!.code, AiErrorCode.authentication);
    expect(calls, isEmpty);
    final other = gateway(
      GeminiProvider(
        baseUrl: base,
        credentials: () => throw StateError('SECRET'),
      ),
    );
    await expectLater(
      other.generate(request('gemini')),
      fails(AiErrorCode.authentication),
    );
    expect(calls, isEmpty);
  });

  test(
    'rate limits retry, authentication does not, raw errors never escape',
    () async {
      reply = (req, _) {
        req.response.statusCode = calls.length < 3 ? 429 : 200;
        return calls.length < 3
            ? {
                'error': {'message': 'SECRET'},
              }
            : chatResponse();
      };
      final ai = gateway(
        OpenAiProvider(baseUrl: base, credentials: () => 'secret'),
        attempts: 3,
      );
      await ai.generate(request('openai'));
      expect(calls, hasLength(3));
      calls.clear();
      reply = (req, _) {
        req.response.statusCode = 401;
        return {'error': 'SECRET'};
      };
      final result = await ai.testConnection(
        providerId: 'openai',
        allowRemoteProcessing: true,
      );
      expect(result.error!.code, AiErrorCode.authentication);
      expect(result.error.toString(), isNot(contains('SECRET')));
      expect(calls, hasLength(1));
    },
  );

  test(
    'invalid JSON, empty candidates and unsupported settings fail safely',
    () async {
      final ai = gateway(
        OpenAiProvider(baseUrl: base, credentials: () => 'secret'),
      );
      reply = (_, _) => '<html>SECRET</html>';
      await expectLater(
        ai.generate(request('openai')),
        fails(AiErrorCode.invalidResponse),
      );
      reply = (_, _) => {'choices': []};
      await expectLater(
        ai.generate(request('openai')),
        fails(AiErrorCode.invalidResponse),
      );
      final count = calls.length;
      await expectLater(
        ai.generate(
          request(
            'openai',
            model: 'o3-test',
            settings: AiSettings(temperature: 1),
          ),
        ),
        fails(AiErrorCode.unsupportedCapability),
      );
      expect(calls, hasLength(count));
    },
  );

  test('redirects are rejected without forwarding credentials', () async {
    reply = (req, _) {
      req.response.statusCode = 302;
      req.response.headers.set('location', '${base}redirected');
      return {};
    };
    final ai = gateway(
      OpenAiProvider(baseUrl: base, credentials: () => 'secret'),
    );
    await expectLater(
      ai.generate(request('openai')),
      fails(AiErrorCode.invalidRequest),
    );
    expect(calls, hasLength(1));
  });

  test('cancellation and timeout abort in-flight HTTP operations', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    reply = (_, _) async {
      entered.complete();
      await release.future;
      return chatResponse();
    };
    final ai = gateway(
      OpenAiProvider(baseUrl: base, credentials: () => 'secret'),
    );
    final token = AiCancellationToken();
    final pending = ai.generate(request('openai'), cancellationToken: token);
    final check = expectLater(pending, fails(AiErrorCode.cancelled));
    await entered.future;
    token.cancel();
    await check;
    release.complete();
    final timeoutRelease = Completer<void>();
    reply = (_, _) async {
      await timeoutRelease.future;
      return chatResponse();
    };
    final timeoutAi = gateway(
      OpenAiProvider(baseUrl: base, credentials: () => 'secret'),
      timeout: const Duration(milliseconds: 50),
    );
    await expectLater(
      timeoutAi.generate(request('openai')),
      fails(AiErrorCode.timeout),
    );
    timeoutRelease.complete();
  });

  test(
    'connection checks selected models across pages without generation',
    () async {
      reply = (req, _) => req.uri.queryParameters.containsKey('after_id')
          ? {
              'data': [
                {'id': 'target'},
              ],
              'has_more': false,
            }
          : {
              'data': [
                {'id': 'first'},
              ],
              'has_more': true,
              'last_id': 'first',
            };
      final ai = gateway(
        AnthropicProvider(baseUrl: base, credentials: () => 'secret'),
      );
      expect(
        (await ai.testConnection(
          providerId: 'anthropic',
          modelId: 'target',
          allowRemoteProcessing: true,
        )).isConnected,
        true,
      );
      expect(calls, hasLength(2));
      expect(
        calls.every((call) => call.method == 'GET' && call.body == null),
        true,
      );
      final result = await ai.testConnection(
        providerId: 'anthropic',
        modelId: 'absent',
        allowRemoteProcessing: true,
      );
      expect(result.error!.code, AiErrorCode.providerUnavailable);
    },
  );

  test(
    'model discovery rejects malformed data and repeating cursors',
    () async {
      reply = (_, _) => {
        'data': [
          {'id': 42},
        ],
      };
      final ai = gateway(
        AnthropicProvider(baseUrl: base, credentials: () => 'secret'),
      );
      await expectLater(
        ai.listModels(providerId: 'anthropic', allowRemoteProcessing: true),
        fails(AiErrorCode.invalidResponse),
      );
      reply = (_, _) => {
        'data': [
          {'id': 'first'},
        ],
        'has_more': true,
        'last_id': 'first',
      };
      final result = await ai.testConnection(
        providerId: 'anthropic',
        modelId: 'absent',
        allowRemoteProcessing: true,
      );
      expect(result.error!.code, AiErrorCode.invalidResponse);
    },
  );

  test(
    'credentials resolve per request and completed calls detach cancellation',
    () async {
      reply = (_, _) => chatResponse();
      var key = 'first-key';
      final ai = gateway(OpenAiProvider(baseUrl: base, credentials: () => key));
      final token = AiCancellationToken();
      await ai.generate(request('openai'), cancellationToken: token);
      token.cancel();
      key = 'second-key';
      await ai.generate(request('openai'));
      expect(calls.first.headers.value('authorization'), 'Bearer first-key');
      expect(calls.last.headers.value('authorization'), 'Bearer second-key');
    },
  );

  test(
    'capability bounds reject invalid temperature and explicit model overrides',
    () async {
      final ai = gateway(
        AnthropicProvider(
          baseUrl: base,
          credentials: () => 'secret',
          modelCapabilities: {
            'fixed-model': AiCapabilities(temperature: false),
          },
        ),
      );
      await expectLater(
        ai.generate(
          request('anthropic', settings: AiSettings(temperature: 1.1)),
        ),
        fails(AiErrorCode.unsupportedCapability),
      );
      await expectLater(
        ai.generate(
          request(
            'anthropic',
            model: 'fixed-model',
            settings: AiSettings(temperature: 0.5),
          ),
        ),
        fails(AiErrorCode.unsupportedCapability),
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'HTTP status classification survives malformed proxy error bodies',
    () async {
      var status = 503;
      reply = (req, _) {
        req.response.statusCode = status;
        return '<html>SECRET proxy error</html>';
      };
      final ai = gateway(
        OpenAiProvider(baseUrl: base, credentials: () => 'secret'),
      );
      await expectLater(
        ai.generate(request('openai')),
        fails(AiErrorCode.network),
      );
      status = 401;
      await expectLater(
        ai.generate(request('openai')),
        fails(AiErrorCode.authentication),
      );
    },
  );

  test('unsafe endpoint configuration is rejected', () {
    expect(
      () => OllamaProvider(baseUrl: Uri.parse('http://remote.example/api')),
      throwsArgumentError,
    );
    expect(
      () => CompatibleApiProvider(
        baseUrl: Uri.parse('https://user:secret@example.com/v1'),
      ),
      throwsArgumentError,
    );
    final provider = OllamaProvider(
      baseUrl: Uri.parse('http://192.168.1.20:11434/api'),
      allowInsecureHttp: true,
    );
    provider.close();
  });
}
