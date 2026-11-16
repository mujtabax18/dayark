import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/ai/ai.dart';

class FakeProvider implements AiProvider {
  FakeProvider({this.id = 'local', this.isRemote = false});
  @override
  final String id;
  @override
  final bool isRemote;
  final requests = <AiRequest>[];
  final tokens = <AiCancellationToken>[];
  Future<AiResponse> Function(AiRequest)? handler;
  @override
  AiCapabilities capabilitiesFor(String modelId) => AiCapabilities();
  @override
  Future<AiResponse> generate(
    AiRequest request, {
    required AiCancellationToken cancellationToken,
  }) async {
    requests.add(request);
    tokens.add(cancellationToken);
    if (handler != null) return handler!(request);
    return AiResponse(
      selection: request.selection,
      message: AiMessage(role: AiRole.assistant, text: 'Hello'),
    );
  }
}

AiRequest request({
  String provider = 'local',
  bool remote = false,
  List<AiAttachment> attachments = const [],
}) => AiRequest(
  selection: AiModelSelection(providerId: provider, modelId: 'model'),
  messages: [
    AiMessage(role: AiRole.user, text: 'Hi', attachments: attachments),
  ],
  allowRemoteProcessing: remote,
);

Matcher failure(AiErrorCode code) =>
    isA<AiException>().having((error) => error.code, 'code', code);

