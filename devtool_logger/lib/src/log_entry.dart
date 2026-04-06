import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'log_level_color.dart';

// ── Stack-frame parsing ────────────────────────────────────────────────────

/// Patterns used for parsing raw stack trace lines into typed [ParsedStackFrame]s.
abstract final class _StackRegex {
  /// Device (Android / iOS): `#1      Logger.log (package:logger/src/...)`
  static final device = RegExp(r'#[0-9]+\s+(.+) \((\S+)\)');

  /// Browser (V8/Chrome): `at Object.methodName (file:line:col)`
  static final v8 = RegExp(r'^\s*at\s+(.+)\s+\((.+)\)$');

  /// Fallback for Web: `location [spaces] symbol`
  static final webFallback = RegExp(r'^(\S+\s+\d+:\d+)\s+(.+)$');

  /// Used to split a location string into [prefix, path, lineCol].
  /// Matches standard "package:path:line:col" or web "path line:col".
  static final locationSplitter = RegExp(
    r'^((?:package:[^/]+/|dart:[^/]+/|packages/[^/]+/|dart-sdk/lib/\S+/))?(.*?)(?:[: ](\d+:\d+))?$',
  );

  /// Matches the frame index header like '#0      '.
  static final frameHeader = RegExp(r'#\d+\s+');

  /// Prefix matching for discarding frames (same as PrettyPrinter)
  static final discardWeb = RegExp(r'^((?:packages|dart-sdk)/\S+/)');
  static final discardBrowser = RegExp(r'^((?:package:)?dart:\S+|\S+)');
}

/// A pre-parsed stack frame with location parts already separated for UI efficiency.
@immutable
class ParsedStackFrame {
  final int index;
  final String symbol;

  /// The prefix like 'package:flutter/', 'dart:core/' or empty.
  final String packagePrefix;

  /// The file path within the package, like 'src/material/ink_well.dart'.
  final String path;

  /// The line and column info, like '1222:21'.
  final String lineCol;

  const ParsedStackFrame({
    required this.index,
    required this.symbol,
    required this.packagePrefix,
    required this.path,
    required this.lineCol,
  });

  /// Reconstructs the full location string if needed.
  String get fullLocation =>
      '$packagePrefix$path${lineCol.isNotEmpty ? ' $lineCol' : ''}';
}

// ── Internal parsing helpers ───────────────────────────────────────────────

/// Splits a raw location string into its constituent parts.
(String, String, String) _splitLocation(String raw) {
  final match = _StackRegex.locationSplitter.firstMatch(raw);
  if (match == null) return ('', raw, '');

  final prefix = match.group(1) ?? '';
  final path = match.group(2) ?? '';
  final lineCol = match.group(3) ?? '';

  return (prefix, path, lineCol);
}

bool _shouldDiscard(String line) {
  final d = _StackRegex.device.matchAsPrefix(line);
  if (d != null) {
    final seg = d.group(2)!;
    return seg.startsWith('package:logger') || _isExcluded(seg);
  }
  final w = _StackRegex.discardWeb.matchAsPrefix(line);
  if (w != null) {
    final seg = w.group(1)!;
    return seg.startsWith('packages/logger') ||
        seg.startsWith('dart-sdk/lib') ||
        _isExcluded(seg);
  }
  final b = _StackRegex.discardBrowser.matchAsPrefix(line);
  if (b != null) {
    final seg = b.group(1)!;
    return seg.startsWith('package:logger') ||
        seg.startsWith('dart:') ||
        _isExcluded(seg);
  }
  return false;
}

bool _isExcluded(String _) => false;

