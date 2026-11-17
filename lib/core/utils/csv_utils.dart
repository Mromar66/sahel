/// Escapes a CSV cell and prevents spreadsheet formula execution on open.
///
/// Text values beginning with a formula operator are prefixed with an apostrophe
/// so Excel treats them as text. Negative numeric values remain numeric.
String escapeCsvCellForSpreadsheet(String value) {
  final trimmed = value.trimLeft();
  final isNegativeNumber = RegExp(r'^-\d+(?:[.,]\d+)?$').hasMatch(value.trim());
  final formulaLike =
      trimmed.startsWith('=') ||
      trimmed.startsWith('+') ||
      trimmed.startsWith('@') ||
      (trimmed.startsWith('-') && !isNegativeNumber) ||
      value.startsWith('\t') ||
      value.startsWith('\r');
  final safeValue = formulaLike ? "'$value" : value;
  return '"${safeValue.replaceAll('"', '""')}"';
}
