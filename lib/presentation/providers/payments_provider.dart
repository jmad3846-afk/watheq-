import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/models/payment.dart';

class PaymentsState {
  final List<Payment> payments;
  final bool isLoading;

  const PaymentsState({
    this.payments = const [],
    this.isLoading = false,
  });

  /// Newest-first history for one person (supplier or client).
  List<Payment> historyFor(String entityType, int? entityId) {
    if (entityId == null) return const [];
    return payments
        .where((p) => p.entityType == entityType && p.entityId == entityId)
        .toList();
  }

  /// The most recent payment for one person (null when never paid).
  Payment? lastFor(String entityType, int? entityId) {
    final history = historyFor(entityType, entityId);
    return history.isEmpty ? null : history.first;
  }

  PaymentsState copyWith({
    List<Payment>? payments,
    bool? isLoading,
  }) {
    return PaymentsState(
      payments: payments ?? this.payments,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

Future<void> _safeInit(Future<void> Function() initFn,
    {required PaymentsState Function() fallback}) async {
  if (kIsWeb) {
    try {
      await initFn().timeout(const Duration(seconds: 2));
    } catch (e) {
      print('PaymentsProvider Web Timeout/Error: $e');
    }
  } else {
    try {
      await initFn();
    } catch (e) {
      print('PaymentsProvider Error: $e');
    }
  }
}

class PaymentsNotifier extends StateNotifier<PaymentsState> {
  final PaymentRepository _repository = PaymentRepository();

  PaymentsNotifier() : super(const PaymentsState()) {
    _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final list = await _repository.getAllPayments();
        state = state.copyWith(payments: list, isLoading: false);
      },
      fallback: () => state.copyWith(isLoading: false, payments: []),
    );
  }

  Future<void> loadPayments() async {
    await _safeInit(
      () async {
        state = state.copyWith(isLoading: true);
        final list = await _repository.getAllPayments();
        state = state.copyWith(payments: list, isLoading: false);
      },
      fallback: () => state.copyWith(isLoading: false),
    );
  }
}

final paymentsProvider =
    StateNotifierProvider<PaymentsNotifier, PaymentsState>((ref) {
  return PaymentsNotifier();
});
