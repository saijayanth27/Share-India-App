import 'dart:convert';
import 'dart:io';

String _unescapeDartSingleQuoted(String value) {
  return value
      .replaceAll(r"\\'", "'")
      .replaceAll(r'\\n', '\n')
      .replaceAll(r'\\r', '\r')
      .replaceAll(r'\\t', '\t')
      .replaceAll(r'\\\\', '\\');
}

void main() {
  final source = File('lib/language_provider.dart').readAsStringSync();
  const startMarker = 'const Map<String, String> _translations = {';
  final start = source.indexOf(startMarker);
  if (start == -1) {
    stderr.writeln('Translation map start not found.');
    exitCode = 1;
    return;
  }

  final bodyStart = source.indexOf('{', start) + 1;
  final end = source.indexOf('\n};', bodyStart);
  if (end == -1) {
    stderr.writeln('Translation map end not found.');
    exitCode = 1;
    return;
  }

  final body = source.substring(bodyStart, end);
  final entryPattern = RegExp(
    r"'((?:\\.|[^'])*)'\s*:\s*'((?:\\.|[^'])*)'",
    multiLine: true,
    dotAll: true,
  );

  final en = <String, String>{};
  final te = <String, String>{};

  for (final match in entryPattern.allMatches(body)) {
    final english = _unescapeDartSingleQuoted(match.group(1)!);
    final telugu = _unescapeDartSingleQuoted(match.group(2)!);
    en[english] = english;
    te[english] = telugu;
  }

  final outputDir = Directory('assets/i18n')..createSync(recursive: true);
  File('${outputDir.path}/en.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(en));
  File('${outputDir.path}/te.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(te));

  stdout.writeln('Exported ${en.length} translations to ${outputDir.path}.');
}
