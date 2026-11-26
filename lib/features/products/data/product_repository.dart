import 'package:safwa/core/database/sqlite_database.dart';
import 'package:safwa/core/services/warehouse_stock.dart';
import 'package:safwa/features/products/domain/product_entity.dart';

/// A single row in the products list with joined lookup names and prices.
class ProductListRow {
  ProductListRow({
    required this.product,
    required this.categoryName,
    required this.unitName,
    required this.avgPurchasePrice,
    required this.lastPurchasePrice,
    required this.totalQuantity,
  });

  final ProductEntity product;
  final String categoryName;
  final String unitName;
  final int avgPurchasePrice;
  final int lastPurchasePrice;
  final int totalQuantity;
}

class ProductRepository {
  ProductRepository._internal() : _db = SqliteDatabase();

  ProductRepository.withDatabase(SqliteDatabase database) : _db = database;

  static final ProductRepository _instance = ProductRepository._internal();
  factory ProductRepository() => _instance;

  final SqliteDatabase _db;

  /// All products joined with category/unit names and purchase price stats,
  /// exactly like the reference products grid.
  Future<List<ProductListRow>> getProductListRows() async {
    final rows = _db.query('''
      SELECT p.*,
             c.name AS category_name,
             u.name AS unit_name,
             COALESCE((SELECT AVG(pi.unit_price) FROM purchase_items pi WHERE pi.product_id = p.id), p.purchase_price) AS avg_purchase,
             COALESCE((SELECT pi.unit_price FROM purchase_items pi WHERE pi.product_id = p.id ORDER BY pi.id DESC LIMIT 1), p.purchase_price) AS last_purchase
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      LEFT JOIN units u ON u.id = p.unit_id
      WHERE p.is_active = 1
      ORDER BY p.id DESC
    ''');
    return rows.map((r) {
      final product = _rowToProduct(r);
      return ProductListRow(
        product: product,
        categoryName: r['category_name'] as String? ?? '',
        unitName: r['unit_name'] as String? ?? '',
        avgPurchasePrice:
            (r['avg_purchase'] as num?)?.round() ?? product.purchasePrice,
        lastPurchasePrice:
            (r['last_purchase'] as num?)?.round() ?? product.purchasePrice,
        totalQuantity: product.currentStock,
      );
    }).toList();
  }

  /// Lookup lists (categories / units / warehouses) for filters and forms.
  Future<List<Map<String, Object?>>> getCategories() async {
    return _db.query('SELECT id, name FROM categories ORDER BY name');
  }

  Future<List<Map<String, Object?>>> getUnits() async {
    return _db.query('SELECT id, name, abbreviation FROM units ORDER BY name');
  }

  Future<List<Map<String, Object?>>> getWarehouses() async {
    return _db.query(
      'SELECT id, name FROM warehouses WHERE is_active = 1 ORDER BY name',
    );
  }

  /// Available + reserved quantity of one product per warehouse.
  Future<List<Map<String, Object?>>> getProductWarehouseStock(
    int productId,
  ) async {
    return WarehouseStock.byProduct(_db, productId);
  }

  /// Stock movements of one product (newest first).
  Future<List<Map<String, Object?>>> getProductMovements(int productId) async {
    return _db.query(
      '''
      SELECT sm.*, w1.name AS from_name, w2.name AS to_name
      FROM stock_movements sm
      LEFT JOIN warehouses w1 ON w1.id = sm.from_warehouse_id
      LEFT JOIN warehouses w2 ON w2.id = sm.to_warehouse_id
      WHERE sm.product_id = ?
      ORDER BY sm.id DESC
    ''',
      [productId],
    );
  }

  Future<List<ProductEntity>> getAllProducts() async {
    final rows = _db.query('SELECT * FROM products WHERE is_active = 1');
    return rows.map((r) => _rowToProduct(r)).toList();
  }

