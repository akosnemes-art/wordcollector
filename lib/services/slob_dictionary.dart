import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html;

/// Reads the UTF-8, zlib-compressed SLOB format used by the bundled FreeDict files.
class SlobDictionary {
  SlobDictionary(ByteData data) : _data = data {
    final reader = _SlobReader(data);
    if (reader.text(8) != '!-1SLOB\x1f') {
      throw const FormatException('Invalid SLOB signature');
    }
    reader.offset += 16; // UUID
    if (reader.text(reader.uint8()) != 'utf-8' ||
        reader.text(reader.uint8()) != 'zlib') {
      throw const FormatException('Unsupported SLOB encoding or compression');
    }

    final tagCount = reader.uint8();
    for (var index = 0; index < tagCount; index++) {
      final nameLength = reader.uint8();
      reader.offset += nameLength + 256; // Name and fixed-width tag value.
    }
    final contentTypeCount = reader.uint8();
    _contentTypes = List.generate(
      contentTypeCount,
      (_) => reader.text(reader.uint16()),
      growable: false,
    );
    reader.uint32(); // Total blob count.
    _store = reader.uint64();
    if (reader.uint64() != data.lengthInBytes) {
      throw const FormatException('Unexpected SLOB size');
    }

    final refCount = reader.uint32();
    final refPositions = reader.offset;
    final refs = refPositions + refCount * 8;
    for (var index = 0; index < refCount; index++) {
      reader.offset = refs + data.getUint64(refPositions + index * 8);
      final key = _normalize(reader.text(reader.uint16()));
      (_index[key] ??= []).add(reader.offset);
    }
  }

  final ByteData _data;
  final _index = <String, List<int>>{};
  late final List<String> _contentTypes;
  late final int _store;

  String? lookup(String word) {
    for (final offset in _index[_normalize(word)] ?? const <int>[]) {
      final reader = _SlobReader(_data)..offset = offset;
      final bin = reader.uint32();
      final item = reader.uint16();
      final binCount = _data.getUint32(_store);
      final binPositions = _store + 4;
      reader.offset =
          binPositions + binCount * 8 + _data.getUint64(binPositions + bin * 8);
      final itemCount = reader.uint32();
      final type = _contentTypes[_data.getUint8(reader.offset + item)];
      if (!type.startsWith('text/html')) continue;

      reader.offset += itemCount;
      final compressedLength = reader.uint32();
      final bytes = zlib.decode(reader.bytes(compressedLength));
      final blob = _SlobReader(ByteData.sublistView(Uint8List.fromList(bytes)));
      blob.offset = item * 4;
      final itemOffset = blob.uint32();
      blob.offset = itemCount * 4 + itemOffset;
      final entry = html.parse(blob.text(blob.uint32()));
      for (final quote in entry.querySelectorAll('.cit.trans .quote')) {
        if (quote.children.any((child) => child.classes.contains('quote'))) {
          continue;
        }
        final translation = quote.text.trim();
        if (translation.isNotEmpty) return translation;
      }
    }
    return null;
  }

  static String _normalize(String word) =>
      word.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _SlobReader {
  _SlobReader(this.data);

  final ByteData data;
  int offset = 0;

  int uint8() => data.getUint8(offset++);

  int uint16() {
    final value = data.getUint16(offset);
    offset += 2;
    return value;
  }

  int uint32() {
    final value = data.getUint32(offset);
    offset += 4;
    return value;
  }

  int uint64() {
    final value = data.getUint64(offset);
    offset += 8;
    return value;
  }

  Uint8List bytes(int length) {
    final result = Uint8List.sublistView(data, offset, offset + length);
    offset += length;
    return result;
  }

  String text(int length) => utf8.decode(bytes(length));
}
