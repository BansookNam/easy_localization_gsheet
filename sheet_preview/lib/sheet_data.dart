import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// Plural suffixes recognized by easy_localization_gsheet
/// (see CSVParser._checkIsPluralKey in the main package).
const kPluralForms = ['zero', 'one', 'two', 'few', 'many', 'other'];

/// Fetches the sheet CSV exactly like the main package's
/// LocalizationGenerator does, so the preview matches the generator input.
class SheetService {
  static const _urlFormat =
      'https://docs.google.com/spreadsheets/export?format=csv&id=';
  static const _headers = {
    'Content-Type': 'text/csv; charset=utf-8',
    'Accept': '*/*',
  };

  /// Accepts either a bare doc id or a full
  /// `https://docs.google.com/spreadsheets/d/<id>/...` URL.
  static String extractDocId(String input) {
    final match = RegExp(r'/d/([a-zA-Z0-9\-_]+)').firstMatch(input);
    return match?.group(1) ?? input.trim();
  }

  static Future<SheetTable> fetch(String docId) async {
    final response =
        await http.get(Uri.parse('$_urlFormat$docId'), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'request failed'}');
    }
    return SheetTable.fromCsv(utf8.decode(response.bodyBytes));
  }
}

class SheetRow {
  const SheetRow({required this.key, required this.values});

  final String key;

  /// Aligned with [SheetTable.locales]; short rows are padded with ''.
  final List<String> values;
}

class SheetTable {
  SheetTable({required this.locales, required this.rows});

  /// Locale column headers, e.g. ['en_US', 'zh_TW'].
  final List<String> locales;
  final List<SheetRow> rows;

  factory SheetTable.fromCsv(String data) {
    // Same normalization as the generator: split lines, join with \r\n.
    final normalized = const LineSplitter().convert(data).join('\r\n');
    final lines = const CsvToListConverter().convert(normalized);
    if (lines.isEmpty || lines.first.length < 2) {
      throw Exception('Sheet is empty or has no locale columns');
    }

    final locales =
        lines.first.sublist(1).map((e) => e.toString()).toList();
    final rows = <SheetRow>[];
    for (final line in lines.skip(1)) {
      final key = line.first.toString();
      if (key.isEmpty) continue;
      final values = List.generate(locales.length,
          (i) => i + 1 < line.length ? line[i + 1].toString() : '');
      rows.add(SheetRow(key: key, values: values));
    }
    return SheetTable(locales: locales, rows: rows);
  }

  /// Groups `key.zero` / `key.one` / ... rows into a single plural entry;
  /// every other row becomes a simple entry. Sheet order is preserved.
  List<PreviewEntry> get entries {
    // base key -> locale -> form -> raw value ('' form = non-plural value)
    final groups = <String, Map<String, Map<String, String>>>{};
    final order = <String>[];

    for (final row in rows) {
      final parts = row.key.split('.');
      final isPluralRow = parts.length > 1 && kPluralForms.contains(parts.last);
      final base =
          isPluralRow ? parts.sublist(0, parts.length - 1).join('.') : row.key;
      final form = isPluralRow ? parts.last : '';

      final group = groups.putIfAbsent(base, () {
        order.add(base);
        return {};
      });
      for (var i = 0; i < locales.length; i++) {
        group.putIfAbsent(locales[i], () => {})[form] = row.values[i];
      }
    }

    return [
      for (final base in order)
        PreviewEntry(
          key: base,
          locales: locales,
          formsByLocale: groups[base]!,
        ),
    ];
  }
}

class ResolvedPreview {
  const ResolvedPreview({required this.text, this.form, this.missing = false});

  final String text;

  /// The plural form that was chosen, or null for non-plural entries.
  final String? form;
  final bool missing;
}

/// One logical localization key: either a simple value per locale, or a
/// group of plural forms per locale.
class PreviewEntry {
  PreviewEntry({
    required this.key,
    required this.locales,
    required this.formsByLocale,
  });

  final String key;
  final List<String> locales;

  /// locale -> (plural form -> raw value). Non-plural values use the '' form.
  final Map<String, Map<String, String>> formsByLocale;

  late final bool isPlural = formsByLocale.values
      .any((forms) => forms.keys.any((form) => form.isNotEmpty));

  /// Union of `{name}` placeholders across every locale and form. Locales
  /// sometimes disagree (e.g. a translated `{Name}`) — surfacing the union
  /// makes those sheet mistakes visible in the playground.
  late final List<String> namedArgs = () {
    final args = <String>{};
    for (final forms in formsByLocale.values) {
      for (final value in forms.values) {
        for (final match in RegExp(r'\{([^{}]+)\}').allMatches(value)) {
          args.add(match.group(1)!);
        }
      }
    }
    return args.toList();
  }();

  /// Max number of positional `{}` placeholders in any single value.
  late final int positionalCount = () {
    var max = 0;
    for (final forms in formsByLocale.values) {
      for (final value in forms.values) {
        final count = RegExp(r'\{\}').allMatches(value).length;
        if (count > max) max = count;
      }
    }
    return max;
  }();

  bool get hasArgs => namedArgs.isNotEmpty || positionalCount > 0 || isPlural;

  /// Resolves the entry for [locale], mimicking easy_localization:
  /// plural form via Intl.pluralLogic, `{name}` via namedArgs, and `{}`
  /// filled with the count (plural) or positional inputs.
  ResolvedPreview resolve(
    String locale, {
    num count = 1,
    Map<String, String> named = const {},
    List<String> positional = const [],
  }) {
    final forms = formsByLocale[locale] ?? const {};
    String? formName;
    String? raw;

    if (isPlural) {
      formName = _chooseForm(locale, count, forms);
      raw = forms[formName];
    } else {
      raw = forms[''];
    }

    if (raw == null || raw.isEmpty) {
      return ResolvedPreview(text: '(no value)', form: formName, missing: true);
    }

    var out = raw;
    for (final entry in named.entries) {
      if (entry.value.isNotEmpty) {
        out = out.replaceAll('{${entry.key}}', entry.value);
      }
    }
    if (isPlural) {
      out = out.replaceAll('{}', count.toString());
    } else if (positional.isNotEmpty) {
      var index = 0;
      out = out.replaceAllMapped(RegExp(r'\{\}'), (match) {
        final value = index < positional.length ? positional[index] : '';
        index++;
        return value.isEmpty ? '{}' : value;
      });
    }
    return ResolvedPreview(text: out, form: formName);
  }

  String _chooseForm(String locale, num count, Map<String, String> forms) {
    final language = locale.split('_').first;
    String? available(String form) =>
        (forms[form]?.isNotEmpty ?? false) ? form : null;
    return Intl.pluralLogic<String>(
      count,
      locale: language,
      zero: available('zero'),
      one: available('one'),
      two: available('two'),
      few: available('few'),
      many: available('many'),
      other: 'other',
    );
  }
}