List<ParsedStackFrame> _parseFrames(String? stackTrace) {
  if (stackTrace == null || stackTrace.isEmpty) return const [];

  final lines = stackTrace.split('\n');
  final frames = <ParsedStackFrame>[];
  int displayIndex = 0;

  for (final line in lines) {
    if (line.isEmpty || _shouldDiscard(line)) continue;

    final cleanLine = line.replaceFirst(_StackRegex.frameHeader, '').trim();

    // Helper to create a frame with parsed location
    ParsedStackFrame create(String sym, String loc) {
      final (pre, path, lc) = _splitLocation(loc);
      return ParsedStackFrame(
        index: displayIndex++,
        symbol: sym,
        packagePrefix: pre,
        path: path,
        lineCol: lc,
      );
    }

    // 1. Try Device format
    final d = _StackRegex.device.firstMatch(line);
    if (d != null) {
      frames.add(create(d.group(1)!.trim(), d.group(2)!));
      continue;
    }

    // 2. Try V8 format
    final v = _StackRegex.v8.firstMatch(cleanLine);
    if (v != null) {
      frames.add(create(v.group(1)!.trim(), v.group(2)!));
      continue;
    }

    // 3. Try Web Fallback
    final w = _StackRegex.webFallback.firstMatch(cleanLine);
    if (w != null) {
      frames.add(create(w.group(2)!.trim(), w.group(1)!.trim()));
      continue;
    }

    // 4. Final fallback
    frames.add(create('', cleanLine));
  }

  return List.unmodifiable(frames);
}

// ── LogEntry ──────────────────────────────────────────────────────────────

@immutable
class LogEntry {
  static final Map<String, Level> _levelCache = {
    for (final l in Level.values) l.name: l,
  };

  final Level level;
  final DateTime time;
  final String? errorString;
  final String? stackTraceString;
  final String id;
  final String isolateId;
  final String isolateName;

  final Object? _rawMessage;
  final Object? _preParsedJson;

  late final String messageString = _formatMessage(_rawMessage);
  late final String messageLower = messageString.toLowerCase();
  late final String? errorLower = errorString?.toLowerCase();
  late final List<ParsedStackFrame> parsedStackFrames = _parseFrames(
    stackTraceString,
  );
  late final String colonTime = time.colonTime;
  late final Color levelColor = level.color;
  late final String levelLabel = level.label;
  late final bool isErrorOrFatal = level == Level.error || level == Level.fatal;
  late final Object? parsedJson =
      _preParsedJson ?? _tryParseJson(messageString);

  LogEntry({
    required this.level,
    required this.time,
    this.errorString,
    this.stackTraceString,
    required this.id,
    required this.isolateId,
    required this.isolateName,
    required Object? rawMessage,
    required Object? preParsedJson,
  }) : _rawMessage = rawMessage,
       _preParsedJson = preParsedJson;

  factory LogEntry.fromJson(
    Map<String, dynamic> json, {
    String? isolateId,
    String? isolateName,
  }) {
    final rawLevel = json['level'] as String? ?? '';
    final level = _levelCache[rawLevel] ?? Level.info;
    final time = DateTime.fromMillisecondsSinceEpoch(json['time'] as int? ?? 0);
    final rawMessage = json['message'];

    // We use a stable ID based on raw data to avoid early formatting.
    final id =
        '${time.millisecondsSinceEpoch}_${level.name}_${rawMessage.hashCode}';

    return LogEntry(
      level: level,
      time: time,
      errorString: json['error']?.toString(),
      stackTraceString: json['stackTrace']?.toString(),
      id: id,
      isolateId: isolateId ?? 'unknown',
      isolateName: isolateName ?? 'unknown',
      rawMessage: rawMessage,
      preParsedJson: rawMessage is Map || rawMessage is List
          ? rawMessage
          : null,
    );
  }

  static String _formatMessage(Object? msg) {
    if (msg == null) return '';
    if (msg is String) return msg.trim();
    if (msg is Map || msg is List) {
      try {
        // Formats JSON with indents for detail views, but only when accessed.
        return const JsonEncoder.withIndent('  ').convert(msg);
      } catch (_) {
        return msg.toString();
      }
    }
    return msg.toString();
  }

  static Object? _tryParseJson(String src) {
    if (src.length < 2) return null;

    int firstChar = -1;
    for (int i = 0; i < src.length; i++) {
      final code = src.codeUnitAt(i);
      // Skip whitespace: space (32), tab (9), newline (10), carriage return (13)
      if (code == 32 || code == 9 || code == 10 || code == 13) continue;
      firstChar = code;
      break;
    }

    if (firstChar != 123 && firstChar != 91) return null;

    try {
      final decoded = jsonDecode(src);
      return (decoded is Map || decoded is List) ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

extension on DateTime {
  String get colonTime {
    final local = toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
