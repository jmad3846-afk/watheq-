import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'financials_provider.dart';
import 'products_provider.dart';

final dashboardKPIProvider = Provider((ref) {
  final financials = ref.watch(financialsProvider);
  final productsState = ref.watch(productsProvider);

  return {
    'receivables': financials.totalReceivables, // "لنا"
    'payables': financials.totalPayables,       // "علينا"
    'productCount': productsState.products.length,
    'lowStockCount': productsState.lowStockCount,
    'isLoading': financials.isLoading || productsState.isLoading,
  };
});
