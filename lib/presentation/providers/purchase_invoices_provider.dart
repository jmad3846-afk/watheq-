import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/purchase_invoice_repository.dart';
import '../../domain/models/invoice_item.dart';
import '../../domain/models/purchase_invoice.dart';
import 'products_provider.dart';

class PurchaseInvoicesState {
  final List<PurchaseInvoice> invoices;
  final bool isLoading;
  final String searchQuery;

  const PurchaseInvoicesState({
    this.invoices = const [],
    this.isLoading = false,
    this.searchQuery = '',
  });

  List<PurchaseInvoice> get filteredInvoices {
    if (searchQuery.trim().isEmpty) return invoices;
    final query = searchQuery.trim().toLowerCase();
    return invoices.where((inv) =>
      inv.supplierName.toLowerCase().contains(query) ||
      inv.invoiceNumber.toLowerCase().contains(query)
    ).toList();
  }

  PurchaseInvoicesState copyWith({
    List<PurchaseInvoice>? invoices,
    bool? isLoading,
    String? searchQuery,
  }) {
    return PurchaseInvoicesState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

Future<void> _safeInit(Future<void> Function() initFn, {required PurchaseInvoicesState Function() fallback}) async {
  if (kIsWeb) {
    try {
      await initFn().timeout(const Duration(seconds: 2));
    } catch (e, stack) {
      print('PurchaseInvoicesProvider Web Timeout/Error: $e');
    }
  } else {
    try {
      await initFn();
    } catch (e, stack) {
      print('PurchaseInvoicesProvider Error: $e');
    }
  }
}

class PurchaseInvoicesNotifier extends StateNotifier<PurchaseInvoicesState> {
  final PurchaseInvoiceRepository _repository = PurchaseInvoiceRepository();
  final Ref ref;

  PurchaseInvoicesNotifier(this.ref) : super(const PurchaseInvoicesState()) {
    _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final list = await _repository.getAllInvoices();
        state = state.copyWith(invoices: list, isLoading: false);
      },
      fallback: () => state.copyWith(isLoading: false, invoices: []),
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> loadInvoices() async {
    await _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final list = await _repository.getAllInvoices();
        state = state.copyWith(invoices: list, isLoading: false);
      },
      fallback: () => state.copyWith(isLoading: false),
    );
  }

  Future<int> createInvoice(PurchaseInvoice invoice) async {
    // Insert first and return immediately so Save feels instant
    // (SQLite is local — works fully offline). List/stock refreshes
    // run in the background without blocking the dialog.
    final id = await _repository.createInvoice(invoice);
    loadInvoices();
    ref.read(productsProvider.notifier).loadProducts();
    return id;
  }

  /// Alias kept for the "حفظ وطباعة" (Save & Print) flow: always save first.
  Future<int> saveInvoice(PurchaseInvoice invoice) => createInvoice(invoice);

  /// Append-only edit: add new item lines to [invoiceId]. Header, existing
  /// lines and payments are left untouched; stock + lists refresh after.
  Future<void> appendItems(int invoiceId, List<InvoiceItem> items) async {
    await _repository.appendInvoiceItems(invoiceId, items);
    await loadInvoices();
    ref.read(productsProvider.notifier).loadProducts();
  }

  /// Remove a single item line from [invoiceId] (stock reverted, header
  /// and payments untouched). Caller refreshes financialsProvider.
  Future<void> removeItem(int invoiceId, int itemId) async {
    await _repository.removeInvoiceItem(invoiceId, itemId);
    await loadInvoices();
    ref.read(productsProvider.notifier).loadProducts();
  }

  /// Change the quantity of a single item line (only the stock difference
  /// is applied). Caller refreshes financialsProvider.
  Future<void> updateItemQty(
      int invoiceId, int itemId, double newQty) async {
    await _repository.updateInvoiceItemQty(invoiceId, itemId, newQty);
    await loadInvoices();
    ref.read(productsProvider.notifier).loadProducts();
  }

  Future<void> deleteInvoice(int id) async {
    await _repository.deleteInvoice(id);
    await loadInvoices();
    ref.read(productsProvider.notifier).loadProducts();
  }
}

final purchaseInvoicesProvider = StateNotifierProvider<PurchaseInvoicesNotifier, PurchaseInvoicesState>((ref) {
  return PurchaseInvoicesNotifier(ref);
});
