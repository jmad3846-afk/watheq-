import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../data/repositories/payment_repository.dart';
import 'payments_provider.dart';
import 'purchase_invoices_provider.dart';
import 'sale_invoices_provider.dart';

class FinancialsState {
  final double totalReceivables; // "لنا"
  final double totalPayables;    // "علينا"
  final bool isLoading;

  const FinancialsState({
    this.totalReceivables = 0.0,
    this.totalPayables = 0.0,
    this.isLoading = false,
  });

  FinancialsState copyWith({
    double? totalReceivables,
    double? totalPayables,
    bool? isLoading,
  }) {
    return FinancialsState(
      totalReceivables: totalReceivables ?? this.totalReceivables,
      totalPayables: totalPayables ?? this.totalPayables,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

Future<void> _safeInit(Future<void> Function() initFn, {required FinancialsState Function() fallback}) async {
  if (kIsWeb) {
    try {
      await initFn().timeout(const Duration(seconds: 2));
    } catch (e, stack) {
      print('FinancialsProvider Web Timeout/Error: $e');
    }
  } else {
    try {
      await initFn();
    } catch (e, stack) {
      print('FinancialsProvider Error: $e');
    }
  }
}

class FinancialsNotifier extends StateNotifier<FinancialsState> {
  final ClientRepository _clientRepo = ClientRepository();
  final SupplierRepository _supplierRepo = SupplierRepository();
  final PaymentRepository _paymentRepo = PaymentRepository();
  final Ref ref;

  FinancialsNotifier(this.ref) : super(const FinancialsState()) {
    _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final rec = await _clientRepo.getTotalReceivables();
        final pay = await _supplierRepo.getTotalPayables();
        state = FinancialsState(
          totalReceivables: rec,
          totalPayables: pay,
          isLoading: false,
        );
      },
      fallback: () => state.copyWith(isLoading: false, totalReceivables: 0.0, totalPayables: 0.0),
    );
  }

  Future<void> refreshFinancials() async {
    await _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final rec = await _clientRepo.getTotalReceivables();
        final pay = await _supplierRepo.getTotalPayables();
        state = FinancialsState(
          totalReceivables: rec,
          totalPayables: pay,
          isLoading: false,
        );
      },
      fallback: () => state.copyWith(isLoading: false),
    );
  }

  /// Record a payment received from a client ("دفع")
  Future<void> receiveClientPayment({
    required int clientId,
    required double amount,
    int? invoiceId,
    String notes = '',
  }) async {
    await _paymentRepo.recordPayment(
      entityType: 'client',
      entityId: clientId,
      amount: amount,
      invoiceId: invoiceId,
      notes: notes,
    );
    await refreshFinancials();
    ref.read(saleInvoicesProvider.notifier).loadInvoices();
    ref.read(paymentsProvider.notifier).loadPayments();
  }

  /// Record a payment made to a supplier ("تسديد دفعة")
  Future<void> paySupplier({
    required int supplierId,
    required double amount,
    int? invoiceId,
    String notes = '',
  }) async {
    await _paymentRepo.recordPayment(
      entityType: 'supplier',
      entityId: supplierId,
      amount: amount,
      invoiceId: invoiceId,
      notes: notes,
    );
    await refreshFinancials();
    ref.read(purchaseInvoicesProvider.notifier).loadInvoices();
    ref.read(paymentsProvider.notifier).loadPayments();
  }
}

final financialsProvider = StateNotifierProvider<FinancialsNotifier, FinancialsState>((ref) {
  return FinancialsNotifier(ref);
});
