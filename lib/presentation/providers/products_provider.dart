import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/models/product.dart';

class ProductsState {
  final List<Product> products;
  final bool isLoading;
  final String searchQuery;

  const ProductsState({
    this.products = const [],
    this.isLoading = false,
    this.searchQuery = '',
  });

  List<Product> get filteredProducts {
    if (searchQuery.trim().isEmpty) return products;
    final query = searchQuery.trim().toLowerCase();
    return products.where((p) => p.name.toLowerCase().contains(query)).toList();
  }

  int get lowStockCount => products.where((p) => p.isLowStock).length;

  ProductsState copyWith({
    List<Product>? products,
    bool? isLoading,
    String? searchQuery,
  }) {
    return ProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

Future<void> _safeInit(Future<void> Function() initFn, {required ProductsState Function() fallback}) async {
  if (kIsWeb) {
    try {
      await initFn().timeout(const Duration(seconds: 2));
    } catch (e, stack) {
      print('ProductsProvider Web Timeout/Error: $e');
    }
  } else {
    try {
      await initFn();
    } catch (e, stack) {
      print('ProductsProvider Error: $e');
    }
  }
}

class ProductsNotifier extends StateNotifier<ProductsState> {
  final ProductRepository _repository = ProductRepository();

  ProductsNotifier() : super(const ProductsState()) {
    _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final list = await _repository.getAllProducts();
        state = state.copyWith(products: list, isLoading: false);
      },
      fallback: () => state.copyWith(isLoading: false, products: []),
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> loadProducts() async {
    await _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final list = await _repository.getAllProducts();
        state = state.copyWith(products: list, isLoading: false);
      },
      fallback: () => state.copyWith(isLoading: false),
    );
  }

  Future<void> addProduct(Product product) async {
    await _repository.insertProduct(product);
    await loadProducts();
  }

  Future<void> updateProduct(Product product) async {
    await _repository.updateProduct(product);
    await loadProducts();
  }

  Future<void> deleteProduct(int id) async {
    await _repository.deleteProduct(id);
    await loadProducts();
  }
}

final productsProvider = StateNotifierProvider<ProductsNotifier, ProductsState>((ref) {
  return ProductsNotifier();
});
