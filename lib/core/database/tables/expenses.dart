import 'package:drift/drift.dart';

import 'accounts.dart';
import 'payments.dart';

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get expenseNumber => text().withLength(min: 1, max: 100)();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  DateTimeColumn get expenseDate =>
      dateTime().clientDefault(() => DateTime.now())();
  IntColumn get amount => integer()();
  TextColumn get category => text()();
  TextColumn get description => text().nullable()();
  IntColumn get paymentId => integer().nullable().references(Payments, #id)();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
