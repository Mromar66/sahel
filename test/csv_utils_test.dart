import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/core/utils/csv_utils.dart';

void main() {
  test('quotes CSV cells and escapes embedded quotes', () {
    expect(escapeCsvCellForSpreadsheet('Product, "A"'), '"Product, ""A"""');
  });

  test('neutralizes spreadsheet formulas in text cells', () {
    expect(escapeCsvCellForSpreadsheet('=1+1'), '"\'=1+1"');
    expect(escapeCsvCellForSpreadsheet('  @SUM(A1:A2)'), '"\'  @SUM(A1:A2)"');
    expect(escapeCsvCellForSpreadsheet('\t=cmd'), '"\'\t=cmd"');
  });

  test('keeps negative numeric values as numbers', () {
    expect(escapeCsvCellForSpreadsheet('-12.5'), '"-12.5"');
    expect(escapeCsvCellForSpreadsheet('-product'), '"\'-product"');
  });
}
