/// Minimal product contract shared by the product search widget, the quick
/// product picker and the inquiry dialog. Both the purchase and the
/// stocktaking features implement it with their own row models.
abstract class ProductSearchItem {
  int get id;
  String get name;
  String get code;
  String? get barcode;
  String get unitName;
  int get available;
  int get purchasePrice;
  int get sellingPrice;
}
