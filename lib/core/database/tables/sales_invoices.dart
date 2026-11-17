import 'package:drift/drift.dart';

import 'customers.dart';

class SalesInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().withLength(min: 1, max: 100)();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  DateTimeColumn get invoiceDate =>
      dateTime().clientDefault(() => DateTime.now())();
  IntColumn get subtotal => integer()();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get tax => integer().withDefault(const Constant(0))();
  IntColumn get total => integer()();
  IntColumn get paidAmount => integer().withDefault(const Constant(0))();
  IntColumn get remainingAmount => integer()();
  TextColumn get paymentStatus => text()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isReturn => boolean().withDefault(const Constant(false))();
  IntColumn get originalInvoiceId => integer().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
