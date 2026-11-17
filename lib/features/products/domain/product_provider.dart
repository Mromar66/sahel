import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventory_app/core/utils/currency_utils.dart';
import 'package:inventory_app/features/products/data/product_repository.dart';
import 'package:inventory_app/features/products/domain/product_entity.dart';

/// Riverpod provider for the product repository.
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

/// Riverpod provider for the list of all products.
final productsProvider = StreamProvider.autoDispose<List<ProductEntity>>((ref) {
  return Stream.value([]).asyncMap((_) async {
    final repo = ref.watch(productRepositoryProvider);
    return await repo.getAllProducts();
  });
});

/// Notifier for product state management.
class ProductNotifier extends StateNotifier<List<ProductEntity>> {
  final ProductRepository _repository;

  ProductNotifier(this._repository) : super([]);

  Future<void> loadProducts() async {
    final products = await _repository.getAllProducts();
    state = products;
  }

  Future<int> addProduct(ProductEntity product) async {
    final id = await _repository.insertProduct(product);
    await loadProducts();
    return id;
  }

  Future<void> updateProduct(ProductEntity product) async {
    await _repository.updateProduct(product);
    await loadProducts();
  }

  Future<void> deleteProduct(int id) async {
    await _repository.deleteProduct(id);
    await loadProducts();
  }

  Future<void> adjustStock(int productId, int delta) async {
    await _repository.adjustStock(productId, delta);
    await loadProducts();
  }

  List<ProductEntity> getLowStockProducts() {
    return state.where((p) => p.currentStock <= p.minimumStock).toList();
  }

  String formatPrice(int amount) {
    return CurrencyUtils.format(amount);
  }
}

/// Provider for the product notifier.
final productNotifierProvider =
    StateNotifierProvider<ProductNotifier, List<ProductEntity>>((ref) {
      final repository = ref.watch(productRepositoryProvider);
      return ProductNotifier(repository);
    });
