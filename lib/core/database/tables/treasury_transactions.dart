import 'package:drift/drift.dart';

class TreasuryTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get transactionNumber => text().withLength(min: 1, max: 100)();
  DateTimeColumn get transactionDate =>
      dateTime().clientDefault(() => DateTime.now())();
  IntColumn get amount => integer()();
  TextColumn get transactionType => text()();
  TextColumn get description => text().nullable()();
  IntColumn get referenceId => integer().nullable()();
  TextColumn get referenceType => text().nullable()();
  IntColumn get balanceAfter => integer()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
