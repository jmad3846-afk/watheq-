import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../domain/models/supplier.dart';

class SuppliersState {
  final List<Supplier> suppliers;
  final bool isLoading;
  final String searchQuery;

  const SuppliersState({
    this.suppliers = const [],
    this.isLoading = false,
    this.searchQuery = '',
  });

  List<Supplier> get filteredSuppliers {
    if (searchQuery.trim().isEmpty) return suppliers;
    final query = searchQuery.trim().toLowerCase();
    return suppliers.where((s) =>
      s.name.toLowerCase().contains(query) ||
      s.phone.contains(query) ||
      s.location.toLowerCase().contains(query)
    ).toList();
  }

  SuppliersState copyWith({
    List<Supplier>? suppliers,
    bool? isLoading,
    String? searchQuery,
  }) {
    return SuppliersState(
      suppliers: suppliers ?? this.suppliers,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

Future<void> _safeInit(Future<void> Function() initFn, {required SuppliersState Function() fallback}) async {
  if (kIsWeb) {
    try {
      await initFn().timeout(const Duration(seconds: 2));
    } catch (e, stack) {
      print('SuppliersProvider Web Timeout/Error: $e');
    }
  } else {
    try {
      await initFn();
    } catch (e, stack) {
      print('SuppliersProvider Error: $e');
    }
  }
}

class SuppliersNotifier extends StateNotifier<SuppliersState> {
  final SupplierRepository _repository = SupplierRepository();

  SuppliersNotifier() : super(const SuppliersState()) {
    _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final list = await _repository.getAllSuppliers();
        state = state.copyWith(suppliers: list, isLoading: false);
      },
      fallback: () => state.copyWith(isLoading: false, suppliers: []),
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> loadSuppliers() async {
    await _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final list = await _repository.getAllSuppliers();
        state = state.copyWith(suppliers: list, isLoading: false);
      },
      fallback: () => state.copyWith(isLoading: false),
    );
  }

  Future<int> addSupplier(Supplier supplier) async {
    final id = await _repository.insertSupplier(supplier);
    await loadSuppliers();
    return id;
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await _repository.updateSupplier(supplier);
    await loadSuppliers();
  }

  Future<void> deleteSupplier(int id) async {
    await _repository.deleteSupplier(id);
    await loadSuppliers();
  }
}

final suppliersProvider = StateNotifierProvider<SuppliersNotifier, SuppliersState>((ref) {
  return SuppliersNotifier();
});
