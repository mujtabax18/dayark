import '../../core/ai_cancellation.dart';
import '../../core/ai_capabilities.dart';
import '../../core/ai_error.dart';
import '../../core/ai_managed_provider.dart';
import '../../models/ai_models.dart';
import '../../models/ai_provider_models.dart';
import '../../models/ai_request.dart';
import 'ai_http_transport.dart';

/// Provider protocols remain inside adapters; all return the same chat values.
enum AiHttpProtocol { openai, compatible, gemini, anthropic, ollama }

abstract class HttpAiProvider implements AiManagedProvider {
  HttpAiProvider({
    required this.id,
    required this.protocol,
    required Uri baseUrl,
    required this.credentials,
    bool allowInsecureHttp = false,
    Map<String, AiCapabilities> modelCapabilities = const {},
    this.anthropicVersion = '2023-06-01',
    this.compatibleUsesCompletionTokens = false,
    this.defaultMaxOutputTokens = 1024,
  }) : transport = AiHttpTransport(
         baseUrl: baseUrl,
         allowInsecureHttp: allowInsecureHttp,
       ),
       _modelCapabilities = Map.unmodifiable(modelCapabilities) {
    if (id.trim().isEmpty || defaultMaxOutputTokens < 1) {
      throw ArgumentError(
        'Provider ID and positive default output limit required.',
      );
    }
  }
  @override
  final String id;
  final AiHttpProtocol protocol;
  final AiCredentialLoader? credentials;
  final AiHttpTransport transport;
  final Map<String, AiCapabilities> _modelCapabilities;
  final String anthropicVersion;
  final bool compatibleUsesCompletionTokens;
  final int defaultMaxOutputTokens;
  @override
  bool get isRemote => true;

  @override
  AiCapabilities capabilitiesFor(String modelId) {
    final configured = _modelCapabilities[modelId];
    if (configured != null) return configured;
    // Conservative defaults; callers may provide explicit per-model metadata.
    final reasoning =
        protocol == AiHttpProtocol.openai &&
        RegExp(r'^(o[1-9]|gpt-[5-9])').hasMatch(modelId);
    // Claude 4.7+ and the Fable/Mythos families reject sampling overrides.
    final fixedClaudeSampling =
        protocol == AiHttpProtocol.anthropic &&
        RegExp(
          r'^claude-(?:(?:fable|mythos)(?:-|$)|(?:sonnet|haiku|opus)-(?:[5-9]|4-[7-9]))',
        ).hasMatch(modelId);
    return AiCapabilities(
      temperature: !reasoning && !fixedClaudeSampling,
      maxTemperature: protocol == AiHttpProtocol.anthropic ? 1 : 2,
      contextWindow: protocol == AiHttpProtocol.ollama,
    );
  }

  Future<Map<String, String>> _headers(AiCancellationToken token) async {
    token.throwIfCancelled();
    String? key;
    try {
      key = (await credentials?.call())?.trim();
    } catch (_) {
      throw const AiException(
        AiErrorCode.authentication,
        'Unable to read AI credentials.',
      );
    }
    token.throwIfCancelled();
    final requiredKey =
        protocol != AiHttpProtocol.ollama &&
        protocol != AiHttpProtocol.compatible;
    if (requiredKey && (key == null || key.isEmpty)) {
      throw const AiException(
        AiErrorCode.authentication,
        'An AI API key is required.',
      );
    }
    return switch (protocol) {
      AiHttpProtocol.gemini => {'x-goog-api-key': key!},
      AiHttpProtocol.anthropic => {
        'x-api-key': key!,
        'anthropic-version': anthropicVersion,
      },
      _ => {if (key?.isNotEmpty ?? false) 'Authorization': 'Bearer $key'},
    };
  }