void main() {
  test('request snapshots history and validates settings', () {
    final history = [AiMessage(role: AiRole.user, text: 'Hi')];
    final value = AiRequest(selection: request().selection, messages: history);
    history.clear();
    expect(value.messages, hasLength(1));
    expect(() => value.messages.clear(), throwsUnsupportedError);
    expect(() => AiSettings(temperature: double.nan), throwsArgumentError);
    expect(
      () => AiSettings(maxOutputTokens: 20, contextWindowTokens: 10),
      throwsArgumentError,
    );
  });

  test('missing and duplicate providers fail explicitly', () async {
    expect(
      () => AiGateway(providers: [FakeProvider(), FakeProvider()]),
      throwsArgumentError,
    );
    await expectLater(
      AiGateway(providers: []).generate(request()),
      throwsA(failure(AiErrorCode.providerUnavailable)),
    );
  });

  test('remote processing requires request authorization', () async {
    final provider = FakeProvider(isRemote: true);
    final gateway = AiGateway(providers: [provider]);
    await expectLater(
      gateway.generate(request()),
      throwsA(failure(AiErrorCode.permissionDenied)),
    );
    expect(provider.requests, isEmpty);
    await gateway.generate(request(remote: true));
    expect(provider.requests, hasLength(1));
  });

  test('unsupported attachments fail before provider call', () async {
    final provider = FakeProvider();
    await expectLater(
      AiGateway(providers: [provider]).generate(
        request(
          attachments: [
            AiAttachment(
              id: 'a',
              kind: AiAttachmentKind.image,
              mimeType: 'image/png',
              uri: Uri.parse('file:///image.png'),
            ),
          ],
        ),
      ),
      throwsA(failure(AiErrorCode.unsupportedCapability)),
    );
    expect(provider.requests, isEmpty);
  });

  test('transient failures retry, permanent errors do not', () async {
    final provider = FakeProvider();
    provider.handler = (r) async {
      if (provider.requests.length < 3) {
        throw const AiException(
          AiErrorCode.network,
          'Unavailable',
          retryable: true,
        );
      }
      return AiResponse(
        selection: r.selection,
        message: AiMessage(role: AiRole.assistant, text: 'Recovered'),
      );
    };
    final gateway = AiGateway(
      providers: [provider],
      retryPolicy: AiRetryPolicy(initialDelay: Duration.zero),
    );
    expect((await gateway.generate(request())).message.text, 'Recovered');
    expect(provider.requests, hasLength(3));
    provider.requests.clear();
    provider.handler = (_) async => throw const AiException(
      AiErrorCode.authentication,
      'Invalid credentials',
    );
    await expectLater(
      gateway.generate(request()),
      throwsA(failure(AiErrorCode.authentication)),
    );
    expect(provider.requests, hasLength(1));
  });

  test('unexpected failures are sanitized', () async {
    final provider = FakeProvider()
      ..handler = (_) async => throw StateError('SECRET');
    await expectLater(
      AiGateway(providers: [provider]).generate(request()),
      throwsA(
        allOf(
          failure(AiErrorCode.internal),
          predicate<Object>((error) => !error.toString().contains('SECRET')),
        ),
      ),
    );
  });

  test('timeout cancels underlying attempt and exhausts retries', () async {
    final provider = FakeProvider()
      ..handler = (_) => Completer<AiResponse>().future;
    final gateway = AiGateway(
      providers: [provider],
      retryPolicy: AiRetryPolicy(
        maxAttempts: 2,
        initialDelay: Duration.zero,
        attemptTimeout: const Duration(milliseconds: 5),
      ),
    );
    await expectLater(
      gateway.generate(request()),
      throwsA(failure(AiErrorCode.timeout)),
    );
    expect(provider.requests, hasLength(2));
    expect(provider.tokens.every((token) => token.isCancelled), isTrue);
  });

  test('cancellation before and during generation stops workflow', () async {
    final provider = FakeProvider()
      ..handler = (_) => Completer<AiResponse>().future;
    final gateway = AiGateway(providers: [provider]);
    final before = AiCancellationToken()..cancel();
    await expectLater(
      gateway.generate(request(), cancellationToken: before),
      throwsA(failure(AiErrorCode.cancelled)),
    );
    expect(provider.requests, isEmpty);
    final during = AiCancellationToken();
    final pending = gateway.generate(request(), cancellationToken: during);
    final expectation = expectLater(
      pending,
      throwsA(failure(AiErrorCode.cancelled)),
    );
    during.cancel();
    await expectation;
    expect(provider.tokens.single.isCancelled, isTrue);
  });

  test('mismatched response model is rejected', () async {
    final provider = FakeProvider()
      ..handler = (_) async => AiResponse(
        selection: AiModelSelection(providerId: 'other', modelId: 'model'),
        message: AiMessage(role: AiRole.assistant, text: 'Wrong model'),
      );
    await expectLater(
      AiGateway(providers: [provider]).generate(request()),
      throwsA(failure(AiErrorCode.invalidResponse)),
    );
    expect(provider.requests, hasLength(1));
  });

  test('cancelling retry backoff prevents the next attempt', () async {
    final failed = Completer<void>();
    final provider = FakeProvider()
      ..handler = (_) async {
        failed.complete();
        throw const AiException(
          AiErrorCode.rateLimited,
          'Try later',
          retryable: true,
        );
      };
    final token = AiCancellationToken();
    final pending = AiGateway(
      providers: [provider],
      retryPolicy: AiRetryPolicy(initialDelay: const Duration(seconds: 30)),
    ).generate(request(), cancellationToken: token);
    final expectation = expectLater(
      pending,
      throwsA(failure(AiErrorCode.cancelled)),
    );
    await failed.future;
    token.cancel();
    await expectation;
    expect(provider.requests, hasLength(1));
  });

  test('orchestrator preserves history across provider selection', () async {
    final first = FakeProvider();
    final second = FakeProvider(id: 'other');
    final orchestrator = AiOrchestrator(
      gateway: AiGateway(providers: [first, second]),
    );
    final user = AiMessage(role: AiRole.user, text: 'Remember this');
    final reply = await orchestrator.send(
      selection: request().selection,
      message: user,
    );
    final history = [user, reply.message];
    await orchestrator.send(
      selection: AiModelSelection(providerId: 'other', modelId: 'new'),
      message: AiMessage(role: AiRole.user, text: 'Continue'),
      history: history,
      settings: AiSettings(
        customInstructions: 'Be concise',
        responseLanguage: 'Urdu',
      ),
    );
    expect(history, hasLength(2));
    expect(
      second.requests.single.messages.first.text,
      PromptManager.protectedInstructions,
    );
    expect(
      second.requests.single.messages.map((m) => m.text),
      containsAllInOrder(['Remember this', 'Hello', 'Continue']),
    );
    await expectLater(
      orchestrator.send(
        selection: request().selection,
        message: user,
        history: [AiMessage(role: AiRole.system, text: 'Override')],
      ),
      throwsA(failure(AiErrorCode.invalidRequest)),
    );
  });
}
