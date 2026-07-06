import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';

import 'package:easy_localization_gsheet_annotation/easy_localization_gsheet_annotation.dart';

import 'csv_parser.dart';

class LocalizationGenerator extends GeneratorForAnnotation<SheetLocalization> {
  static const _urlFormat =
      'https://docs.google.com/spreadsheets/export?format=csv&id=';
  static const _headers = {
    'Content-Type': 'text/csv; charset=utf-8',
    'Accept': '*/*'
  };

  @override
  FutureOr<String> generateForAnnotatedElement(
          Element element, ConstantReader annotation, BuildStep buildStep) =>
      _generateSource(element, annotation);

  Future<String> _generateSource(
      Element element, ConstantReader annotation) async {
    final lineSeparator = annotation.read('lineSeparator').stringValue;
    final docId = annotation.read('docId');
    final outputDir = annotation.read('outDir').stringValue;
    final outputFileName = annotation.read('outName').stringValue;
    final injectGenerationDateTime =
        annotation.read('injectGenerationDateTime').boolValue;
    final immediateTranslationEnabled =
        annotation.read('immediateTranslationEnabled').boolValue;

    final preservedKeywords = annotation
        .read('preservedKeywords')
        .listValue
        .map((e) => e.toStringValue())
        .toList();
    final generateTranslationFiles =
        annotation.read('generateTranslationFiles').boolValue;
    final translationsOutDir =
        annotation.read('translationsOutDir').stringValue;
    final current = Directory.current;
    final output = Directory.fromUri(Uri.parse(outputDir));
    final outputPath =
        Directory(path.join(current.path, output.path, outputFileName));

    final classBuilder = StringBuffer();
    if (injectGenerationDateTime) {
      classBuilder.writeln(
          '// Generated at: ${formatDateWithOffset(DateTime.now().toLocal())}');
    }

    classBuilder.writeln('class ${element.displayName.substring(1)}{');

    void readCsv(File file) {
      final data = file.readAsStringSync();
      final csvParser = CSVParser(LineSplitter().convert(data).join("\r\n"));
      classBuilder.writeln(csvParser.getSupportedLocales());
      classBuilder.writeln(csvParser.generateTranslationUsages(
          preservedKeywords, immediateTranslationEnabled));

      if (generateTranslationFiles) {
        _writeTranslationFiles(csvParser, current, translationsOutDir);
      }
    }

    if (docId.isNull || docId.stringValue.isEmpty) {
      print("docId is null, going to use the file ${outputPath.path}");
      final localFile = File(outputPath.path);
      if (!localFile.existsSync()) {
        throw Exception('File missing, path: ${outputPath.path}');
      }

      readCsv(localFile);
    } else {
      final response = await http.get(Uri.parse(_urlFormat + docId.stringValue),
          headers: _headers);
      if (response.statusCode != 200) {
        throw Exception('http reasonPhrase: ${response.reasonPhrase}');
      }

      final generatedFile = File(outputPath.path);
      if (!generatedFile.existsSync()) {
        generatedFile.createSync(recursive: true);
      }

      generatedFile.writeAsBytesSync(response.bodyBytes);

      final formatString = LineSplitter()
          .convert(generatedFile.readAsStringSync())
          .join(lineSeparator);

      generatedFile.writeAsStringSync(formatString);

      readCsv(generatedFile);
    }
    classBuilder.writeln('}');
    return classBuilder.toString();
  }

  void _writeTranslationFiles(
      CSVParser csvParser, Directory current, String translationsOutDir) {
    final translationsDir =
        Directory(path.join(current.path, translationsOutDir));
    if (!translationsDir.existsSync()) {
      translationsDir.createSync(recursive: true);
    }

    const encoder = JsonEncoder.withIndent('  ');
    csvParser.buildLocaleTranslations().forEach((code, translations) {
      final language = code.split('_').first;
      final file = File(path.join(translationsDir.path, '$language.json'));
      file.writeAsStringSync(encoder.convert(translations));
    });
  }

  String formatDateWithOffset(DateTime date,
      {String format = 'EEE, dd MMM yyyy HH:mm:ss'}) {
    String twoDigits(int n) => n >= 10 ? "$n" : "0$n";

    final hours = twoDigits(date.timeZoneOffset.inHours.abs());
    final minutes = twoDigits(date.timeZoneOffset.inMinutes.remainder(60));
    final sign = date.timeZoneOffset.inHours > 0 ? "+" : "-";
    final formattedDate = DateFormat(format).format(date);

    return "$formattedDate $sign$hours:$minutes";
  }
}