  @override
  Future<AiResponse> generate(
    AiRequest request, {
    required AiCancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    if (!request.allowRemoteProcessing) {
      throw const AiException(
        AiErrorCode.permissionDenied,
        'Remote AI processing requires explicit authorization.',
      );
    }
    if (request.selection.providerId != id) {
      throw const AiException(
        AiErrorCode.invalidRequest,
        'Request selected another provider.',
      );
    }
    // Attachment upload/serialization is introduced in Part 5; never drop data.
    if (request.messages.any((message) => message.attachments.isNotEmpty)) {
      throw const AiException(
        AiErrorCode.unsupportedCapability,
        'This adapter currently accepts text only.',
      );
    }
    final settings = request.settings;
    final caps = capabilitiesFor(request.selection.modelId);
    if ((settings.temperature != null &&
            (!caps.temperature ||
                (caps.maxTemperature != null &&
                    settings.temperature! > caps.maxTemperature!))) ||
        (settings.maxOutputTokens != null && !caps.outputTokenLimit) ||
        (settings.contextWindowTokens != null && !caps.contextWindow)) {
      throw const AiException(
        AiErrorCode.unsupportedCapability,
        'Unsupported model settings.',
      );
    }
    final headers = await _headers(cancellationToken);
    final system = request.messages
        .where((m) => m.role == AiRole.system)
        .map((m) => m.text)
        .join('\n\n');
    final conversation = request.messages
        .where((m) => m.role != AiRole.system)
        .toList();
    final List<Map<String, Object?>> messages = request.messages
        .map((m) => <String, Object?>{'role': m.role.name, 'content': m.text})
        .toList();
    final Map<String, Object?> body;
    final String path;
    switch (protocol) {
      case AiHttpProtocol.openai:
      case AiHttpProtocol.compatible:
        path = 'chat/completions';
        body = {
          'model': request.selection.modelId,
          'messages': messages,
          'stream': false,
          if (protocol == AiHttpProtocol.openai) 'store': false,
          if (settings.temperature != null) 'temperature': settings.temperature,
          if (settings.maxOutputTokens != null)
            (protocol == AiHttpProtocol.openai || compatibleUsesCompletionTokens
                    ? 'max_completion_tokens'
                    : 'max_tokens'):
                settings.maxOutputTokens,
        };
      case AiHttpProtocol.gemini:
        final model = request.selection.modelId.replaceFirst(
          RegExp(r'^models/'),
          '',
        );
        path = 'models/${Uri.encodeComponent(model)}:generateContent';
        body = {
          if (system.isNotEmpty)
            'systemInstruction': {
              'parts': [
                {'text': system},
              ],
            },
          'contents': [
            for (final m in conversation)
              {
                'role': m.role == AiRole.assistant ? 'model' : 'user',
                'parts': [
                  {'text': m.text},
                ],
              },
          ],
          if (settings.temperature != null || settings.maxOutputTokens != null)
            'generationConfig': {
              if (settings.temperature != null)
                'temperature': settings.temperature,
              if (settings.maxOutputTokens != null)
                'maxOutputTokens': settings.maxOutputTokens,
            },
        };
      case AiHttpProtocol.anthropic:
        path = 'messages';
        // Claude requires max_tokens and top-level system, never a system role.
        // Merge adjacent same-role messages to match the Messages contract.
        final turns = <Map<String, String>>[];
        for (final m in conversation) {
          if (turns.isNotEmpty && turns.last['role'] == m.role.name) {
            turns.last['content'] = '${turns.last['content']}\n\n${m.text}';
          } else {
            turns.add({'role': m.role.name, 'content': m.text});
          }
        }
        body = {
          'model': request.selection.modelId,
          'messages': turns,
          if (system.isNotEmpty) 'system': system,
          'max_tokens': settings.maxOutputTokens ?? defaultMaxOutputTokens,
          if (settings.temperature != null) 'temperature': settings.temperature,
          'stream': false,
        };
      case AiHttpProtocol.ollama:
        path = 'chat';
        body = {
          'model': request.selection.modelId,
          'messages': messages,
          'stream': false,
          'options': {
            if (settings.temperature != null)
              'temperature': settings.temperature,
            if (settings.maxOutputTokens != null)
              'num_predict': settings.maxOutputTokens,
            if (settings.contextWindowTokens != null)
              'num_ctx': settings.contextWindowTokens,
          },
        };
    }
    final data = await transport.send(
      path,
      method: 'POST',
      body: body,
      headers: headers,
      cancellationToken: cancellationToken,
    );
    try {
      return _response(request, data);
    } on AiException {
      rethrow;
    } catch (_) {
      throw invalidAiResponse;
    }
  }

  AiResponse _response(AiRequest request, Map<String, dynamic> data) {
    String text;
    String? finish;
    int? input;
    int? output;
    switch (protocol) {
      case AiHttpProtocol.openai:
      case AiHttpProtocol.compatible:
        final choices = aiList(data['choices']);
        if (choices.isEmpty) throw invalidAiResponse;
        final choice = aiObject(choices.first);
        final message = aiObject(choice['message']);
        if (message['role'] != 'assistant' || message['tool_calls'] != null) {
          throw invalidAiResponse;
        }
        text = aiString(message['content']);
        finish = choice['finish_reason'] as String?;
        final usage = data['usage'] == null
            ? <String, dynamic>{}
            : aiObject(data['usage']);
        input = aiTokenCount(usage['prompt_tokens']);
        output = aiTokenCount(usage['completion_tokens']);
      case AiHttpProtocol.gemini:
        final candidates = aiList(data['candidates']);
        if (candidates.isEmpty) throw invalidAiResponse;
        final candidate = aiObject(candidates.first);
        final parts = aiList(aiObject(candidate['content'])['parts']);
        text = parts
            .map(aiObject)
            .where((p) => p['thought'] != true && p['text'] is String)
            .map((p) => p['text'] as String)
            .join();
        finish = candidate['finishReason'] as String?;
        final usage = data['usageMetadata'] == null
            ? <String, dynamic>{}
            : aiObject(data['usageMetadata']);
        input = aiTokenCount(usage['promptTokenCount']);
        output = aiTokenCount(usage['candidatesTokenCount']);
      case AiHttpProtocol.anthropic:
        if (data['role'] != 'assistant') throw invalidAiResponse;
        text = aiList(data['content'])
            .map(aiObject)
            .where((p) => p['type'] == 'text')
            .map((p) => aiString(p['text']))
            .join();
        finish = data['stop_reason'] as String?;
        final usage = data['usage'] == null
            ? <String, dynamic>{}
            : aiObject(data['usage']);
        input = aiTokenCount(usage['input_tokens']);
        output = aiTokenCount(usage['output_tokens']);
      case AiHttpProtocol.ollama:
        final message = aiObject(data['message']);
        if (data['done'] != true || message['role'] != 'assistant') {
          throw invalidAiResponse;
        }
        text = aiString(message['content']);
        finish = data['done_reason'] as String?;
        input = aiTokenCount(data['prompt_eval_count']);
        output = aiTokenCount(data['eval_count']);
    }
    aiString(text);
    return AiResponse(
      selection: request.selection,
      message: AiMessage(role: AiRole.assistant, text: text),
      usage: AiUsage(inputTokens: input, outputTokens: output),
      finishReason: finish,
    );
  }

  @override
  Future<AiModelPage> listModels({
    String? cursor,
    required AiCancellationToken cancellationToken,
  }) async {
    if (cursor != null &&
        protocol != AiHttpProtocol.gemini &&
        protocol != AiHttpProtocol.anthropic) {
      throw const AiException(
        AiErrorCode.invalidRequest,
        'This provider does not accept a model cursor.',
      );
    }
    try {
      return await _listModels(
        cursor: cursor,
        cancellationToken: cancellationToken,
      );
    } on AiException {
      rethrow;
    } catch (_) {
      throw invalidAiResponse;
    }
  }

  Future<AiModelPage> _listModels({
    String? cursor,
    required AiCancellationToken cancellationToken,
  }) async {
    final headers = await _headers(cancellationToken);
    final data = await transport.send(
      protocol == AiHttpProtocol.ollama ? 'tags' : 'models',
      headers: headers,
      cancellationToken: cancellationToken,
      query: {
        if (protocol == AiHttpProtocol.gemini) 'pageSize': 100,
        if (protocol == AiHttpProtocol.anthropic) 'limit': 100,
        if (cursor != null && protocol == AiHttpProtocol.gemini)
          'pageToken': cursor,
        if (cursor != null && protocol == AiHttpProtocol.anthropic)
          'after_id': cursor,
      },
    );
    final entries = aiList(
      data[protocol == AiHttpProtocol.gemini ||
              protocol == AiHttpProtocol.ollama
          ? 'models'
          : 'data'],
    );
    final models = <AiModelInfo>[];
    for (final entry in entries) {
      final value = aiObject(entry);
      if (protocol == AiHttpProtocol.gemini &&
          !aiList(value['supportedGenerationMethods'])
              .contains('generateContent')) {
        continue;
      }
      final modelId = aiString(
        value[protocol == AiHttpProtocol.gemini ||
                protocol == AiHttpProtocol.ollama
            ? 'name'
            : 'id'],
      );
      final display =
          value[protocol == AiHttpProtocol.gemini
              ? 'displayName'
              : 'display_name'];
      models.add(
        AiModelInfo(
          selection: AiModelSelection(providerId: id, modelId: modelId),
          name: display is String && display.isNotEmpty ? display : modelId,
          capabilities: capabilitiesFor(modelId),
          inputTokenLimit: aiTokenCount(value['inputTokenLimit']),
          outputTokenLimit: aiTokenCount(value['outputTokenLimit']),
        ),
      );
    }
    final String? next = switch (protocol) {
      AiHttpProtocol.gemini => data['nextPageToken'] as String?,
      AiHttpProtocol.anthropic =>
        data['has_more'] == true ? aiString(data['last_id']) : null,
      _ => null,
    };
    return AiModelPage(
      models: models,
      nextCursor: next?.isEmpty == true ? null : next,
    );
  }

  @override
  Future<void> checkConnection({
    String? modelId,
    required AiCancellationToken cancellationToken,
  }) async {
    // No paid generation or conversation data. Listing verifies endpoint/auth;
    // selecting a model additionally verifies it appears in the exposed catalog.
    final seen = <String>{};
    String? cursor;
    do {
      final page = await listModels(
        cursor: cursor,
        cancellationToken: cancellationToken,
      );
      if (modelId == null ||
          page.models.any(
            (model) =>
                model.selection.modelId == modelId ||
                (protocol == AiHttpProtocol.gemini &&
                    model.selection.modelId == 'models/$modelId'),
          )) {
        return;
      }
      cursor = page.nextCursor;
      if (cursor != null && (!seen.add(cursor) || seen.length > 100)) {
        throw invalidAiResponse;
      }
    } while (cursor != null);
    throw const AiException(
      AiErrorCode.providerUnavailable,
      'Selected AI model is not exposed by the provider.',
    );
  }

  void close() => transport.close();
}
