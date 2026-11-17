import 'package:drift/drift.dart';

import 'accounts.dart';

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get paymentNumber => text().withLength(min: 1, max: 100)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  DateTimeColumn get paymentDate =>
      dateTime().clientDefault(() => DateTime.now())();
  IntColumn get amount => integer()();
  TextColumn get paymentType => text()();
  TextColumn get paymentMethod => text()();
  TextColumn get description => text().nullable()();
  IntColumn get referenceId => integer().nullable()();
  TextColumn get referenceType => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
