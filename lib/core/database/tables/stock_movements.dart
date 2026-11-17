import 'package:drift/drift.dart';

import 'products.dart';
import 'warehouses.dart';

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  TextColumn get movementType => text()();
  IntColumn get referenceId => integer().nullable()();
  TextColumn get referenceType => text().nullable()();
  IntColumn get fromWarehouseId =>
      integer().nullable().references(Warehouses, #id)();
  IntColumn get toWarehouseId =>
      integer().nullable().references(Warehouses, #id)();
  DateTimeColumn get movementDate =>
      dateTime().clientDefault(() => DateTime.now())();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
