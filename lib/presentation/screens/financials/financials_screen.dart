import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../domain/models/sale_invoice.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/financials_provider.dart';
import '../../providers/payments_provider.dart';
import '../../widgets/payment_history_dialog.dart';
import '../../providers/projects_provider.dart';
import '../../providers/suppliers_provider.dart';
import '../../providers/clients_provider.dart';
import '../../providers/purchase_invoices_provider.dart';
import '../../providers/sale_invoices_provider.dart';

class FinancialsScreen extends ConsumerStatefulWidget {
  const FinancialsScreen({super.key});

  @override
  ConsumerState<FinancialsScreen> createState() => _FinancialsScreenState();
}

class _FinancialsScreenState extends ConsumerState<FinancialsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final financials = ref.watch(financialsProvider);
    final currency = ref.watch(appSettingsProvider).currency;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header Summary Banner
          Container(
            padding: const EdgeInsets.all(24),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryBox(
                    title: 'إجمالي الديون للموردين ("علينا")',
                    amount: '${financials.totalPayables.toStringAsFixed(0)} $currency',
                    color: AppColors.payables,
                    icon: Icons.call_received_rounded,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildSummaryBox(
                    title: 'إجمالي المستحقات من المعتمدين ("لنا")',
                    amount: '${financials.totalReceivables.toStringAsFixed(0)} $currency',
                    color: AppColors.receivables,
                    icon: Icons.call_made_rounded,
                  ),
                ),
              ],
            ),
          ),

          // Tabs Header
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.accent,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              tabs: const [
                Tab(text: 'مالية وحسابات الموردين (تسديد دفعة)'),
                Tab(text: 'مبيعات العملاء القياسية (تحصيل)'),
                Tab(text: 'مالية المشاريع المعتمدة'),
              ],
            ),
          ),

          // Tab Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSuppliersFinanceTab(context, ref, currency),
                _buildStandardSalesFinanceTab(context, ref, currency),
                _buildProjectFinancialsTab(context, ref, currency),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({
    required String title,
    required String amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(amount, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  // 1. SUPPLIERS FINANCE TAB
  Widget _buildSuppliersFinanceTab(BuildContext context, WidgetRef ref, String currency) {
    final suppliers = ref.watch(suppliersProvider).suppliers;
    final invoices = ref.watch(purchaseInvoicesProvider).invoices;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView.builder(
        itemCount: suppliers.length,
        itemBuilder: (context, index) {
          final supplier = suppliers[index];
          final suppInvoices = invoices.where((i) => i.supplierId == supplier.id).toList();
          final totalDebt = suppInvoices.fold(0.0, (sum, i) => sum + i.remainingBalance);

          final lastPay =
              ref.watch(paymentsProvider).lastFor('supplier', supplier.id);
          final lastPayLabel = lastPay == null
              ? 'لا توجد دفعات مسددة بعد'
              : 'آخر دفعة مسددة: ${lastPay.amount.toStringAsFixed(0)} $currency بتاريخ ${DateFormat('yyyy/MM/dd').format(lastPay.date)}';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: const Icon(Icons.local_shipping, color: AppColors.primary),
              title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text('الهاتف: ${supplier.phone} • عدد الفواتير: ${suppInvoices.length}\n$lastPayLabel'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'المتبقي: ${totalDebt.toStringAsFixed(0)} $currency',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: totalDebt > 0 ? AppColors.payables : AppColors.receivables),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.history, size: 20, color: AppColors.accent),
                    tooltip: 'سجل الدفعات بالتواريخ',
                    onPressed: () => PaymentHistoryDialog.show(
                      context,
                      ref,
                      entityType: 'supplier',
                      entityId: supplier.id,
                      personName: supplier.name,
                      currency: currency,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: totalDebt <= 0 ? null : () => _showSupplierPaymentDialog(context, ref, supplier, suppInvoices, currency),
                    icon: const Icon(Icons.payment, size: 16),
                    label: const Text('تسديد دفعة'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.payables, foregroundColor: Colors.white),
                  ),
                ],
              ),
              children: suppInvoices.map((inv) {
                return ListTile(
                  title: Text('فاتورة رقم: ${inv.invoiceNumber} (بتاريخ: ${inv.date.toString().split(' ').first})'),
                  subtitle: Text('إجمالي الفاتورة: ${inv.totalAmount.toStringAsFixed(0)} | مدفوع: ${inv.paidAmount.toStringAsFixed(0)}'),
                  trailing: Text(
                    'متبقي: ${inv.remainingBalance.toStringAsFixed(0)} $currency',
                    style: TextStyle(fontWeight: FontWeight.bold, color: inv.remainingBalance > 0 ? AppColors.payables : AppColors.textMuted),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  // 2. STANDARD CUSTOMER SALES TAB — immediate-payment cash sales only.
  // These invoices are settled right away and carry no outstanding debt;
  // this tab is their settled history (per client + client-less quick sales).
  // Credit/project invoices live in tab 3.
  Widget _buildStandardSalesFinanceTab(
      BuildContext context, WidgetRef ref, String currency) {
    final clients = ref.watch(clientsProvider).clients;
    final invoices = ref.watch(saleInvoicesProvider).invoices;

    final standard = invoices
        .where((i) =>
            !i.isReturnInvoice && i.type == SaleInvoiceType.regular)
        .toList();
    final cashSales =
        standard.where((i) => i.clientId == null).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          if (cashSales.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: const Icon(Icons.bolt,
                    color: AppColors.accent),
                title: Text(
                    'مبيعات نقدية سريعة (بدون عميل) — ${cashSales.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                subtitle: Text(
                    'الإجمالي المحصّل: ${cashSales.fold(0.0, (s, i) => s + i.totalAmount).toStringAsFixed(0)} $currency'),
                trailing: const Chip(
                  label: Text('مسددة بالكامل',
                      style: TextStyle(fontSize: 11)),
                ),
                children: cashSales.map((inv) {
                  return ListTile(
                    dense: true,
                    title: Text(
                        'فاتورة #${inv.invoiceNumber} (${inv.date.toString().split(' ').first})'),
                    subtitle: Text(
                        'الأصناف: ${inv.items.length}'),
                    trailing: Text(
                      '${inv.totalAmount.toStringAsFixed(0)} $currency',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ),
          ...clients.map((client) {
            final clientInvoices = standard
                .where((i) => i.clientId == client.id)
                .toList();
            if (clientInvoices.isEmpty) {
              return const SizedBox.shrink();
            }
            final collected = clientInvoices.fold(
                0.0, (sum, i) => sum + i.paidAmount);
            final lastPay =
                ref.watch(paymentsProvider).lastFor('client', client.id);
            final lastPayLabel = lastPay == null
                ? 'لا توجد دفعات مستلمة بعد'
                : 'آخر دفعة مستلمة: ${lastPay.amount.toStringAsFixed(0)} $currency بتاريخ ${DateFormat('yyyy/MM/dd').format(lastPay.date)}';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: const Icon(Icons.person,
                    color: AppColors.accent),
                title: Text(client.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                subtitle: Text(
                    'الهاتف: ${client.phone} • العنوان: ${client.address}\n$lastPayLabel'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'المحصّل: ${collected.toStringAsFixed(0)} $currency',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.receivables),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.history,
                          size: 20, color: AppColors.accent),
                      tooltip: 'سجل الدفعات بالتواريخ',
                      onPressed: () => PaymentHistoryDialog.show(
                        context,
                        ref,
                        entityType: 'client',
                        entityId: client.id,
                        personName: client.name,
                        currency: currency,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Chip(
                      label: Text('مسددة بالكامل',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                children: clientInvoices.map((inv) {
                  return ListTile(
                    dense: true,
                    title: Text(
                        'فاتورة بيع نقدية رقم: ${inv.invoiceNumber} (بتاريخ: ${inv.date.toString().split(' ').first})'),
                    subtitle: Text(
                        'إجمالي: ${inv.totalAmount.toStringAsFixed(0)} | مسدد: ${inv.paidAmount.toStringAsFixed(0)}'),
                    trailing: const Text(
                      'لا يوجد مستحق',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
          if (standard.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('لا توجد مبيعات نقدية مسجلة بعد'),
            )),
        ],
      ),
    );
  }

  // 3. APPROVED PROJECT FINANCIALS — grouped by approved party, then project.
  // Tracks issued invoices, return deductions, paid amounts and what they owe.
  Widget _buildProjectFinancialsTab(
      BuildContext context, WidgetRef ref, String currency) {
    final clients = ref.watch(clientsProvider).clients;
    final projects = ref.watch(projectsProvider).projects;
    final invoices = ref.watch(saleInvoicesProvider).invoices;

    final legacy = invoices
        .where((i) =>
            !i.isReturnInvoice &&
            i.projectId == null &&
            i.type == SaleInvoiceType.long &&
            i.remainingBalance > 0)
        .toList();
    final legacyOwed =
        legacy.fold(0.0, (sum, i) => sum + i.remainingBalance);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: (projects.isEmpty && clients.isEmpty && legacy.isEmpty)
          ? const Center(child: Text('لا توجد مشاريع معتمدة بعد'))
          : ListView(
              children: [
                ...clients.map((client) {
                final clientProjects = projects
                    .where((p) => p.clientId == client.id)
                    .toList();
                if (clientProjects.isEmpty) {
                  return const SizedBox.shrink();
                }

                double clientIssued = 0.0,
                    clientPaid = 0.0,
                    clientReturns = 0.0;
                for (final p in clientProjects) {
                  final b = _projectBalance(invoices, p.id);
                  clientIssued += b.issued;
                  clientPaid += b.paid;
                  clientReturns += b.returns;
                }
                final clientOwed =
                    clientIssued - clientPaid - clientReturns;
                final lastPay = ref
                    .watch(paymentsProvider)
                    .lastFor('client', client.id);
                final lastPayLabel = lastPay == null
                    ? 'لا توجد دفعات مستلمة بعد'
                    : 'آخر دفعة مستلمة: ${lastPay.amount.toStringAsFixed(0)} $currency بتاريخ ${DateFormat('yyyy/MM/dd').format(lastPay.date)}';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ExpansionTile(
                    leading: const Icon(Icons.business,
                        color: AppColors.primary),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                              'المعتمد: ${client.name} — المستحق الكلي: ${clientOwed.toStringAsFixed(0)} $currency',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.history,
                              size: 20,
                              color: AppColors.accent),
                          tooltip:
                              'سجل الدفعات بالتواريخ',
                          onPressed: () =>
                              PaymentHistoryDialog.show(
                            context,
                            ref,
                            entityType: 'client',
                            entityId: client.id,
                            personName: client.name,
                            currency: currency,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                        'عدد المشاريع: ${clientProjects.length} • الهاتف: ${client.phone}\n$lastPayLabel'),
                    children: clientProjects.map((p) {
                      final b =
                          _projectBalance(invoices, p.id);
                      final owed = b.issued - b.paid - b.returns;
                      final projectInvoices = invoices
                          .where((i) =>
                              i.projectId == p.id &&
                              !i.isReturnInvoice)
                          .toList();
                      final projectReturns = invoices
                          .where((i) =>
                              i.projectId == p.id &&
                              i.isReturnInvoice)
                          .toList();
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Card(
                          color: AppColors.background,
                          child: ExpansionTile(
                            dense: true,
                            leading: const Icon(
                                Icons.location_on,
                                color: AppColors.accent,
                                size: 20),
                            title: Text(
                              'المشروع: ${p.location.isEmpty ? "بدون موقع" : p.location} — المستحق: ${owed.toStringAsFixed(0)} $currency',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            subtitle: Text(
                                'فواتير: ${projectInvoices.length} • إرجاع: ${projectReturns.length} • مدفوع: ${b.paid.toStringAsFixed(0)} $currency'),
                            trailing: ElevatedButton.icon(
                              onPressed: owed <= 0
                                  ? null
                                  : () => _showProjectPaymentDialog(
                                      context,
                                      ref,
                                      p.id!,
                                      '${client.name} — ${p.location}',
                                      projectInvoices,
                                      currency),
                              icon: const Icon(Icons.download,
                                  size: 14),
                              label:
                                  const Text('تحصيل دفعة'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppColors.receivables,
                                  foregroundColor:
                                      Colors.white),
                            ),
                            children: [
                              ...projectInvoices.map((inv) =>
                                  ListTile(
                                    dense: true,
                                    title: Text(
                                        'فاتورة #${inv.invoiceNumber} (${inv.date.toString().split(' ').first})'),
                                    subtitle: Text(
                                        'إجمالي: ${inv.totalAmount.toStringAsFixed(0)} | مسدد: ${inv.paidAmount.toStringAsFixed(0)}'),
                                    trailing: Text(
                                      'متبقي: ${inv.remainingBalance.toStringAsFixed(0)} $currency',
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  )),
                              ...projectReturns.map((inv) =>
                                  ListTile(
                                    dense: true,
                                    leading: const Icon(
                                        Icons.keyboard_return,
                                        size: 16,
                                        color:
                                            AppColors.warning),
                                    title: Text(
                                        'إرجاع #${inv.invoiceNumber} (للأصلية #${inv.returnOfInvoiceId ?? "؟"})',
                                        style: const TextStyle(
                                            fontSize: 12)),
                                    trailing: Text(
                                      '-${inv.totalAmount.toStringAsFixed(0)} $currency',
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 12,
                                          color:
                                              AppColors.warning),
                                    ),
                                  )),
                              Padding(
                                padding: const EdgeInsets
                                    .symmetric(
                                    horizontal: 16,
                                    vertical: 8),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Divider(),
                                    Text(
                                        'الفواتير الصادرة: ${b.issued.toStringAsFixed(0)} $currency',
                                        style: const TextStyle(
                                            fontSize: 12)),
                                    Text(
                                        'خصم الإرجاع: ${b.returns.toStringAsFixed(0)} $currency',
                                        style: const TextStyle(
                                            fontSize: 12)),
                                    Text(
                                        'المدفوع: ${b.paid.toStringAsFixed(0)} $currency',
                                        style: const TextStyle(
                                            fontSize: 12)),
                                    Text(
                                      'المستحق للمشروع: ${owed.toStringAsFixed(0)} $currency',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
                }).toList(),
                if (legacy.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      leading: const Icon(Icons.history,
                          color: AppColors.warning),
                      title: const Text(
                          'فواتير آجلة قديمة (بدون مشروع محدد)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold)),
                      trailing: Text(
                        '${legacyOwed.toStringAsFixed(0)} $currency',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.receivables),
                      ),
                      children: legacy.map((inv) {
                        return ListTile(
                          dense: true,
                          title: Text(
                              'فاتورة #${inv.invoiceNumber} (${inv.clientName ?? "—"}) — ${inv.date.toString().split(' ').first}'),
                          subtitle: Text(
                              'إجمالي: ${inv.totalAmount.toStringAsFixed(0)} | مسدد: ${inv.paidAmount.toStringAsFixed(0)}'),
                          trailing: Text(
                            'متبقي: ${inv.remainingBalance.toStringAsFixed(0)} $currency',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
    );
  }

  _ProjectBalance _projectBalance(List invoices, int? projectId) {
    double issued = 0.0, paid = 0.0, returns = 0.0;
    for (final i in invoices) {
      if (i.projectId != projectId) continue;
      if (i.isReturnInvoice == true) {
        returns += (i.totalAmount as double);
      } else {
        issued += (i.totalAmount as double);
        paid += (i.paidAmount as double);
      }
    }
    return _ProjectBalance(issued: issued, paid: paid, returns: returns);
  }

  /// Collects a payment and applies it to this project's oldest unpaid
  /// invoices first (via per-invoice payments), so project tracking stays exact.
  void _showProjectPaymentDialog(BuildContext context, WidgetRef ref,
      int projectId, String label, List invoices, String currency) {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text('تحصيل دفعة للمشروع: $label'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: 'المبلغ المستلم ($currency)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration:
                    const InputDecoration(labelText: 'ملاحظات'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amt = parseAmount(amountCtrl.text);
              if (amt == null || amt <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('أدخل مبلغاً صحيحاً أكبر من صفر')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                double left = amt;
                final targets = List.of(invoices)
                  ..sort((a, b) =>
                      (a.id as int).compareTo(b.id as int));
                for (final inv in targets) {
                  if (left <= 0) break;
                  final rem = (inv.remainingBalance as double);
                  if (rem <= 0) continue;
                  final pay = left > rem ? rem : left;
                  await ref
                      .read(financialsProvider.notifier)
                      .receiveClientPayment(
                        clientId: inv.clientId as int,
                        amount: pay,
                        invoiceId: inv.id as int,
                        notes: notesCtrl.text.trim().isEmpty
                            ? 'تحصيل مشروع: $label'
                            : notesCtrl.text.trim(),
                      );
                  left -= pay;
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تم تسجيل دفعة المشروع')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل تسجيل الدفعة: $e')),
                  );
                }
              }
            },
            child: const Text('تسجيل الدفعة'),
          ),
        ],
      ),
    );
  }

  void _showSupplierPaymentDialog(BuildContext context, WidgetRef ref, dynamic supplier, List invoices, String currency) {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسديد دفعة للمورد: ${supplier.name}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'مبلغ الدفعة ($currency)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظات / رقم الإيصال'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amt = parseAmount(amountCtrl.text);
              if (amt == null || amt <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('أدخل مبلغاً صحيحاً أكبر من صفر')),
                );
                return;
              }

              await ref.read(financialsProvider.notifier).paySupplier(
                supplierId: supplier.id!,
                amount: amt,
                notes: notesCtrl.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: const Text('تسديد المبلغ'),
          ),
        ],
      ),
    );
  }
}

class _ProjectBalance {
  final double issued;
  final double paid;
  final double returns;
  const _ProjectBalance(
      {required this.issued, required this.paid, required this.returns});
}