  Future<ProductEntity?> getProductById(int id) async {
    final rows = _db.query('SELECT * FROM products WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _rowToProduct(rows.first);
  }

  Future<List<ProductEntity>> getProductsByCategory(int categoryId) async {
    final rows = _db.query(
      'SELECT * FROM products WHERE category_id = ? AND is_active = 1',
      [categoryId],
    );
    return rows.map((r) => _rowToProduct(r)).toList();
  }

  Future<List<ProductEntity>> getLowStockProducts() async {
    final rows = _db.query(
      'SELECT * FROM products WHERE current_stock <= minimum_stock AND is_active = 1',
    );
    return rows.map((r) => _rowToProduct(r)).toList();
  }

  Future<int> insertProduct(ProductEntity product) async {
    return _db.insert(
      '''INSERT INTO products (name, product_code, barcode, category_id, unit_id, purchase_price, selling_price, selling_price_2, selling_price_3, selling_price_4, current_stock, minimum_stock, code2, other_codes, discount_percent, last_selling_price, last_qty, reorder_point, economic_qty, is_service, quick_family, image_path, is_active, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        product.name,
        product.productCode,
        product.barcode,
        product.categoryId,
        product.unitId,
        product.purchasePrice,
        product.sellingPrice,
        product.sellingPrice2,
        product.sellingPrice3,
        product.sellingPrice4,
        product.currentStock,
        product.minimumStock,
        product.code2,
        product.otherCodes,
        product.discountPercent,
        product.lastSellingPrice,
        product.lastQty,
        product.reorderPoint,
        product.economicQty,
        product.isService ? 1 : 0,
        product.quickFamily ? 1 : 0,
        product.imagePath,
        product.isActive ? 1 : 0,
        product.createdAt?.toIso8601String(),
        product.updatedAt?.toIso8601String(),
      ],
    );
  }

  Future<void> updateProduct(ProductEntity product) async {
    _db.execute(
      '''UPDATE products SET name = ?, product_code = ?, barcode = ?, category_id = ?, unit_id = ?, purchase_price = ?, selling_price = ?, selling_price_2 = ?, selling_price_3 = ?, selling_price_4 = ?, current_stock = ?, minimum_stock = ?, code2 = ?, other_codes = ?, discount_percent = ?, last_selling_price = ?, last_qty = ?, reorder_point = ?, economic_qty = ?, is_service = ?, quick_family = ?, image_path = ?, is_active = ?, updated_at = ? WHERE id = ?''',
      [
        product.name,
        product.productCode,
        product.barcode,
        product.categoryId,
        product.unitId,
        product.purchasePrice,
        product.sellingPrice,
        product.sellingPrice2,
        product.sellingPrice3,
        product.sellingPrice4,
        product.currentStock,
        product.minimumStock,
        product.code2,
        product.otherCodes,
        product.discountPercent,
        product.lastSellingPrice,
        product.lastQty,
        product.reorderPoint,
        product.economicQty,
        product.isService ? 1 : 0,
        product.quickFamily ? 1 : 0,
        product.imagePath,
        product.isActive ? 1 : 0,
        product.updatedAt?.toIso8601String(),
        product.id,
      ],
    );
  }

  Future<void> deleteProduct(int id) async {
    _db.execute('UPDATE products SET is_active = 0 WHERE id = ?', [id]);
  }

  Future<void> updateStock(int productId, int newQuantity) async {
    _db.execute(
      'UPDATE products SET current_stock = ?, updated_at = ? WHERE id = ?',
      [newQuantity, DateTime.now().toIso8601String(), productId],
    );
  }

  Future<void> adjustStock(int productId, int delta) async {
    final current = await getProductById(productId);
    if (current != null) {
      updateStock(productId, current.currentStock + delta);
    }
  }

  ProductEntity _rowToProduct(Map<String, dynamic> r) {
    return ProductEntity(
      id: r['id'] as int?,
      name: r['name'] as String? ?? '',
      productCode: r['product_code'] as String? ?? '',
      barcode: r['barcode'] as String?,
      categoryId: r['category_id'] as int?,
      unitId: r['unit_id'] as int?,
      purchasePrice: r['purchase_price'] as int? ?? 0,
      sellingPrice: r['selling_price'] as int? ?? 0,
      sellingPrice2: r['selling_price_2'] as int? ?? 0,
      sellingPrice3: r['selling_price_3'] as int? ?? 0,
      sellingPrice4: r['selling_price_4'] as int? ?? 0,
      currentStock: r['current_stock'] as int? ?? 0,
      minimumStock: r['minimum_stock'] as int? ?? 0,
      code2: r['code2'] as String?,
      otherCodes: r['other_codes'] as String?,
      discountPercent: r['discount_percent'] as int? ?? 0,
      lastSellingPrice: r['last_selling_price'] as int? ?? 0,
      lastQty: r['last_qty'] as int? ?? 0,
      reorderPoint: r['reorder_point'] as int? ?? 0,
      economicQty: r['economic_qty'] as int? ?? 0,
      isService: (r['is_service'] as int? ?? 0) == 1,
      quickFamily: (r['quick_family'] as int? ?? 0) == 1,
      imagePath: r['image_path'] as String?,
      isActive: (r['is_active'] as int? ?? 1) == 1,
      createdAt: r['created_at'] != null
          ? DateTime.parse(r['created_at'])
          : null,
      updatedAt: r['updated_at'] != null
          ? DateTime.parse(r['updated_at'])
          : null,
    );
  }
}
