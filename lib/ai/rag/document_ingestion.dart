import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

class DocumentIngestion {
  static Future<String> extract(String name, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
      throw const FormatException('Documents must contain at most 8 MiB.');
    }
    final text = await compute(_extract, (name: name, bytes: bytes));
    if (text.trim().isEmpty) {
      throw const FormatException(
        'No readable text. Scanned PDFs require OCR first.',
      );
    }
    if (text.length > 1024 * 1024) {
      throw const FormatException('Extracted text exceeds 1 MiB.');
    }
    return text;
  }

  static String _extract(({String name, Uint8List bytes}) input) {
    final extension = input.name.toLowerCase().split('.').last;
    if (['txt', 'md', 'markdown'].contains(extension)) {
      return utf8.decode(input.bytes);
    }
    if (extension != 'pdf') {
      throw const FormatException('Use PDF, UTF-8 TXT or Markdown.');
    }
    final document = PdfDocument.open(input.bytes);
    if (document.pages.length > 300) {
      throw const FormatException('PDFs are limited to 300 pages.');
    }
    return [
      for (var i = 0; i < document.pages.length; i++)
        '[Page ${i + 1}]\n${PdfTextExtractor.extract(document, i).text}',
    ].join('\n\n');
  }
}

class TextChunk {
  const TextChunk(this.index, this.offset, this.text);
  final int index, offset;
  final String text;
}

class ChunkingService {
  const ChunkingService({this.size = 700, this.overlap = 100});
  final int size, overlap;
  List<TextChunk> split(String text) {
    if (size < 32 || overlap < 0 || overlap >= size) {
      throw ArgumentError('Invalid chunk sizes.');
    }
    // Rune boundaries keep Urdu and supplementary Unicode characters intact.
    final runes = text.runes.toList();
    final chunks = <TextChunk>[];
    for (var start = 0; start < runes.length;) {
      final end = (start + size).clamp(0, runes.length);
      final value = String.fromCharCodes(runes.sublist(start, end));
      if (value.trim().isNotEmpty) {
        chunks.add(TextChunk(chunks.length, start, value));
      }
      if (end == runes.length) break;
      start = end - overlap;
    }
    return chunks;
  }
}
