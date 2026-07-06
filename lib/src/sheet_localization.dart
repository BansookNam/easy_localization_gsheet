class SheetLocalization {
  /// Optional. If null then the local file (outName) will be used
  final String? docId;
  final String lineSeparator;
  final int version;
  final String outDir; //output directory
  final String outName; //output file name
  final List<String> preservedKeywords;
  final bool injectGenerationDateTime;
  final bool immediateTranslationEnabled;

  /// If true, also writes one JSON translation file per sheet locale column
  /// (e.g. `en_US` -> `en.json`) into [translationsOutDir], for consumption
  /// by easy_localization's default asset loader.
  final bool generateTranslationFiles;

  /// Output directory for the per-locale JSON files written when
  /// [generateTranslationFiles] is true.
  final String translationsOutDir;

  const SheetLocalization({
    this.docId,
    this.version = 1,
    this.outDir = 'resources/langs',
    this.lineSeparator = '\n',
    this.outName = 'langs.csv',
    this.preservedKeywords = const [],
    this.injectGenerationDateTime = true,
    this.immediateTranslationEnabled = true,
    this.generateTranslationFiles = false,
    this.translationsOutDir = 'assets/translations',
  });
}
