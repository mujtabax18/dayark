import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class Transcription {
  const Transcription(this.text, {this.language});
  final String text;
  final String? language;
}

abstract interface class SpeechProvider {
  bool get isRemote;
  Future<Transcription> transcribe(String wavPath, {String language = ''});
}

/// A recognizer lives only inside a worker isolate for one recording. Both native
/// stream and model are freed, including on decode errors.
class WhisperSpeechProvider implements SpeechProvider {
  const WhisperSpeechProvider(this.directory);
  final String directory;
  @override
  bool get isRemote => false;
  @override
  Future<Transcription> transcribe(String wavPath, {String language = ''}) {
    final dir = directory;
    return Isolate.run(() async {
      for (final name in ['encoder.onnx', 'decoder.onnx', 'tokens.txt']) {
        if (!File('$dir/$name').existsSync()) {
          throw StateError(
            'Install a multilingual Whisper model in Voice settings.',
          );
        }
      }
      sherpa.initBindings();
      final recognizer = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            tokens: '$dir/tokens.txt',
            numThreads: 2,
            debug: false,
            whisper: sherpa.OfflineWhisperModelConfig(
              encoder: '$dir/encoder.onnx',
              decoder: '$dir/decoder.onnx',
              language: language,
              task: 'transcribe',
            ),
          ),
        ),
      );
      try {
        final stream = recognizer.createStream();
        try {
          final wave = sherpa.readWave(wavPath);
          stream.acceptWaveform(
            samples: wave.samples,
            sampleRate: wave.sampleRate,
          );
          recognizer.decode(stream);
          return Transcription(
            recognizer.getResult(stream).text,
            language: language,
          );
        } finally {
          stream.free();
        }
      } finally {
        recognizer.free();
      }
    });
  }
}

/// OpenAI and endpoints implementing its multipart audio/transcriptions contract.
/// Credentials are resolved only after explicit online authorization.
class OnlineSpeechProvider implements SpeechProvider {
  OnlineSpeechProvider({
    required this.baseUrl,
    required this.model,
    required this.credential,
    required this.allowOnline,
    Dio? client,
  }) : client =
           client ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(minutes: 3),
               followRedirects: false,
             ),
           );
  final Uri baseUrl;
  final String model;
  final Future<String?> Function() credential;
  final bool allowOnline;
  final Dio client;
  @override
  bool get isRemote => true;
  @override
  Future<Transcription> transcribe(
    String wavPath, {
    String language = '',
  }) async {
    if (!allowOnline) {
      throw StateError('Enable online processing in AI settings first.');
    }
    final local = ['localhost', '127.0.0.1', '::1'].contains(baseUrl.host);
    if (baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment ||
        !(baseUrl.scheme == 'https' || (local && baseUrl.scheme == 'http'))) {
      throw ArgumentError(
        'Use HTTPS or localhost without embedded credentials.',
      );
    }
    if (await File(wavPath).length() > 24 * 1024 * 1024) {
      throw StateError('Recording exceeds the 24 MiB upload limit.');
    }
    final key = await credential();
    try {
      final response = await client.post<Object?>(
        '${baseUrl.toString().replaceAll(RegExp(r"/$"), "")}/audio/transcriptions',
        data: FormData.fromMap({
          'model': model,
          'response_format': 'json',
          if (language.isNotEmpty) 'language': language,
          'file': await MultipartFile.fromFile(wavPath, filename: 'speech.wav'),
        }),
        options: Options(
          headers: {
            if (key?.isNotEmpty ?? false) 'Authorization': 'Bearer $key',
          },
        ),
      );
      final data = response.data;
      if (data is! Map || data['text'] is! String) {
        throw StateError('The speech service returned an invalid transcript.');
      }
      return Transcription(data['text'] as String, language: language);
    } on DioException {
      throw StateError(
        'Speech service unavailable. Check credentials and connection.',
      );
    }
  }
}
