import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/payment.dart';
import '../providers/payments_provider.dart';

/// Dated payment history for one person (supplier or client/agent).
/// Every payment row stores its timestamp (`payments.date`), so this dialog
/// answers "when was the last payment made to / received from this person?".
class PaymentHistoryDialog extends ConsumerWidget {
  final String entityType; // 'supplier' or 'client'
  final int? entityId;
  final String personName;
  final String currency;

  const PaymentHistoryDialog({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.personName,
    required this.currency,
  });

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required String entityType,
    required int? entityId,
    required String personName,
    required String currency,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => PaymentHistoryDialog(
        entityType: entityType,
        entityId: entityId,
        personName: personName,
        currency: currency,
      ),
    );
  }

  bool get isSupplier => entityType == 'supplier';

  String formatDate(DateTime d) {
    return DateFormat('yyyy/MM/dd — HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(paymentsProvider).historyFor(entityType, entityId);
    final total =
        history.fold(0.0, (sum, p) => sum + p.amount);

    return AlertDialog(
      scrollable: true,
      title: Text(
          'سجل الدفعات: $personName (${isSupplier ? "مورد" : "معتمد"})'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: history.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                    'لا توجد دفعات مسجلة لهذا الشخص بعد — ستظهر هنا كل دفعة بتاريخها فور تسجيلها'),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'عدد الدفعات: ${history.length}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        Text(
                          'الإجمالي: ${total.toStringAsFixed(0)} $currency',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...history.map((p) => _paymentRow(context, p)),
                ],
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق')),
      ],
    );
  }

  Widget _paymentRow(BuildContext context, Payment p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSupplier
                ? Icons.call_received_rounded
                : Icons.call_made_rounded,
            size: 20,
            color: isSupplier ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatDate(p.date),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (p.notes.isNotEmpty)
                  Text(p.notes,
                      style: const TextStyle(fontSize: 12)),
                if (p.invoiceId != null)
                  Text('مرتبطة بفاتورة داخلية #${p.invoiceId}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${p.amount.toStringAsFixed(0)} $currency',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
