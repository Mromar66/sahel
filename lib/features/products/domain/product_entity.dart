/// Domain entity for a product.
class ProductEntity {
  final int? id;
  final String name;
  final String productCode;
  final String? barcode;
  final int? categoryId;
  final int? unitId;
  final int purchasePrice; // stored as plain integer
  final int sellingPrice; // stored as plain integer
  final int sellingPrice2;
  final int sellingPrice3;
  final int sellingPrice4;
  final int currentStock;
  final int minimumStock;
  final String? code2;
  final String? otherCodes;
  final int discountPercent;
  final int lastSellingPrice;
  final int lastQty;
  final int reorderPoint;
  final int economicQty;
  final bool isService;
  final bool quickFamily;
  final String? imagePath;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductEntity({
    this.id,
    required this.name,
    required this.productCode,
    this.barcode,
    this.categoryId,
    this.unitId,
    required this.purchasePrice,
    required this.sellingPrice,
    this.sellingPrice2 = 0,
    this.sellingPrice3 = 0,
    this.sellingPrice4 = 0,
    this.currentStock = 0,
    this.minimumStock = 0,
    this.code2,
    this.otherCodes,
    this.discountPercent = 0,
    this.lastSellingPrice = 0,
    this.lastQty = 0,
    this.reorderPoint = 0,
    this.economicQty = 0,
    this.isService = false,
    this.quickFamily = false,
    this.imagePath,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Copy with modifications.
  ProductEntity copyWith({
    int? id,
    String? name,
    String? productCode,
    String? barcode,
    int? categoryId,
    int? unitId,
    int? purchasePrice,
    int? sellingPrice,
    int? sellingPrice2,
    int? sellingPrice3,
    int? sellingPrice4,
    int? currentStock,
    int? minimumStock,
    String? code2,
    String? otherCodes,
    int? discountPercent,
    int? lastSellingPrice,
    int? lastQty,
    int? reorderPoint,
    int? economicQty,
    bool? isService,
    bool? quickFamily,
    String? imagePath,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      productCode: productCode ?? this.productCode,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      unitId: unitId ?? this.unitId,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      sellingPrice2: sellingPrice2 ?? this.sellingPrice2,
      sellingPrice3: sellingPrice3 ?? this.sellingPrice3,
      sellingPrice4: sellingPrice4 ?? this.sellingPrice4,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      code2: code2 ?? this.code2,
      otherCodes: otherCodes ?? this.otherCodes,
      discountPercent: discountPercent ?? this.discountPercent,
      lastSellingPrice: lastSellingPrice ?? this.lastSellingPrice,
      lastQty: lastQty ?? this.lastQty,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      economicQty: economicQty ?? this.economicQty,
      isService: isService ?? this.isService,
      quickFamily: quickFamily ?? this.quickFamily,
      imagePath: imagePath ?? this.imagePath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
