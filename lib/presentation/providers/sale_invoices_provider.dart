import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/sale_invoice_repository.dart';
import '../../domain/models/invoice_item.dart';
import '../../domain/models/sale_invoice.dart';
import 'products_provider.dart';

class SaleInvoicesState {
  final List<SaleInvoice> invoices;
  final bool isLoading;
  final String searchQuery;
  final DateTimeRangeFilter? dateFilter;

  const SaleInvoicesState({
    this.invoices = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.dateFilter,
  });

  List<SaleInvoice> get filteredInvoices {
    return invoices.where((inv) {
      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final matchesClient = inv.clientName?.toLowerCase().contains(query) ?? false;
        final matchesNumber = inv.invoiceNumber.toLowerCase().contains(query);
        if (!matchesClient && !matchesNumber) return false;
      }

      if (dateFilter != null) {
        if (inv.date.isBefore(dateFilter!.start) || inv.date.isAfter(dateFilter!.end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  SaleInvoicesState copyWith({
    List<SaleInvoice>? invoices,
    bool? isLoading,
    String? searchQuery,
    DateTimeRangeFilter? dateFilter,
    bool clearDateFilter = false,
  }) {
    return SaleInvoicesState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      dateFilter: clearDateFilter ? null : (dateFilter ?? this.dateFilter),
    );
  }
}

class DateTimeRangeFilter {
  final DateTime start;
  final DateTime end;
  const DateTimeRangeFilter(this.start, this.end);
}

Future<void> _safeInit(Future<void> Function() initFn, {required SaleInvoicesState Function() fallback}) async {
  if (kIsWeb) {
    try {
      await initFn().timeout(const Duration(seconds: 2));
    } catch (e, stack) {
      print('SaleInvoicesProvider Web Timeout/Error: $e');
    }
  } else {
    try {
      await initFn();
    } catch (e, stack) {
      print('SaleInvoicesProvider Error: $e');
    }
  }
}

class SaleInvoicesNotifier extends StateNotifier<SaleInvoicesState> {
  final SaleInvoiceRepository _repository = SaleInvoiceRepository();
  final Ref ref;

  SaleInvoicesNotifier(this.ref) : super(const SaleInvoicesState()) {
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

  void setDateFilter(DateTime start, DateTime end) {
    state = state.copyWith(dateFilter: DateTimeRangeFilter(start, end));
  }

  void clearDateFilter() {
    state = state.copyWith(clearDateFilter: true);
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

  Future<int> createInvoice(SaleInvoice invoice) async {
    // Insert first and return immediately so Save feels instant
    // (SQLite is local — works fully offline). List/stock refreshes
    // run in the background without blocking the dialog.
    final id = await _repository.createInvoice(invoice);
    loadInvoices();
    ref.read(productsProvider.notifier).loadProducts();
    return id;
  }

  /// Alias kept for the "حفظ وطباعة" (Save & Print) flow: always save first.
  Future<int> saveInvoice(SaleInvoice invoice) => createInvoice(invoice);

  /// Append-only edit: add new item lines to [invoiceId]. Header, existing
  /// lines and payments are left untouched; stock + lists refresh after.
  Future<void> appendItems(int invoiceId, List<InvoiceItem> items) async {
    await _repository.appendInvoiceItems(invoiceId, items);
    await loadInvoices();
    ref.read(productsProvider.notifier).loadProducts();
    // Financials are derived from invoices; caller refreshes financialsProvider.
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

final saleInvoicesProvider = StateNotifierProvider<SaleInvoicesNotifier, SaleInvoicesState>((ref) {
  return SaleInvoicesNotifier(ref);
});
