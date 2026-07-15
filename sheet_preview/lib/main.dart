import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'sheet_data.dart';

/// The public demo sheet from the package README.
const kDemoSheetId = '1wcpxwGviymes945LdxBDyRobCxKp0NW3QFE11sFdGAM';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(800, 600));
  runApp(const SheetPreviewApp());
}

class SheetPreviewApp extends StatelessWidget {
  const SheetPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GSheet Localization Preview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF188038)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF34A853),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _idController = TextEditingController(text: kDemoSheetId);
  final _searchController = TextEditingController();
  final _hScrollController = ScrollController();
  final _vScrollController = ScrollController();

  SheetTable? _table;
  List<PreviewEntry> _entries = [];
  PreviewEntry? _selected;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _idController.dispose();
    _searchController.dispose();
    _hScrollController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docId = SheetService.extractDocId(_idController.text);
      final table = await SheetService.fetch(docId);
      setState(() {
        _table = table;
        _entries = table.entries;
        _selected = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectRowKey(String rowKey) {
    final parts = rowKey.split('.');
    final isPluralRow = parts.length > 1 && kPluralForms.contains(parts.last);
    final base =
        isPluralRow ? parts.sublist(0, parts.length - 1).join('.') : rowKey;
    final entry = _entries.where((e) => e.key == base).firstOrNull;
    setState(() => _selected = entry);
  }

  bool _rowMatchesSelection(String rowKey) {
    final selected = _selected;
    if (selected == null) return false;
    if (rowKey == selected.key) return true;
    final parts = rowKey.split('.');
    return parts.length > 1 &&
        kPluralForms.contains(parts.last) &&
        parts.sublist(0, parts.length - 1).join('.') == selected.key;
  }

  List<SheetRow> get _filteredRows {
    final table = _table;
    if (table == null) return const [];
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return table.rows;
    return table.rows
        .where((row) =>
            row.key.toLowerCase().contains(query) ||
            row.values.any((v) => v.toLowerCase().contains(query)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(theme),
          if (_error != null) _buildErrorBanner(theme),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTableArea(theme)),
                if (_selected != null)
                  PlaygroundPanel(
                    key: ValueKey(_selected!.key),
                    entry: _selected!,
                    onClose: () => setState(() => _selected = null),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Icon(Icons.table_chart_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _idController,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  labelText: 'Google Sheet ID or URL',
                  hintText:
                      'e.g. 1wcpxwGviymes945LdxBDyRobCxKp0NW3QFE11sFdGAM',
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _load,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_loading ? 'Loading…' : 'Load'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(ThemeData theme) {
    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableArea(ThemeData theme) {
    final table = _table;
    if (table == null) {
      return Center(
        child: _loading
            ? const CircularProgressIndicator()
            : const Text('Enter a sheet ID and press Load'),
      );
    }

    final rows = _filteredRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(),
                    hintText: 'Filter keys or values',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '${rows.length} rows · ${table.locales.length} locales',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // The hint is pointless (and space-starved) once the
                // playground panel is open, so drop it entirely then.
                child: _selected == null
                    ? Text(
                        'Click a row to open the playground →',
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall!
                            .copyWith(color: theme.colorScheme.outline),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _hScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _hScrollController,
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                controller: _vScrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowColor: WidgetStatePropertyAll(
                      theme.colorScheme.surfaceContainerHigh),
                  columns: [
                    const DataColumn(
                        label: Text('Key',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    for (final locale in table.locales)
                      DataColumn(
                          label: Text(locale,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                  ],
                  rows: [
                    for (final row in rows)
                      DataRow(
                        selected: _rowMatchesSelection(row.key),
                        onSelectChanged: (_) => _selectRowKey(row.key),
                        cells: [
                          DataCell(Text(
                            row.key,
                            style: TextStyle(
                              fontFamily: 'Menlo',
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                            ),
                          )),
                          for (final value in row.values)
                            DataCell(
                              Tooltip(
                                message: value,
                                waitDuration: const Duration(seconds: 1),
                                child: SizedBox(
                                  width: 200,
                                  child: Text(
                                    value,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Right-hand panel: input values for a key's args ({name}, {} and plural
/// count) and see the resolved string per locale.
class PlaygroundPanel extends StatefulWidget {
  const PlaygroundPanel(
      {super.key, required this.entry, required this.onClose});

  final PreviewEntry entry;
  final VoidCallback onClose;

  @override
  State<PlaygroundPanel> createState() => _PlaygroundPanelState();
}

class _PlaygroundPanelState extends State<PlaygroundPanel> {
  final _countController = TextEditingController(text: '1');
  late final Map<String, TextEditingController> _namedControllers = {
    for (final arg in widget.entry.namedArgs) arg: TextEditingController(),
  };
  late final List<TextEditingController> _positionalControllers = [
    for (var i = 0; i < widget.entry.positionalCount; i++)
      TextEditingController(),
  ];

  @override
  void dispose() {
    _countController.dispose();
    for (final controller in _namedControllers.values) {
      controller.dispose();
    }
    for (final controller in _positionalControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  num get _count => num.tryParse(_countController.text.trim()) ?? 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SizedBox(
        width: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontFamily: 'Menlo',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                children: [
                  if (entry.isPlural)
                    Chip(
                      label: const Text('plural'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.tertiaryContainer,
                    ),
                  for (final arg in entry.namedArgs)
                    Chip(
                      label: Text('{$arg}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (entry.positionalCount > 0)
                    Chip(
                      label: Text('{} ×${entry.positionalCount}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (entry.hasArgs) ...[
                    Text('TRY IT', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 8),
                    if (entry.isPlural)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: _countController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            labelText: 'count (plural)',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    for (final arg in entry.namedArgs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: _namedControllers[arg],
                          decoration: InputDecoration(
                            isDense: true,
                            border: const OutlineInputBorder(),
                            labelText: '{$arg}',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    for (var i = 0; i < _positionalControllers.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: _positionalControllers[i],
                          decoration: InputDecoration(
                            isDense: true,
                            border: const OutlineInputBorder(),
                            labelText: '{} #${i + 1}',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    const Divider(height: 24),
                  ],
                  Text('PREVIEW', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 8),
                  for (final locale in entry.locales)
                    _buildPreviewCard(theme, entry, locale),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
      ThemeData theme, PreviewEntry entry, String locale) {
    final resolved = entry.resolve(
      locale,
      count: _count,
      named: {
        for (final e in _namedControllers.entries) e.key: e.value.text,
      },
      positional: [for (final c in _positionalControllers) c.text],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  locale,
                  style: theme.textTheme.labelMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                if (resolved.form != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '.${resolved.form}',
                      style: theme.textTheme.labelSmall!.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              resolved.text,
              style: resolved.missing
                  ? theme.textTheme.bodyMedium!.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.outline,
                    )
                  : theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
