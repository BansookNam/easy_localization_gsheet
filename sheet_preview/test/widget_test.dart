import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_preview/sheet_data.dart';

void main() {
  const csv = 'str,en_US,ko_KR\r\n'
      'title,Hello,안녕\r\n'
      'clicked.one,You clicked {count} time!,{count}번 클릭!\r\n'
      'clicked.other,You clicked {count} times!,{count}번 클릭!\r\n'
      'amount.other,Your amount : {},금액 : {}\r\n'
      'msg,Hello {name} in {type},{type}의 {name}님 안녕하세요\r\n';

  test('parses locales and rows', () {
    final table = SheetTable.fromCsv(csv);
    expect(table.locales, ['en_US', 'ko_KR']);
    expect(table.rows.length, 5);
  });

  test('groups plural forms into one entry', () {
    final entries = SheetTable.fromCsv(csv).entries;
    expect(entries.map((e) => e.key), ['title', 'clicked', 'amount', 'msg']);
    final clicked = entries[1];
    expect(clicked.isPlural, isTrue);
    expect(clicked.namedArgs, ['count']);
  });

  test('resolves plural form and named args', () {
    final clicked = SheetTable.fromCsv(csv).entries[1];
    final one = clicked.resolve('en_US', count: 1, named: {'count': '1'});
    expect(one.form, 'one');
    expect(one.text, 'You clicked 1 time!');
    final many = clicked.resolve('en_US', count: 5, named: {'count': '5'});
    expect(many.form, 'other');
    expect(many.text, 'You clicked 5 times!');
  });

  test('fills positional {} with count for plurals', () {
    final amount = SheetTable.fromCsv(csv).entries[2];
    final resolved = amount.resolve('en_US', count: 42);
    expect(resolved.text, 'Your amount : 42');
  });

  test('resolves named args for simple keys', () {
    final msg = SheetTable.fromCsv(csv).entries[3];
    final resolved =
        msg.resolve('ko_KR', named: {'name': 'Nam', 'type': 'Flutter'});
    expect(resolved.text, 'Flutter의 Nam님 안녕하세요');
  });

  test('extracts doc id from a full URL', () {
    expect(
      SheetService.extractDocId(
          'https://docs.google.com/spreadsheets/d/1wcpxwGviymes945LdxBDyRobCxKp0NW3QFE11sFdGAM/edit?usp=sharing'),
      '1wcpxwGviymes945LdxBDyRobCxKp0NW3QFE11sFdGAM',
    );
    expect(SheetService.extractDocId(' abc123 '), 'abc123');
  });
}
