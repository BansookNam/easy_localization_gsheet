# easy_localization_gsheet_annotation

[![Pub](https://img.shields.io/pub/v/easy_localization_gsheet_annotation.svg)](https://pub.dev/packages/easy_localization_gsheet_annotation)

Annotation package for [easy_localization_gsheet](https://github.com/BansookNam/easy_localization_gsheet), a tool that downloads a Google Sheet as CSV and generates localization keys for use with [easy_localization](https://pub.dev/packages/easy_localization).

This package only contains the `@SheetLocalization` annotation used to configure code generation. It has no build-time dependencies, so it's safe to add as a regular (non-dev) dependency of your app.

## Usage

You normally don't depend on this package directly — it's re-exported by `easy_localization_gsheet`. Import it from there and annotate a class with `@SheetLocalization`:

```dart
import 'package:easy_localization_gsheet/easy_localization_gsheet.dart';

part 'strings.g.dart';

@SheetLocalization(
  docId: 'DOCID',
  version: 1,
  outDir: 'assets/langs',
  outName: 'langs.csv',
)
class _Strings {}
```

See the [easy_localization_gsheet README](https://github.com/BansookNam/easy_localization_gsheet) for full setup instructions, including how to prepare the Google Sheet and run the code generator.

## `SheetLocalization` options

| Parameter | Default | Description |
| --- | --- | --- |
| `docId` | `null` | Google Sheet document ID. If `null`, the local file at `outDir/outName` is used instead. |
| `version` | `1` | Increment to force regeneration; the generator caches by version. |
| `outDir` | `'resources/langs'` | Directory the downloaded CSV is saved to. |
| `outName` | `'langs.csv'` | File name for the downloaded CSV. |
| `lineSeparator` | `'\n'` | Line separator used when parsing/writing the CSV. |
| `preservedKeywords` | `[]` | Keywords (e.g. plural forms `one`, `many`, `other`) preserved during generation. |
| `injectGenerationDateTime` | `true` | Whether to add a generation timestamp comment to the generated file. |
| `immediateTranslationEnabled` | `true` | Whether to enable immediate (eager) translation lookups. |
| `generateTranslationFiles` | `false` | If `true`, also writes one JSON translation file per sheet locale column (e.g. `en_US` -> `en.json`) into `translationsOutDir`, for consumption by easy_localization's default asset loader. |
| `translationsOutDir` | `'assets/translations'` | Output directory for the per-locale JSON files written when `generateTranslationFiles` is `true`. |

## Related

- [easy_localization_gsheet](https://github.com/BansookNam/easy_localization_gsheet) — the parent package and code generator that consumes this annotation.
