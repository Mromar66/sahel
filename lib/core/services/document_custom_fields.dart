import 'package:sqlite3/sqlite3.dart';

import 'package:safwa/core/services/database_service.dart';

class DocumentTypes {
  DocumentTypes._();

  static const sale = 'sale';
  static const salesReturn = 'sales_return';
  static const purchase = 'purchase';
  static const purchaseReturn = 'purchase_return';
  static const quotation = 'quotation';
  static const receipt = 'receipt';
  static const payment = 'payment';
  static const stocktaking = 'stocktaking';
  static const warehouseAdjustment = 'warehouse_adjustment';
  static const warehouseTransfer = 'warehouse_transfer';
  static const treasuryReceive = 'treasury_receive';
  static const treasuryExpense = 'treasury_expense';
  static const treasuryTransfer = 'treasury_transfer';
  static const check = 'check';
}

/// Stores additional document values beside the existing business rows.
/// The document id is polymorphic, so a field definition applies to every
/// document type without changing historical invoice or payment columns.
class DocumentCustomFields {
  DocumentCustomFields._();

  static Database get _db => DatabaseService().database.db;

  static List<Map<String, Object?>> definitions({
    bool activeOnly = true,
    String scope = 'document',
  }) {
    final rows = _db.select(
      'SELECT id,name,is_active,sort_order FROM document_custom_fields '
      'WHERE scope=? ${activeOnly ? 'AND is_active=1 ' : ''}ORDER BY sort_order,id',
      [scope],
    );
    return rows.map((row) => Map<String, Object?>.from(row)).toList();
  }

  static Map<int, String> values(String documentType, int documentId) {
    final rows = _db.select(
      'SELECT field_id,value FROM document_custom_values '
      'WHERE document_type=? AND document_id=?',
      [documentType, documentId],
    );
    return {
      for (final row in rows) row['field_id'] as int: row['value'] as String,
    };
  }

  static Map<int, String> entityValues(String scope, int entityId) {
    final rows = _db.select(
      'SELECT field_id,value FROM entity_custom_values WHERE scope=? AND entity_id=?',
      [scope, entityId],
    );
    return {
      for (final row in rows)
        (row['field_id'] as num).toInt(): '${row['value'] ?? ''}',
    };
  }

  static Map<int, String> lineValues(
    String documentType,
    int documentId,
    int lineId,
  ) {
    final rows = _db.select(
      'SELECT field_id,value FROM document_custom_line_values '
      'WHERE document_type=? AND document_id=? AND line_id=?',
      [documentType, documentId, lineId],
    );
    return {
      for (final row in rows)
        (row['field_id'] as num).toInt(): '${row['value'] ?? ''}',
    };
  }

  /// Call inside the owning document's transaction so field values and the
  /// business document either commit together or roll back together.
  static void saveValues(
    String documentType,
    int documentId,
    Map<int, String> values,
  ) {
    final now = DateTime.now().toIso8601String();
    for (final entry in values.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) {
        _db.execute(
          'DELETE FROM document_custom_values WHERE document_type=? AND document_id=? AND field_id=?',
          [documentType, documentId, entry.key],
        );
        continue;
      }
      _db.execute(
        'INSERT INTO document_custom_values(document_type,document_id,field_id,value,updated_at) '
        'VALUES(?,?,?,?,?) ON CONFLICT(document_type,document_id,field_id) '
        'DO UPDATE SET value=excluded.value,updated_at=excluded.updated_at',
        [documentType, documentId, entry.key, value, now],
      );
    }
  }

  static void saveEntityValues(
    String scope,
    int entityId,
    Map<int, String> values,
  ) {
    final now = DateTime.now().toIso8601String();
    for (final entry in values.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) {
        _db.execute(
          'DELETE FROM entity_custom_values WHERE scope=? AND entity_id=? AND field_id=?',
          [scope, entityId, entry.key],
        );
      } else {
        _db.execute(
          'INSERT INTO entity_custom_values(scope,entity_id,field_id,value,updated_at) '
          'VALUES(?,?,?,?,?) ON CONFLICT(scope,entity_id,field_id) '
          'DO UPDATE SET value=excluded.value,updated_at=excluded.updated_at',
          [scope, entityId, entry.key, value, now],
        );
      }
    }
  }

  static void saveLineValues(
    String documentType,
    int documentId,
    int lineId,
    Map<int, String> values,
  ) {
    final now = DateTime.now().toIso8601String();
    for (final entry in values.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) {
        _db.execute(
          'DELETE FROM document_custom_line_values '
          'WHERE document_type=? AND document_id=? AND line_id=? AND field_id=?',
          [documentType, documentId, lineId, entry.key],
        );
        continue;
      }
      _db.execute(
        'INSERT INTO document_custom_line_values '
        '(document_type,document_id,line_id,field_id,value,updated_at) '
        'VALUES(?,?,?,?,?,?) ON CONFLICT(document_type,document_id,line_id,field_id) '
        'DO UPDATE SET value=excluded.value,updated_at=excluded.updated_at',
        [documentType, documentId, lineId, entry.key, value, now],
      );
    }
  }
}
