import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/printing/printer_service.dart';
import '../../../domain/models/approved_project.dart';
import '../../../domain/models/invoice_item.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/purchase_invoice.dart';
import '../../../domain/models/sale_invoice.dart';
import '../../../domain/models/supplier.dart';
import '../../../domain/models/client.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/financials_provider.dart';
import '../../providers/projects_provider.dart';
import '../../providers/purchase_invoices_provider.dart';
import '../../providers/sale_invoices_provider.dart';
import '../../providers/suppliers_provider.dart';
import '../../providers/clients_provider.dart';
import '../../providers/products_provider.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Rebuild the header action button whenever the active tab changes,
    // so its label/handler always matches the visible section.
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Searchable selectors (type-to-filter, no new dependencies).
  // Built on Flutter's [Autocomplete] so long product/client lists stay
  // usable. Arabic UI, RTL-safe, works inside StatefulBuilder dialogs.
  // ---------------------------------------------------------------------------

  /// Searchable product picker: type part of the name to filter.
  /// Shows name + available qty + unit. Calls [onChanged] on select/clear.
  Widget _productSearchField({
    required List<Product> products,
    required Product? selected,
    required ValueChanged<Product?> onChanged,
    String label = 'ابحث عن المنتج...',
  }) {
    return Autocomplete<Product>(
      displayStringForOption: (p) => p.name,
      initialValue: TextEditingValue(text: selected?.name ?? ''),
      optionsBuilder: (TextEditingValue v) {
        final q = v.text.trim();
        if (q.isEmpty) return products.take(30);
        return products.where((p) => p.name.contains(q)).take(30);
      },
      onSelected: onChanged,
      fieldViewBuilder:
          (fCtx, fCtrl, fFocus, onFieldSubmitted) => TextField(
                controller: fCtrl,
                focusNode: fFocus,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon:
                      const Icon(Icons.search, size: 18),
                  suffixIcon: selected != null
                      ? IconButton(
                          tooltip: 'مسح',
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            fCtrl.clear();
                            onChanged(null);
                          },
                        )
                      : null,
                ),
                onChanged: (t) {
                  if (t.isEmpty && selected != null) onChanged(null);
                },
              ),
      optionsViewBuilder: (oCtx, onSelectedOpt, options) => Align(
        alignment: Alignment.topRight,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 420),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (oCtx, i) {
                final p = options.elementAt(i);
                return ListTile(
                  dense: true,
                  title: Text(p.name),
                  subtitle: Text('المتوفر: ${p.quantity} ${p.unit}'),
                  onTap: () => onSelectedOpt(p),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Searchable client/approver picker: type part of the name to filter.
  Widget _clientSearchField({
    required List<Client> clients,
    required Client? selected,
    required ValueChanged<Client?> onChanged,
    String label = 'ابحث عن المعتمد...',
  }) {
    return Autocomplete<Client>(
      displayStringForOption: (c) => c.name,
      initialValue: TextEditingValue(text: selected?.name ?? ''),
      optionsBuilder: (TextEditingValue v) {
        final q = v.text.trim();
        if (q.isEmpty) return clients.take(30);
        return clients.where((c) => c.name.contains(q)).take(30);
      },
      onSelected: onChanged,
      fieldViewBuilder:
          (fCtx, fCtrl, fFocus, onFieldSubmitted) => TextField(
                controller: fCtrl,
                focusNode: fFocus,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon:
                      const Icon(Icons.search, size: 18),
                  suffixIcon: selected != null
                      ? IconButton(
                          tooltip: 'مسح',
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            fCtrl.clear();
                            onChanged(null);
                          },
                        )
                      : null,
                ),
                onChanged: (t) {
                  if (t.isEmpty && selected != null) onChanged(null);
                },
              ),
      optionsViewBuilder: (oCtx, onSelectedOpt, options) => Align(
        alignment: Alignment.topRight,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 420),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (oCtx, i) {
                final c = options.elementAt(i);
                return ListTile(
                  dense: true,
                  title: Text(c.name),
                  subtitle: c.phone.isNotEmpty ? Text(c.phone) : null,
                  onTap: () => onSelectedOpt(c),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Format a quantity without a trailing ".0" for whole numbers.
  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header Bar with 3 Category Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 520,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.accent,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      tabs: const [
                        Tab(text: 'فواتير شراء (موردين)'),
                        Tab(text: 'فواتير المشاريع المعتمدة'),
                        Tab(text: 'فواتير بيع عادية (نقدية)'),
                        Tab(text: 'فواتير الإرجاع'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_tabController.index == 0) {
                      _showCreatePurchaseInvoiceDialog(context, ref);
                    } else if (_tabController.index == 1) {
                      _showCreateProjectDialog(context, ref);
                    } else if (_tabController.index == 2) {
                      _showCreateSaleInvoiceDialog(context, ref,
                          isLongTerm: false);
                    } else {
                      _showCreateReturnDialog(context, ref);
                    }
                  },
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: Text(_tabController.index == 1
                      ? 'إنشاء مشروع معتمد جديد'
                      : _tabController.index == 3
                          ? 'إنشاء فاتورة إرجاع'
                          : 'إنشاء فاتورة جديدة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                ],
              ),
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPurchaseInvoicesTab(context, ref),
                _buildProjectsTab(context, ref),
                _buildSaleInvoicesTab(context, ref, isLongTerm: false),
                _buildReturnsTab(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. PURCHASE INVOICES TAB
  Widget _buildPurchaseInvoicesTab(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseInvoicesProvider);
    final settings = ref.watch(appSettingsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            onChanged: (q) => ref.read(purchaseInvoicesProvider.notifier).setSearchQuery(q),
            decoration: InputDecoration(
              hintText: 'ابحث حسب اسم المورد أو رقم الفاتورة...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.filteredInvoices.isEmpty
                    ? const Center(child: Text('لا توجد فواتير شراء'))
                    : ListView.builder(
                        itemCount: state.filteredInvoices.length,
                        itemBuilder: (context, index) {
                          final inv = state.filteredInvoices[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ExpansionTile(
                              leading: const Icon(Icons.shopping_bag, color: AppColors.primary),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'فاتورة شراء #${inv.invoiceNumber} - المورد: ${inv.supplierName}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: inv.isDelivered
                                          ? AppColors.receivables.withOpacity(0.15)
                                          : AppColors.warning.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      inv.isDelivered ? 'واصلة' : 'غير واصلة',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: inv.isDelivered ? AppColors.receivables : AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'التاريخ: ${inv.date.toString().split(' ').first} • العناصر: ${inv.items.length}'
                                '${!inv.isDelivered && (inv.driverName?.isNotEmpty ?? false) ? " • السائق: ${inv.driverName}" : ""}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'الإجمالي: ${inv.totalAmount.toStringAsFixed(0)} ${settings.currency}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'المتبقي للمورد: ${inv.remainingBalance.toStringAsFixed(0)} ${settings.currency}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: inv.remainingBalance > 0 ? AppColors.payables : AppColors.receivables,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('الأصناف:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ...inv.items.map((item) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('- ${item.productName}${item.isReturn ? " (مرتجع)" : ""}'),
                                                Text('${item.quantity} ${item.unit} × ${item.unitPrice} = ${item.subtotal.toStringAsFixed(0)} ${settings.currency}'),
                                              ],
                                            ),
                                          )),
                                      const Divider(),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: inv.isDelivered
                                              ? AppColors.receivables.withOpacity(0.08)
                                              : AppColors.warning.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'حالة وصول البضاعة: ${inv.isDelivered ? "واصلة" : "غير واصلة"}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            if (!inv.isDelivered) ...[
                                              const SizedBox(height: 4),
                                              if ((inv.driverName?.isNotEmpty ?? false))
                                                Text('السائق: ${inv.driverName} (${inv.driverPhone ?? ""})',
                                                    style: const TextStyle(fontSize: 12)),
                                              Text(
                                                  'سعر التوصيل / أجرة الشحن: ${inv.effectiveDeliveryCost.toStringAsFixed(0)} ${settings.currency}',
                                                  style: const TextStyle(fontSize: 12)),
                                              if (inv.deliveryNotes.isNotEmpty)
                                                Text('ملاحظات التوصيل: ${inv.deliveryNotes}',
                                                    style: const TextStyle(fontSize: 12)),
                                            ],
                                            const SizedBox(height: 4),
                                            Text(
                                                'المجموع الفرعي: ${inv.subtotal.toStringAsFixed(0)} ${settings.currency}',
                                                style: const TextStyle(fontSize: 12)),
                                            Text(
                                                'الإجمالي (شامل التوصيل): ${inv.totalAmount.toStringAsFixed(0)} ${settings.currency}',
                                                style: const TextStyle(
                                                    fontSize: 13, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      if (inv.notes.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text('ملاحظات الفاتورة: ${inv.notes}',
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              await PrinterService
                                                  .showPurchaseInvoicePreview(
                                                context: context,
                                                invoice: inv,
                                                headerTitle:
                                                    settings.printerHeader,
                                                currency: settings.currency,
                                              );
                                            },
                                            icon: const Icon(Icons.preview, size: 16),
                                            label: const Text('معاينة وطباعة (A4)'),
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: AppColors.accent),
                                            tooltip: 'تعديل — إضافة وحذف وتعديل الكميات',
                                            onPressed: () => _showAppendPurchaseItemsDialog(context, ref, inv),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: AppColors.payables),
                                            onPressed: () => _confirmDeletePurchaseInvoice(context, ref, inv.id, inv.invoiceNumber),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // 3. REGULAR (CASH) SALE INVOICES TAB — standard customer sales only.
  // Project invoices live in the Projects tab, returns in the Returns tab.
  Widget _buildSaleInvoicesTab(BuildContext context, WidgetRef ref, {required bool isLongTerm}) {
    final state = ref.watch(saleInvoicesProvider);
    final settings = ref.watch(appSettingsProvider);

    final invoices = state.filteredInvoices
        .where((i) =>
            !i.isReturnInvoice &&
            i.type == SaleInvoiceType.regular)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (q) => ref.read(saleInvoicesProvider.notifier).setSearchQuery(q),
                  decoration: InputDecoration(
                    hintText: isLongTerm ? 'ابحث حسب اسم المعتمد أو رقم الفاتورة...' : 'ابحث حسب رقم الفاتورة...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              if (!isLongTerm) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (range != null) {
                      ref.read(saleInvoicesProvider.notifier).setDateFilter(range.start, range.end);
                    }
                  },
                  icon: const Icon(Icons.date_range),
                  label: const Text('فلترة بالتاريخ'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : invoices.isEmpty
                    ? const Center(child: Text('لا توجد فواتير مبيعات في هذا القسم'))
                    : ListView.builder(
                        itemCount: invoices.length,
                        itemBuilder: (context, index) {
                          final inv = invoices[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ExpansionTile(
                              leading: const Icon(Icons.receipt_long, color: AppColors.accent),
                              title: Text(
                                'فاتورة بيع #${inv.invoiceNumber}${inv.clientName != null ? " - العميل: ${inv.clientName}" : " (مبيعات عادية)"}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('التاريخ: ${inv.date.toString().split(' ').first} • العناصر: ${inv.items.length}'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'الإجمالي: ${inv.totalAmount.toStringAsFixed(0)} ${settings.currency}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  if (isLongTerm)
                                    Text(
                                      'المتبقي على العميل: ${inv.remainingBalance.toStringAsFixed(0)} ${settings.currency}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: inv.remainingBalance > 0 ? AppColors.receivables : AppColors.textMuted,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('الأصناف والمنتجات:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ...inv.items.map((item) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('- ${item.productName}${item.isReturn ? " (مرتجع)" : ""}'),
                                                Text('${item.quantity} ${item.unit} × ${item.unitPrice} = ${item.subtotal.toStringAsFixed(0)} ${settings.currency}'),
                                              ],
                                            ),
                                          )),
                                      const Divider(),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              await PrinterService
                                                  .showSaleInvoicePreview(
                                                context: context,
                                                invoice: inv,
                                                headerTitle:
                                                    settings.printerHeader,
                                                currency: settings.currency,
                                              );
                                            },
                                            icon: const Icon(Icons.preview, size: 16),
                                            label: const Text('معاينة وطباعة (A4)'),
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                                            tooltip: 'تعديل — إضافة وحذف وتعديل الكميات',
                                            onPressed: () => _showAppendSaleItemsDialog(context, ref, inv),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: AppColors.payables),
                                            onPressed: () => _confirmDeleteSaleInvoice(context, ref, inv.id, inv.invoiceNumber),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ---- Delete helpers (confirm + safe, with feedback) ----
  Future<void> _confirmDeleteSaleInvoice(
      BuildContext context, WidgetRef ref, int? id, String number) async {
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف الفاتورة: رقم داخلي مفقود')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف الفاتورة'),
        content: Text('هل أنت متأكد من حذف الفاتورة #$number؟\nسيتم عكس حركة المخزون المرتبطة بها.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.payables,
                foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(saleInvoicesProvider.notifier).deleteInvoice(id);
      await ref.read(financialsProvider.notifier).refreshFinancials();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الفاتورة بنجاح')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حذف الفاتورة: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeletePurchaseInvoice(
      BuildContext context, WidgetRef ref, int? id, String number) async {
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف الفاتورة: رقم داخلي مفقود')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف الفاتورة'),
        content: Text('هل أنت متأكد من حذف فاتورة الشراء #$number؟\nسيتم عكس حركة المخزون المرتبطة بها.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.payables,
                foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(purchaseInvoicesProvider.notifier).deleteInvoice(id);
      await ref.read(financialsProvider.notifier).refreshFinancials();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الفاتورة بنجاح')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حذف الفاتورة: $e')),
        );
      }
    }
  }

  // 2. APPROVED PROJECTS TAB — replaces the old long-term sales tab.
  // Each project card shows party + location + totals and its invoices.
  Widget _buildProjectsTab(BuildContext context, WidgetRef ref) {
    final projectsState = ref.watch(projectsProvider);
    final salesState = ref.watch(saleInvoicesProvider);
    final settings = ref.watch(appSettingsProvider);

    final projectInvoices = salesState.filteredInvoices
        .where((i) => !i.isReturnInvoice && i.isProjectLike)
        .toList();
    final legacyInvoices =
        projectInvoices.where((i) => i.projectId == null).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            onChanged: (q) =>
                ref.read(projectsProvider.notifier).setSearchQuery(q),
            decoration: InputDecoration(
              hintText: 'ابحث حسب اسم المعتمد أو موقع المشروع...',
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textMuted),
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: projectsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : (projectsState.filteredProjects.isEmpty &&
                        legacyInvoices.isEmpty)
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                                'لا توجد مشاريع معتمدة بعد — أنشئ مشروعاً معتمداً جديداً'),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _showCreateProjectDialog(context, ref),
                              icon: const Icon(Icons.add_business, size: 18),
                              label:
                                  const Text('إنشاء مشروع معتمد جديد'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          ...projectsState.filteredProjects
                              .map((p) => _buildProjectCard(
                                  context, ref, p, settings.currency))
                              ,
                          if (legacyInvoices.isNotEmpty)
                            _buildLegacyProjectCard(context, ref,
                                legacyInvoices, settings.currency),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, WidgetRef ref,
      ApprovedProject project, String currency) {
    final salesState = ref.watch(saleInvoicesProvider);
    final settings = ref.watch(appSettingsProvider);
    if (project.id == null) return const SizedBox.shrink();

    final invs = salesState.invoices
        .where((i) =>
            !i.isReturnInvoice &&
            i.isProjectLike &&
            i.projectId == project.id)
        .toList();
    final returns = salesState.invoices
        .where((i) => i.isReturnInvoice && i.projectId == project.id)
        .toList();
    final issued = invs.fold(0.0, (s, i) => s + i.totalAmount);
    final paid = invs.fold(0.0, (s, i) => s + i.paidAmount);
    final returned = returns.fold(0.0, (s, i) => s + i.totalAmount);
    final owed = issued - paid - returned;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.business, color: AppColors.primary),
        title: Text(
          '${project.clientName} — ${project.location.isEmpty ? "بدون موقع" : project.location}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
            'الفواتير: ${invs.length} • الإرجاع: ${returns.length}'),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            'المستحق: ${owed.toStringAsFixed(0)} $currency',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: owed > 0
                    ? AppColors.receivables
                    : AppColors.textMuted),
          ),
        ),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await PrinterService.showProjectReportPreview(
                      context: context,
                      project: project,
                      invoices: [...invs, ...returns],
                      headerTitle: settings.printerHeader,
                      currency: settings.currency,
                    );
                  },
                  icon: const Icon(Icons.summarize, size: 16),
                  label: const Text('طباعة كشف المشروع',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showCreateSaleInvoiceDialog(context, ref,
                      isLongTerm: true, project: project),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('إضافة فاتورة للمشروع'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      _confirmDeleteProject(context, ref, project),
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.payables),
                  label: const Text('حذف المشروع',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.payables)),
                ),
              ],
            ),
          ),
          if (invs.isEmpty && returns.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('لا توجد فواتير لهذا المشروع بعد'),
            ),
          ...invs.map((inv) => _buildProjectInvoiceTile(
              context, ref, inv, settings.currency, false)),
          ...returns.map((inv) => _buildProjectInvoiceTile(
              context, ref, inv, settings.currency, true)),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text(
                    'إجمالي الفواتير: ${issued.toStringAsFixed(0)} $currency',
                    style: const TextStyle(fontSize: 12)),
                Text(
                    'إجمالي الإرجاع: ${returned.toStringAsFixed(0)} $currency',
                    style: const TextStyle(fontSize: 12)),
                Text('المدفوع: ${paid.toStringAsFixed(0)} $currency',
                    style: const TextStyle(fontSize: 12)),
                Text(
                  'الصافي المستحق: ${owed.toStringAsFixed(0)} $currency',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Legacy long-term invoices created before Projects existed.
  Widget _buildLegacyProjectCard(BuildContext context, WidgetRef ref,
      List<SaleInvoice> legacy, String currency) {
    final settings = ref.watch(appSettingsProvider);
    final issued = legacy.fold(0.0, (s, i) => s + i.totalAmount);
    final paid = legacy.fold(0.0, (s, i) => s + i.paidAmount);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.history, color: AppColors.warning),
        title: const Text('فواتير آجلة قديمة (بدون مشروع محدد)',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('العدد: ${legacy.length}'),
        trailing: Text(
          'المستحق: ${(issued - paid).toStringAsFixed(0)} $currency',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13),
        ),
        children: legacy
            .map((inv) => _buildProjectInvoiceTile(
                context, ref, inv, settings.currency, false))
            .toList(),
      ),
    );
  }

  Widget _buildProjectInvoiceTile(BuildContext context, WidgetRef ref,
      SaleInvoice inv, String currency, bool isReturnRow) {
    final settings = ref.watch(appSettingsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Card(
        color: isReturnRow
            ? AppColors.warning.withOpacity(0.08)
            : AppColors.background,
        child: ExpansionTile(
          dense: true,
          leading: Icon(
              isReturnRow ? Icons.keyboard_return : Icons.receipt_long,
              color: isReturnRow
                  ? AppColors.warning
                  : AppColors.accent,
              size: 20),
          title: Text(
            '${isReturnRow ? "فاتورة إرجاع" : "فاتورة"} #${inv.invoiceNumber}'
            '${isReturnRow && inv.returnOfInvoiceId != null ? " (للأصلية #${inv.returnOfInvoiceId})" : ""}'
            ' — ${inv.totalAmount.toStringAsFixed(0)} $currency',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
              'التاريخ: ${inv.date.toString().split(' ').first} • الأصناف: ${inv.items.length}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.preview,
                    size: 18, color: AppColors.primary),
                tooltip: 'معاينة قبل الطباعة',
                onPressed: () async {
                  await PrinterService.showSaleInvoicePreview(
                    context: context,
                    invoice: inv,
                    headerTitle: settings.printerHeader,
                    currency: settings.currency,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.accent),
                tooltip: 'تعديل — إضافة وحذف وتعديل الكميات',
                onPressed: () =>
                    _showAppendSaleItemsDialog(context, ref, inv),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.payables),
                tooltip: 'حذف',
                onPressed: () => _confirmDeleteSaleInvoice(
                    context, ref, inv.id, inv.invoiceNumber),
              ),
            ],
          ),
          children: inv.items
              .map((item) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                              '- ${item.productName}${item.isReturn ? " (مرتجع)" : ""}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                              '${item.quantity} ${item.unit} × ${item.unitPrice} = ${item.subtotal.toStringAsFixed(0)} $currency',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteProject(
      BuildContext context, WidgetRef ref, ApprovedProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف المشروع'),
        content: Text(
            'حذف المشروع "${project.clientName} — ${project.location}"؟\nالفواتير المرتبطة تبقى في النظام بدون مشروع.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.payables,
                foregroundColor: Colors.white),
            child: const Text('حذف المشروع'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(projectsProvider.notifier).deleteProject(project.id!);
      await ref.read(saleInvoicesProvider.notifier).loadInvoices();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المشروع')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حذف المشروع: $e')),
        );
      }
    }
  }

  // 4. RETURN INVOICES TAB — returns for Approved Contractor Projects.
  Widget _buildReturnsTab(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleInvoicesProvider);
    final settings = ref.watch(appSettingsProvider);
    final returns = state.filteredInvoices
        .where((i) => i.isReturnInvoice)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (q) => ref
                      .read(saleInvoicesProvider.notifier)
                      .setSearchQuery(q),
                  decoration: InputDecoration(
                    hintText: 'ابحث برقم فاتورة الإرجاع أو الأصلية...',
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textMuted),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showCreateReturnDialog(context, ref),
                icon: const Icon(Icons.keyboard_return, size: 18),
                label: const Text('إنشاء فاتورة إرجاع'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : returns.isEmpty
                    ? const Center(
                        child: Text(
                            'لا توجد فواتير إرجاع — أنشئ إرجاعاً من فاتورة مشروع معتمد'))
                    : ListView.builder(
                        itemCount: returns.length,
                        itemBuilder: (context, index) {
                          final inv = returns[index];
                          return Card(
                            margin:
                                const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            child: ExpansionTile(
                              leading: const Icon(
                                  Icons.keyboard_return,
                                  color: AppColors.warning),
                              title: Text(
                                'فاتورة إرجاع #${inv.invoiceNumber} — للأصلية #${inv.returnOfInvoiceId ?? "?"}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                  'المشروع: ${inv.projectName ?? inv.clientName ?? "—"} • التاريخ: ${inv.date.toString().split(' ').first} • الأصناف: ${inv.items.length}'),
                              trailing: Text(
                                'قيمة الإرجاع: ${inv.totalAmount.toStringAsFixed(0)} ${settings.currency}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              children: [
                                ...inv.items.map((item) =>
                                    Padding(
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 20,
                                          vertical: 2),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        children: [
                                          Text(
                                              '- ${item.productName}'),
                                          Text(
                                              '${item.quantity} ${item.unit} × ${item.unitPrice} = ${item.subtotal.toStringAsFixed(0)} ${settings.currency}'),
                                        ],
                                      ),
                                    )),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          await PrinterService
                                              .showSaleInvoicePreview(
                                            context: context,
                                            invoice: inv,
                                            headerTitle:
                                                settings.printerHeader,
                                            currency: settings.currency,
                                          );
                                        },
                                        icon: const Icon(Icons.preview,
                                            size: 16),
                                        label:
                                            const Text('معاينة وطباعة (A4)'),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.primary,
                                            foregroundColor:
                                                Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.edit_outlined,
                                            color: AppColors.accent),
                                        tooltip: 'تعديل — إضافة وحذف وتعديل الكميات',
                                        onPressed: () =>
                                            _showAppendSaleItemsDialog(
                                                context, ref, inv),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline,
                                            color:
                                                AppColors.payables),
                                        onPressed: () =>
                                            _confirmDeleteSaleInvoice(
                                                context,
                                                ref,
                                                inv.id,
                                                inv.invoiceNumber),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // DIALOG FOR CREATING PURCHASE INVOICE
  void _showCreatePurchaseInvoiceDialog(BuildContext context, WidgetRef ref) {
    final suppliers = ref.read(suppliersProvider).suppliers;
    final products = ref.read(productsProvider).products;
    final settings = ref.read(appSettingsProvider);

    Supplier? selectedSupplier = suppliers.isNotEmpty ? suppliers.first : null;
    final List<InvoiceItem> currentItems = [];
    final paidAmountCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController(text: '');
    String? selectedImagePath;

    // Delivery status (per-invoice) + driver details
    bool isDelivered = true;
    final driverNameCtrl = TextEditingController(text: '');
    final driverPhoneCtrl = TextEditingController(text: '');
    final deliveryCostCtrl = TextEditingController(text: '0');
    final deliveryNotesCtrl = TextEditingController(text: '');

    Product? selectedProduct = products.isNotEmpty ? products.first : null;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: selectedProduct?.costPrice.toString() ?? '0');
    bool isReturn = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final itemsSubtotal = currentItems.fold(0.0, (sum, i) => sum + i.subtotal);
          final parsedDelivery = double.tryParse(deliveryCostCtrl.text);
          final deliveryCostValue =
              (!isDelivered && parsedDelivery != null && parsedDelivery > 0) ? parsedDelivery : 0.0;
          final grandTotal = itemsSubtotal + deliveryCostValue;
          final hasDeliveryError = !isDelivered &&
              deliveryCostCtrl.text.trim().isNotEmpty &&
              (parsedDelivery == null || parsedDelivery < 0);

          return AlertDialog(
            title: const Text('إنشاء فاتورة شراء جديدة (من مورد)'),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Supplier Selector
                    Row(
                      children: [
                        const Text('المورد:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButton<Supplier>(
                            isExpanded: true,
                            value: selectedSupplier,
                            items: suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                            onChanged: (val) => setDialogState(() => selectedSupplier = val),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Add Item Line Controls
                    const Text('إضافة أصناف الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _productSearchField(
                            products: products,
                            selected: selectedProduct,
                            label: 'ابحث عن المنتج...',
                            onChanged: (val) {
                              setDialogState(() {
                                selectedProduct = val;
                                priceCtrl.text = val?.costPrice.toString() ?? '0';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية')),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الوحدة')),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Checkbox(value: isReturn, onChanged: (v) => setDialogState(() => isReturn = v ?? false)),
                            const Text('مرتجع', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 30),
                          onPressed: () {
                            if (selectedProduct == null) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('لا توجد منتجات متاحة')),
                              );
                              return;
                            }
                            if (selectedProduct!.id == null) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('بيانات المنتج غير صالحة')),
                              );
                              return;
                            }
                            final qty =
                                double.tryParse(qtyCtrl.text.trim()) ?? -1;
                            final price =
                                double.tryParse(priceCtrl.text.trim()) ??
                                    selectedProduct!.costPrice;
                            if (qty <= 0) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('أدخل كمية صحيحة (> 0)')),
                              );
                              return;
                            }
                            if (price < 0) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('أدخل سعراً صحيحاً (0 أو أكثر)')),
                              );
                              return;
                            }

                            setDialogState(() {
                              currentItems.add(InvoiceItem(
                                productId: selectedProduct!.id!,
                                productName: selectedProduct!.name,
                                quantity: qty,
                                unitPrice: price,
                                unit: selectedProduct!.unit,
                                isReturn: isReturn,
                              ));
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Items List Preview
                    Container(
                      height: 140,
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                      child: currentItems.isEmpty
                          ? const Center(child: Text('لم يتم إضافة أصناف بعد'))
                          : ListView.builder(
                              itemCount: currentItems.length,
                              itemBuilder: (ctx, i) {
                                final item = currentItems[i];
                                return ListTile(
                                  dense: true,
                                  title: Text('${item.productName}${item.isReturn ? " (مرتجع)" : ""}'),
                                  subtitle: Text('${item.quantity} ${item.unit} × ${item.unitPrice}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${item.subtotal.toStringAsFixed(0)} ${settings.currency}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setDialogState(() => currentItems.removeAt(i))),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Image attachment & totals breakdown (live: subtotal + delivery)
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final img = await picker.pickImage(source: ImageSource.gallery);
                            if (img != null) {
                              setDialogState(() => selectedImagePath = img.path);
                            }
                          },
                          icon: const Icon(Icons.attach_file, size: 16),
                          label: Text(selectedImagePath == null ? 'إرفاق صورة الفاتورة' : 'تم إرفاق الصورة'),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                'المجموع الفرعي: ${itemsSubtotal.toStringAsFixed(0)} ${settings.currency}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            if (!isDelivered)
                              Text(
                                  'سعر التوصيل: ${deliveryCostValue.toStringAsFixed(0)} ${settings.currency}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text('الإجمالي الكلي (شامل التوصيل): ${grandTotal.toStringAsFixed(0)} ${settings.currency}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: paidAmountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'المدفوع كدفعة أولى للمورد'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'ملاحظات الفاتورة'),
                    ),
                    const Divider(height: 24),
                    // Delivery Status (per-invoice): حالة وصول البضاعة
                    const Text('حالة وصول البضاعة:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<bool>(
                      initialValue: isDelivered,
                      decoration: const InputDecoration(
                        labelText: 'حالة وصول البضاعة',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('واصلة (Delivered)')),
                        DropdownMenuItem(value: false, child: Text('غير واصلة (Not Delivered)')),
                      ],
                      onChanged: (val) => setDialogState(() {
                        isDelivered = val ?? true;
                        if (isDelivered) {
                          // Hide cost field and reset to zero when delivered.
                          deliveryCostCtrl.text = '0';
                        }
                      }),
                    ),
                    if (!isDelivered) ...[
                      const SizedBox(height: 10),
                      const Text('بيانات السائق / التوصيل:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: driverNameCtrl,
                              decoration: const InputDecoration(labelText: 'اسم السائق'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: driverPhoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'رقم هاتف السائق'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: deliveryCostCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'سعر التوصيل / أجرة الشحن',
                                errorText: hasDeliveryError ? 'أدخل مبلغاً صحيحاً (0 أو أكثر)' : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: deliveryNotesCtrl,
                              decoration: const InputDecoration(labelText: 'ملاحظات التوصيل'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (suppliers.isEmpty || selectedSupplier == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'لا يوجد موردون — أضف مورداً أولاً من شاشة جهات الاتصال')),
                          );
                          return;
                        }
                        if (currentItems.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('أضف صنفاً واحداً على الأقل')),
                          );
                          return;
                        }
                        // Re-parse live (don't rely on stale builder closure).
                        final liveParsedDelivery = double.tryParse(
                            deliveryCostCtrl.text.trim());
                        if (!isDelivered &&
                            deliveryCostCtrl.text.trim().isNotEmpty &&
                            (liveParsedDelivery == null ||
                                liveParsedDelivery < 0)) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'سعر التوصيل غير صالح — أدخل مبلغاً صحيحاً (0 أو أكثر)')),
                          );
                          return;
                        }
                        final liveDeliveryCost = (!isDelivered &&
                                liveParsedDelivery != null &&
                                liveParsedDelivery > 0)
                            ? liveParsedDelivery
                            : 0.0;
                        final paid =
                            double.tryParse(paidAmountCtrl.text.trim()) ?? -1;
                        if (paid < 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'المبلغ المدفوع غير صالح — أدخل مبلغاً (0 أو أكثر)')),
                          );
                          return;
                        }
                        if (selectedSupplier!.id == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('بيانات المورد غير صالحة')),
                          );
                          return;
                        }
                        final invoice = PurchaseInvoice(
                          invoiceNumber: '',
                          supplierId: selectedSupplier!.id!,
                          supplierName: selectedSupplier!.name,
                          date: DateTime.now(),
                          paidAmount: paid,
                          imagePath: selectedImagePath,
                          notes: notesCtrl.text.trim(),
                          items: List.of(currentItems),
                          isDelivered: isDelivered,
                          driverName: isDelivered
                              ? null
                              : driverNameCtrl.text.trim().isEmpty
                                  ? null
                                  : driverNameCtrl.text.trim(),
                          driverPhone: isDelivered
                              ? null
                              : driverPhoneCtrl.text.trim().isEmpty
                                  ? null
                                  : driverPhoneCtrl.text.trim(),
                          deliveryCost: liveDeliveryCost,
                          deliveryNotes: isDelivered
                              ? ''
                              : deliveryNotesCtrl.text.trim(),
                        );

                        setDialogState(() => isSaving = true);
                        try {
                          // 1) ALWAYS save to SQLite first via provider.
                          await ref
                              .read(purchaseInvoicesProvider.notifier)
                              .saveInvoice(invoice);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('تم حفظ الفاتورة بنجاح')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('فشل حفظ الفاتورة: $e')),
                            );
                          }
                        }
                      },
                // No spinner: SQLite save is local/instant (offline-safe).
                // isSaving only disables the button to prevent double-tap.
                child: const Text('حفظ الفاتورة'),
              ),
              ElevatedButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (suppliers.isEmpty || selectedSupplier == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'لا يوجد موردون — أضف مورداً أولاً من شاشة جهات الاتصال')),
                          );
                          return;
                        }
                        if (currentItems.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('أضف صنفاً واحداً على الأقل')),
                          );
                          return;
                        }
                        final liveParsedDelivery = double.tryParse(
                            deliveryCostCtrl.text.trim());
                        if (!isDelivered &&
                            deliveryCostCtrl.text.trim().isNotEmpty &&
                            (liveParsedDelivery == null ||
                                liveParsedDelivery < 0)) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'سعر التوصيل غير صالح — أدخل مبلغاً صحيحاً (0 أو أكثر)')),
                          );
                          return;
                        }
                        final liveDeliveryCost = (!isDelivered &&
                                liveParsedDelivery != null &&
                                liveParsedDelivery > 0)
                            ? liveParsedDelivery
                            : 0.0;
                        final paid =
                            double.tryParse(paidAmountCtrl.text.trim()) ?? -1;
                        if (paid < 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'المبلغ المدفوع غير صالح — أدخل مبلغاً (0 أو أكثر)')),
                          );
                          return;
                        }
                        if (selectedSupplier!.id == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('بيانات المورد غير صالحة')),
                          );
                          return;
                        }
                        final invoice = PurchaseInvoice(
                          invoiceNumber: '',
                          supplierId: selectedSupplier!.id!,
                          supplierName: selectedSupplier!.name,
                          date: DateTime.now(),
                          paidAmount: paid,
                          imagePath: selectedImagePath,
                          notes: notesCtrl.text.trim(),
                          items: List.of(currentItems),
                          isDelivered: isDelivered,
                          driverName: isDelivered
                              ? null
                              : driverNameCtrl.text.trim().isEmpty
                                  ? null
                                  : driverNameCtrl.text.trim(),
                          driverPhone: isDelivered
                              ? null
                              : driverPhoneCtrl.text.trim().isEmpty
                                  ? null
                                  : driverPhoneCtrl.text.trim(),
                          deliveryCost: liveDeliveryCost,
                          deliveryNotes: isDelivered
                              ? ''
                              : deliveryNotesCtrl.text.trim(),
                        );

                        setDialogState(() => isSaving = true);
                        int savedId = -1;
                        try {
                          // 1) ALWAYS save to SQLite first via provider.
                          savedId = await ref
                              .read(purchaseInvoicesProvider.notifier)
                              .saveInvoice(invoice);
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('فشل حفظ الفاتورة: $e')),
                            );
                          }
                          return;
                        }
                        // Re-load the saved invoice so the receipt shows the real DB invoiceNumber.
                        PurchaseInvoice invoiceToPrint = invoice;
                        try {
                          final all =
                              ref.read(purchaseInvoicesProvider).invoices;
                          invoiceToPrint = all.firstWhere(
                            (e) => e.id == savedId,
                            orElse: () => invoice,
                          );
                        } catch (_) {}

                        // 2) Then show the A4 print preview — never let printer
                        // errors undo the save.
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          await PrinterService.showPurchaseInvoicePreview(
                            context: context,
                            invoice: invoiceToPrint,
                            headerTitle: settings.printerHeader,
                            currency: settings.currency,
                          );
                        }
                      },
                icon: const Icon(Icons.preview, size: 18),
                label: const Text('حفظ ومعاينة وطباعة (A4)'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  // DIALOG FOR CREATING SALE INVOICE (Long term / Regular)
  /// Creates a sale invoice. Pass [project] to issue the invoice to an
  /// Approved Project (type project, linked via projectId).
  void _showCreateSaleInvoiceDialog(BuildContext context, WidgetRef ref,
      {required bool isLongTerm, ApprovedProject? project}) {
    final clients = ref.read(clientsProvider).clients;
    final products = ref.read(productsProvider).products;
    final settings = ref.read(appSettingsProvider);

    Client? selectedClient;
    if (project != null) {
      try {
        selectedClient =
            clients.firstWhere((c) => c.id == project.clientId);
      } catch (_) {
        selectedClient = clients.isNotEmpty ? clients.first : null;
      }
    } else if (isLongTerm && clients.isNotEmpty) {
      selectedClient = clients.first;
    }
    final List<InvoiceItem> currentItems = [];
    final depositCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController(text: '');

    Product? selectedProduct = products.isNotEmpty ? products.first : null;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: selectedProduct?.salePrice.toString() ?? '0');
    bool isReturn = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double grandTotal = currentItems.fold(0.0, (sum, i) => sum + i.subtotal);

          return AlertDialog(
            scrollable: true,
            title: Text(project != null
                ? 'إنشاء فاتورة مشروع معتمد (${project.clientName} — ${project.location})'
                : isLongTerm
                    ? 'إنشاء فاتورة بيع طويلة (آجل معتمد)'
                    : 'إنشاء فاتورة بيع عادية (نقدية)'),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (project != null) ...[
                      Row(
                        children: [
                          const Text('المشروع المعتمد:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                                '${project.clientName} — ${project.location.isEmpty ? "بدون موقع" : project.location}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                    ] else if (isLongTerm) ...[
                      Row(
                        children: [
                          const Text('العميل / المعتمد:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _clientSearchField(
                              clients: clients,
                              selected: selectedClient,
                              label: 'ابحث عن العميل / المعتمد...',
                              onChanged: (val) =>
                                  setDialogState(() => selectedClient = val),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                    ],

                    const Text('اختيار المنتجات:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _productSearchField(
                            products: products,
                            selected: selectedProduct,
                            label: 'ابحث عن المنتج...',
                            onChanged: (val) {
                              setDialogState(() {
                                selectedProduct = val;
                                priceCtrl.text = val?.salePrice.toString() ?? '0';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية')),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر')),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Checkbox(value: isReturn, onChanged: (v) => setDialogState(() => isReturn = v ?? false)),
                            const Text('مرتجع', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: AppColors.accent, size: 30),
                          onPressed: () {
                            if (selectedProduct == null) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('لا توجد منتجات متاحة')),
                              );
                              return;
                            }
                            if (selectedProduct!.id == null) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('بيانات المنتج غير صالحة')),
                              );
                              return;
                            }
                            final qty =
                                double.tryParse(qtyCtrl.text.trim()) ?? -1;
                            final price =
                                double.tryParse(priceCtrl.text.trim()) ??
                                    selectedProduct!.salePrice;
                            if (qty <= 0) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('أدخل كمية صحيحة (> 0)')),
                              );
                              return;
                            }
                            if (price < 0) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('أدخل سعراً صحيحاً (0 أو أكثر)')),
                              );
                              return;
                            }

                            setDialogState(() {
                              currentItems.add(InvoiceItem(
                                productId: selectedProduct!.id!,
                                productName: selectedProduct!.name,
                                quantity: qty,
                                unitPrice: price,
                                unit: selectedProduct!.unit,
                                isReturn: isReturn,
                              ));
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      height: 140,
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                      child: currentItems.isEmpty
                          ? const Center(child: Text('لم يتم إضافة منتجات بعد'))
                          : ListView.builder(
                              itemCount: currentItems.length,
                              itemBuilder: (ctx, i) {
                                final item = currentItems[i];
                                return ListTile(
                                  dense: true,
                                  title: Text('${item.productName}${item.isReturn ? " (مرتجع)" : ""}'),
                                  subtitle: Text('${item.quantity} ${item.unit} × ${item.unitPrice}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${item.subtotal.toStringAsFixed(0)} ${settings.currency}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setDialogState(() => currentItems.removeAt(i))),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),

                    Text('الإجمالي الكلي: ${grandTotal.toStringAsFixed(0)} ${settings.currency}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accent)),
                    if (isLongTerm || project != null) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: depositCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'الدفعة الأولى المستلمة من العميل'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              // Save-only: persists without touching the printer.
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (currentItems.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'أضف منتجاً واحداً على الأقل')),
                          );
                          return;
                        }
                        if (isLongTerm && project == null) {
                          if (clients.isEmpty || selectedClient == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'لا يوجد عملاء — أضف عميلاً أولاً من شاشة جهات الاتصال')),
                            );
                            return;
                          }
                        }
                        if (products.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('لا توجد منتجات — أضف منتجاً أولاً')),
                          );
                          return;
                        }
                        final deposit = double.tryParse(
                                depositCtrl.text.trim()) ??
                            0.0;
                        if (deposit < 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('الدفعة غير صالحة')),
                          );
                          return;
                        }

                        final isProjectInvoice = project != null;
                        final invoice = SaleInvoice(
                          invoiceNumber: '',
                          clientId: isProjectInvoice
                              ? project.clientId
                              : selectedClient?.id,
                          clientName: isProjectInvoice
                              ? project.clientName
                              : selectedClient?.name,
                          type: isProjectInvoice
                              ? SaleInvoiceType.project
                              : isLongTerm
                                  ? SaleInvoiceType.long
                                  : SaleInvoiceType.regular,
                          date: DateTime.now(),
                          deposit: deposit,
                          paidAmount: (isLongTerm || isProjectInvoice)
                              ? deposit
                              : grandTotal,
                          notes: notesCtrl.text.trim(),
                          items: List.of(currentItems),
                          projectId: project?.id,
                          projectName: project == null
                              ? null
                              : '${project.clientName} — ${project.location}',
                        );

                        setDialogState(() => isSaving = true);
                        try {
                          await ref
                              .read(saleInvoicesProvider.notifier)
                              .saveInvoice(invoice);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('تم حفظ الفاتورة بنجاح')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('فشل حفظ الفاتورة: $e')),
                            );
                          }
                        }
                      },
                // No spinner: SQLite save is local/instant (offline-safe).
                // isSaving only disables the button to prevent double-tap.
                child: const Text('حفظ فقط'),
              ),
              ElevatedButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (currentItems.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'أضف منتجاً واحداً على الأقل')),
                          );
                          return;
                        }
                        if (isLongTerm && project == null) {
                          if (clients.isEmpty || selectedClient == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'اختر العميل / المعتمد أولاً')),
                            );
                            return;
                          }
                        }
                        if (products.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('لا توجد منتجات — أضف منتجاً أولاً')),
                          );
                          return;
                        }
                        final deposit = double.tryParse(
                                depositCtrl.text.trim()) ??
                            0.0;
                        if (deposit < 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('الدفعة غير صالحة')),
                          );
                          return;
                        }

                        final isProjectInvoice = project != null;
                        final invoice = SaleInvoice(
                          invoiceNumber: '',
                          clientId: isProjectInvoice
                              ? project.clientId
                              : selectedClient?.id,
                          clientName: isProjectInvoice
                              ? project.clientName
                              : selectedClient?.name,
                          type: isProjectInvoice
                              ? SaleInvoiceType.project
                              : isLongTerm
                                  ? SaleInvoiceType.long
                                  : SaleInvoiceType.regular,
                          date: DateTime.now(),
                          deposit: deposit,
                          paidAmount: (isLongTerm || isProjectInvoice)
                              ? deposit
                              : grandTotal,
                          notes: notesCtrl.text.trim(),
                          items: List.of(currentItems),
                          projectId: project?.id,
                          projectName: project == null
                              ? null
                              : '${project.clientName} — ${project.location}',
                        );

                        setDialogState(() => isSaving = true);
                        int savedId = -1;
                        try {
                          // 1) ALWAYS save to SQLite first via provider.
                          savedId = await ref
                              .read(saleInvoicesProvider.notifier)
                              .saveInvoice(invoice);
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('فشل حفظ الفاتورة: $e')),
                            );
                          }
                          return;
                        }
                        // Re-load the saved invoice so the receipt shows the real DB invoiceNumber.
                        SaleInvoice invoiceToPrint = invoice;
                        try {
                          final all =
                              ref.read(saleInvoicesProvider).invoices;
                          invoiceToPrint = all.firstWhere(
                            (e) => e.id == savedId,
                            orElse: () => invoice,
                          );
                        } catch (_) {}

                        // 2) Then show the A4 print preview — wrapped so a
                        // missing printer never throws and never undoes the save.
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          await PrinterService.showSaleInvoicePreview(
                            context: context,
                            invoice: invoiceToPrint,
                            headerTitle: settings.printerHeader,
                            currency: settings.currency,
                          );
                        }
                      },
                icon: const Icon(Icons.preview, size: 18),
                label: const Text('حفظ ومعاينة وطباعة (A4)'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  // APPEND-ONLY EDIT: add product lines to an existing SALE invoice.
  // Existing lines are shown read-only (no edit / no delete); only NEW
  // lines can be added and saved. Header (number/date/client/project/paid)
  // is never modified; totals derive from items on reload.
  void _showAppendSaleItemsDialog(
      BuildContext context, WidgetRef ref, SaleInvoice invoice) {
    if (invoice.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تعديل الفاتورة: رقم داخلي مفقود')),
      );
      return;
    }
    final products = ref.read(productsProvider).products;
    final settings = ref.read(appSettingsProvider);

    Product? selectedProduct = products.isNotEmpty ? products.first : null;
    final List<InvoiceItem> newItems = [];
    // Local mirror of the persisted lines so deletions reflect instantly
    // inside the dialog (provider reload updates the screen behind it).
    final List<InvoiceItem> existingItems = List.of(invoice.items);
    // Per-line quantity editors for the persisted lines.
    final Map<int, TextEditingController> qtyCtrls = {
      for (final it in invoice.items)
        if (it.id != null)
          it.id!: TextEditingController(text: _fmtQty(it.quantity)),
    };
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(
        text: selectedProduct?.salePrice.toString() ?? '0');
    bool isReturn = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final addedTotal =
              newItems.fold(0.0, (s, i) => s + i.subtotal);
          // Persist a new quantity for one existing line: only the stock
          // difference is applied by the provider; header untouched.
          Future<void> saveQty(InvoiceItem rowItem) async {
            if (rowItem.id == null) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content:
                          Text('تعذر تعديل الصنف: رقم داخلي مفقود')),
                );
              }
              return;
            }
            final raw = qtyCtrls[rowItem.id]?.text.trim() ?? '';
            final q = double.tryParse(raw) ?? -1;
            if (q <= 0) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('أدخل كمية صحيحة (> 0)')),
                );
              }
              qtyCtrls[rowItem.id]?.text = _fmtQty(rowItem.quantity);
              return;
            }
            if (q == rowItem.quantity) return;
            try {
              await ref
                  .read(saleInvoicesProvider.notifier)
                  .updateItemQty(invoice.id!, rowItem.id!, q);
              await ref
                  .read(financialsProvider.notifier)
                  .refreshFinancials();
              setDialogState(() {
                final idx =
                    existingItems.indexWhere((e) => e.id == rowItem.id);
                if (idx >= 0) {
                  existingItems[idx] =
                      existingItems[idx].copyWith(quantity: q);
                }
              });
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content:
                          Text('تم تعديل الكمية وعكس فرق المخزون')),
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                qtyCtrls[rowItem.id]?.text = _fmtQty(rowItem.quantity);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('فشل تعديل الكمية: $e')),
                );
              }
            }
          }

          return AlertDialog(
            scrollable: true,
            title: Text(
                'تعديل الفاتورة #${invoice.invoiceNumber} — إضافة وحذف وتعديل الكميات'),
            content: SizedBox(
              width: 650,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الأصناف الحالية (عدّل الكمية ثم احفظ ✓ أو احذف أي صنف — التعديل والحذف فوري ويعكس حركة المخزون):',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border)),
                    child: existingItems.isEmpty
                        ? const Center(child: Text('لا توجد أصناف'))
                        : ListView.builder(
                            itemCount: existingItems.length,
                            itemBuilder: (ctx, i) {
                              final item = existingItems[i];
                              final qtyEditCtrl = item.id == null
                                  ? null
                                  : qtyCtrls.putIfAbsent(
                                      item.id!,
                                      () => TextEditingController(
                                          text: _fmtQty(item.quantity)));
                              return ListTile(
                                dense: true,
                                title: Text(
                                    '${item.productName}${item.isReturn ? " (مرتجع)" : ""}'),
                                subtitle: Text(
                                    '${item.unit} × ${item.unitPrice} = ${item.subtotal.toStringAsFixed(0)} ${settings.currency}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (qtyEditCtrl == null)
                                      Text(
                                        _fmtQty(item.quantity),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      )
                                    else ...[
                                      SizedBox(
                                        width: 62,
                                        child: TextField(
                                          controller: qtyEditCtrl,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                                  decimal: true),
                                          decoration:
                                              const InputDecoration(
                                                  labelText: 'الكمية',
                                                  isDense: true),
                                          onSubmitted: (_) =>
                                              saveQty(item),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.check,
                                            size: 18,
                                            color:
                                                AppColors.receivables),
                                        tooltip: 'حفظ الكمية الجديدة',
                                        onPressed: () =>
                                            saveQty(item),
                                      ),
                                    ],
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: AppColors.payables),
                                      tooltip: 'حذف الصنف من الفاتورة',
                                      onPressed: () async {
                                        final confirmed =
                                            await showDialog<bool>(
                                          context: ctx,
                                          builder: (c2) => AlertDialog(
                                            title:
                                                const Text('حذف الصنف'),
                                            content: Text(
                                                'حذف "${item.productName}" من الفاتورة #${invoice.invoiceNumber}؟\nسيتم عكس حركة المخزون الخاصة به.'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          c2, false),
                                                  child: const Text(
                                                      'إلغاء')),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(c2, true),
                                                style:
                                                    ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            AppColors
                                                                .payables,
                                                        foregroundColor:
                                                            Colors.white),
                                                child:
                                                    const Text('حذف'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed != true) return;
                                        if (item.id == null) {
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'تعذر حذف الصنف: رقم داخلي مفقود')),
                                            );
                                          }
                                          return;
                                        }
                                        try {
                                          await ref
                                              .read(saleInvoicesProvider
                                                  .notifier)
                                              .removeItem(
                                                  invoice.id!, item.id!);
                                          await ref
                                              .read(financialsProvider
                                                  .notifier)
                                              .refreshFinancials();
                                          setDialogState(() =>
                                              existingItems.removeWhere(
                                                  (e) =>
                                                      e.id ==
                                                      item.id));
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'تم حذف الصنف وعكس حركة المخزون')),
                                            );
                                          }
                                        } catch (e) {
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'فشل حذف الصنف: $e')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 24),
                  const Text('إضافة أصناف جديدة:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _productSearchField(
                          products: products,
                          selected: selectedProduct,
                          label: 'ابحث عن المنتج...',
                          onChanged: (val) {
                            setDialogState(() {
                              selectedProduct = val;
                              priceCtrl.text =
                                  val?.salePrice.toString() ?? '0';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'الكمية')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'السعر')),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Checkbox(
                              value: isReturn,
                              onChanged: (v) => setDialogState(
                                  () => isReturn = v ?? false)),
                          const Text('مرتجع',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: AppColors.accent, size: 30),
                        onPressed: () {
                          if (selectedProduct == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('اختر المنتج من القائمة أولاً')),
                            );
                            return;
                          }
                          if (selectedProduct!.id == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('بيانات المنتج غير صالحة')),
                            );
                            return;
                          }
                          final qty =
                              double.tryParse(qtyCtrl.text.trim()) ?? -1;
                          final price = double.tryParse(
                                  priceCtrl.text.trim()) ??
                              selectedProduct!.salePrice;
                          if (qty <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('أدخل كمية صحيحة (> 0)')),
                            );
                            return;
                          }
                          if (price < 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'أدخل سعراً صحيحاً (0 أو أكثر)')),
                            );
                            return;
                          }
                          setDialogState(() {
                            newItems.add(InvoiceItem(
                              productId: selectedProduct!.id!,
                              productName: selectedProduct!.name,
                              quantity: qty,
                              unitPrice: price,
                              unit: selectedProduct!.unit,
                              isReturn: isReturn,
                            ));
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border)),
                    child: newItems.isEmpty
                        ? const Center(
                            child: Text('لم تتم إضافة أصناف جديدة بعد'))
                        : ListView.builder(
                            itemCount: newItems.length,
                            itemBuilder: (ctx, i) {
                              final item = newItems[i];
                              return ListTile(
                                dense: true,
                                title: Text(
                                    '${item.productName}${item.isReturn ? " (مرتجع)" : ""}'),
                                subtitle: Text(
                                    '${item.quantity} ${item.unit} × ${item.unitPrice}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                        '${item.subtotal.toStringAsFixed(0)} ${settings.currency}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 16),
                                        onPressed: () => setDialogState(
                                            () => newItems.removeAt(i))),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'إجمالي المضاف الجديد: ${addedTotal.toStringAsFixed(0)} ${settings.currency}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.accent)),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (newItems.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'أضف صنفاً جديداً واحداً على الأقل')),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          await ref
                              .read(saleInvoicesProvider.notifier)
                              .appendItems(invoice.id!, newItems);
                          await ref
                              .read(financialsProvider.notifier)
                              .refreshFinancials();
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'تمت إضافة الأصناف إلى الفاتورة بنجاح')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text('فشل تعديل الفاتورة: $e')),
                            );
                          }
                        }
                      },
                child: const Text('حفظ الإضافات'),
              ),
            ],
          );
        },
      ),
    );
  }

  // APPEND-ONLY EDIT: add product lines to an existing PURCHASE invoice.
  // Same contract as [_showAppendSaleItemsDialog]: existing lines are
  // read-only, header untouched, only new lines are appended.
  void _showAppendPurchaseItemsDialog(
      BuildContext context, WidgetRef ref, PurchaseInvoice invoice) {
    if (invoice.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تعديل الفاتورة: رقم داخلي مفقود')),
      );
      return;
    }
    final products = ref.read(productsProvider).products;
    final settings = ref.read(appSettingsProvider);

    Product? selectedProduct = products.isNotEmpty ? products.first : null;
    final List<InvoiceItem> newItems = [];
    // Local mirror of the persisted lines so deletions reflect instantly
    // inside the dialog (provider reload updates the screen behind it).
    final List<InvoiceItem> existingItems = List.of(invoice.items);
    // Per-line quantity editors for the persisted lines.
    final Map<int, TextEditingController> qtyCtrls = {
      for (final it in invoice.items)
        if (it.id != null)
          it.id!: TextEditingController(text: _fmtQty(it.quantity)),
    };
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(
        text: selectedProduct?.costPrice.toString() ?? '0');
    bool isReturn = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final addedTotal =
              newItems.fold(0.0, (s, i) => s + i.subtotal);
          // Persist a new quantity for one existing line: only the stock
          // difference is applied by the provider; header untouched.
          Future<void> saveQty(InvoiceItem rowItem) async {
            if (rowItem.id == null) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content:
                          Text('تعذر تعديل الصنف: رقم داخلي مفقود')),
                );
              }
              return;
            }
            final raw = qtyCtrls[rowItem.id]?.text.trim() ?? '';
            final q = double.tryParse(raw) ?? -1;
            if (q <= 0) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('أدخل كمية صحيحة (> 0)')),
                );
              }
              qtyCtrls[rowItem.id]?.text = _fmtQty(rowItem.quantity);
              return;
            }
            if (q == rowItem.quantity) return;
            try {
              await ref
                  .read(purchaseInvoicesProvider.notifier)
                  .updateItemQty(invoice.id!, rowItem.id!, q);
              await ref
                  .read(financialsProvider.notifier)
                  .refreshFinancials();
              setDialogState(() {
                final idx =
                    existingItems.indexWhere((e) => e.id == rowItem.id);
                if (idx >= 0) {
                  existingItems[idx] =
                      existingItems[idx].copyWith(quantity: q);
                }
              });
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content:
                          Text('تم تعديل الكمية وعكس فرق المخزون')),
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                qtyCtrls[rowItem.id]?.text = _fmtQty(rowItem.quantity);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('فشل تعديل الكمية: $e')),
                );
              }
            }
          }

          return AlertDialog(
            scrollable: true,
            title: Text(
                'تعديل فاتورة الشراء #${invoice.invoiceNumber} — إضافة وحذف وتعديل الكميات'),
            content: SizedBox(
              width: 650,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الأصناف الحالية (عدّل الكمية ثم احفظ ✓ أو احذف أي صنف — التعديل والحذف فوري ويعكس حركة المخزون):',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border)),
                    child: existingItems.isEmpty
                        ? const Center(child: Text('لا توجد أصناف'))
                        : ListView.builder(
                            itemCount: existingItems.length,
                            itemBuilder: (ctx, i) {
                              final item = existingItems[i];
                              final qtyEditCtrl = item.id == null
                                  ? null
                                  : qtyCtrls.putIfAbsent(
                                      item.id!,
                                      () => TextEditingController(
                                          text: _fmtQty(item.quantity)));
                              return ListTile(
                                dense: true,
                                title: Text(
                                    '${item.productName}${item.isReturn ? " (مرتجع)" : ""}'),
                                subtitle: Text(
                                    '${item.unit} × ${item.unitPrice} = ${item.subtotal.toStringAsFixed(0)} ${settings.currency}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (qtyEditCtrl == null)
                                      Text(
                                        _fmtQty(item.quantity),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      )
                                    else ...[
                                      SizedBox(
                                        width: 62,
                                        child: TextField(
                                          controller: qtyEditCtrl,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                                  decimal: true),
                                          decoration:
                                              const InputDecoration(
                                                  labelText: 'الكمية',
                                                  isDense: true),
                                          onSubmitted: (_) =>
                                              saveQty(item),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.check,
                                            size: 18,
                                            color:
                                                AppColors.receivables),
                                        tooltip: 'حفظ الكمية الجديدة',
                                        onPressed: () =>
                                            saveQty(item),
                                      ),
                                    ],
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: AppColors.payables),
                                      tooltip: 'حذف الصنف من الفاتورة',
                                      onPressed: () async {
                                        final confirmed =
                                            await showDialog<bool>(
                                          context: ctx,
                                          builder: (c2) => AlertDialog(
                                            title:
                                                const Text('حذف الصنف'),
                                            content: Text(
                                                'حذف "${item.productName}" من فاتورة الشراء #${invoice.invoiceNumber}؟\nسيتم عكس حركة المخزون الخاصة به.'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          c2, false),
                                                  child: const Text(
                                                      'إلغاء')),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(c2, true),
                                                style:
                                                    ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            AppColors
                                                                .payables,
                                                        foregroundColor:
                                                            Colors.white),
                                                child:
                                                    const Text('حذف'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed != true) return;
                                        if (item.id == null) {
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'تعذر حذف الصنف: رقم داخلي مفقود')),
                                            );
                                          }
                                          return;
                                        }
                                        try {
                                          await ref
                                              .read(purchaseInvoicesProvider
                                                  .notifier)
                                              .removeItem(
                                                  invoice.id!, item.id!);
                                          await ref
                                              .read(financialsProvider
                                                  .notifier)
                                              .refreshFinancials();
                                          setDialogState(() =>
                                              existingItems.removeWhere(
                                                  (e) =>
                                                      e.id ==
                                                      item.id));
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'تم حذف الصنف وعكس حركة المخزون')),
                                            );
                                          }
                                        } catch (e) {
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'فشل حذف الصنف: $e')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 24),
                  const Text('إضافة أصناف جديدة:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _productSearchField(
                          products: products,
                          selected: selectedProduct,
                          label: 'ابحث عن المنتج...',
                          onChanged: (val) {
                            setDialogState(() {
                              selectedProduct = val;
                              priceCtrl.text =
                                  val?.costPrice.toString() ?? '0';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'الكمية')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'سعر الوحدة')),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Checkbox(
                              value: isReturn,
                              onChanged: (v) => setDialogState(
                                  () => isReturn = v ?? false)),
                          const Text('مرتجع',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: AppColors.primary, size: 30),
                        onPressed: () {
                          if (selectedProduct == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('اختر المنتج من القائمة أولاً')),
                            );
                            return;
                          }
                          if (selectedProduct!.id == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('بيانات المنتج غير صالحة')),
                            );
                            return;
                          }
                          final qty =
                              double.tryParse(qtyCtrl.text.trim()) ?? -1;
                          final price = double.tryParse(
                                  priceCtrl.text.trim()) ??
                              selectedProduct!.costPrice;
                          if (qty <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('أدخل كمية صحيحة (> 0)')),
                            );
                            return;
                          }
                          if (price < 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'أدخل سعراً صحيحاً (0 أو أكثر)')),
                            );
                            return;
                          }
                          setDialogState(() {
                            newItems.add(InvoiceItem(
                              productId: selectedProduct!.id!,
                              productName: selectedProduct!.name,
                              quantity: qty,
                              unitPrice: price,
                              unit: selectedProduct!.unit,
                              isReturn: isReturn,
                            ));
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border)),
                    child: newItems.isEmpty
                        ? const Center(
                            child: Text('لم تتم إضافة أصناف جديدة بعد'))
                        : ListView.builder(
                            itemCount: newItems.length,
                            itemBuilder: (ctx, i) {
                              final item = newItems[i];
                              return ListTile(
                                dense: true,
                                title: Text(
                                    '${item.productName}${item.isReturn ? " (مرتجع)" : ""}'),
                                subtitle: Text(
                                    '${item.quantity} ${item.unit} × ${item.unitPrice}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                        '${item.subtotal.toStringAsFixed(0)} ${settings.currency}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 16),
                                        onPressed: () => setDialogState(
                                            () => newItems.removeAt(i))),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'إجمالي المضاف الجديد: ${addedTotal.toStringAsFixed(0)} ${settings.currency}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary)),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (newItems.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'أضف صنفاً جديداً واحداً على الأقل')),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          await ref
                              .read(purchaseInvoicesProvider.notifier)
                              .appendItems(invoice.id!, newItems);
                          await ref
                              .read(financialsProvider.notifier)
                              .refreshFinancials();
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'تمت إضافة الأصناف إلى الفاتورة بنجاح')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text('فشل تعديل الفاتورة: $e')),
                            );
                          }
                        }
                      },
                child: const Text('حفظ الإضافات'),
              ),
            ],
          );
        },
      ),
    );
  }

  // DIALOG FOR CREATING AN APPROVED PROJECT (party + location).
  // After creation, standard invoices can be added to it from its card.
  void _showCreateProjectDialog(BuildContext context, WidgetRef ref,
      {ApprovedProject? existing}) {
    final clients = ref.read(clientsProvider).clients;
    Client? selectedClient;
    if (existing != null) {
      try {
        selectedClient =
            clients.firstWhere((c) => c.id == existing.clientId);
      } catch (_) {
        selectedClient = null;
      }
    } else if (clients.isNotEmpty) {
      selectedClient = clients.first;
    }
    final locationCtrl =
        TextEditingController(text: existing?.location ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            scrollable: true,
            title: Text(existing == null
                ? 'إنشاء مشروع معتمد جديد'
                : 'تعديل المشروع المعتمد'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الطرف المعتمد:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _clientSearchField(
                    clients: clients,
                    selected: selectedClient,
                    label: 'ابحث عن المعتمد...',
                    onChanged: (val) =>
                        setDialogState(() => selectedClient = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                        labelText: 'موقع المشروع'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'ملاحظات المشروع'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (selectedClient == null ||
                            selectedClient!.id == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'اختر الطرف المعتمد أولاً (أضف معتمداً من شاشة الأشخاص إن لزم)')),
                          );
                          return;
                        }
                        if (locationCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('أدخل موقع المشروع')),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          if (existing == null) {
                            await ref
                                .read(projectsProvider.notifier)
                                .addProject(ApprovedProject(
                                  clientId: selectedClient!.id!,
                                  clientName: selectedClient!.name,
                                  location:
                                      locationCtrl.text.trim(),
                                  notes: notesCtrl.text.trim(),
                                  createdAt: DateTime.now(),
                                ));
                          } else {
                            await ref
                                .read(projectsProvider.notifier)
                                .updateProject(existing.copyWith(
                                  clientId: selectedClient!.id!,
                                  clientName:
                                      selectedClient!.name,
                                  location:
                                      locationCtrl.text.trim(),
                                  notes: notesCtrl.text.trim(),
                                ));
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'تم حفظ المشروع المعتمد بنجاح')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(
                                () => isSaving = false);
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'فشل حفظ المشروع: $e')),
                            );
                          }
                        }
                      },
                child: const Text('حفظ المشروع'),
              ),
            ],
          );
        },
      ),
    );
  }

  // DIALOG FOR CREATING A RETURN INVOICE for an Approved Contractor Project.
  // Flow: select project -> select original invoice -> set returned quantities
  // -> confirm. The original invoice is never modified; the return row
  // restocks inventory and deducts from the project balance.
  void _showCreateReturnDialog(BuildContext context, WidgetRef ref,
      {ApprovedProject? fixedProject}) {
    final projects = ref.read(projectsProvider).projects;
    final allSales = ref.read(saleInvoicesProvider).invoices;
    final settings = ref.read(appSettingsProvider);

    ApprovedProject? selectedProject =
        fixedProject ?? (projects.isNotEmpty ? projects.first : null);
    SaleInvoice? selectedOriginal;
    final Map<int, TextEditingController> qtyCtrls = {};
    bool isSaving = false;

    List<SaleInvoice> originalsFor(ApprovedProject? p) {
      if (p == null || p.id == null) return const [];
      return allSales
          .where((i) =>
              !i.isReturnInvoice &&
              i.isProjectLike &&
              i.projectId == p.id)
          .toList();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final originals = originalsFor(selectedProject);
          if (selectedOriginal != null &&
              !originals.any((o) => o.id == selectedOriginal!.id)) {
            selectedOriginal = null;
            qtyCtrls.clear();
          }
          double returnTotal = 0.0;
          if (selectedOriginal != null) {
            for (final item in selectedOriginal!.items) {
              final c = qtyCtrls[item.productId];
              final q = double.tryParse(c?.text.trim() ?? '') ?? 0.0;
              if (q > 0) returnTotal += q * item.unitPrice;
            }
          }

          return AlertDialog(
            scrollable: true,
            title: const Text('إنشاء فاتورة إرجاع (مشروع مقاول معتمد)'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المشروع المعتمد:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButton<ApprovedProject>(
                    isExpanded: true,
                    value: selectedProject,
                    hint: const Text('اختر المشروع'),
                    items: projects
                        .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                                '${p.clientName} — ${p.location}')))
                        .toList(),
                    onChanged: fixedProject != null
                        ? null
                        : (val) => setDialogState(() {
                              selectedProject = val;
                              selectedOriginal = null;
                              qtyCtrls.clear();
                            }),
                  ),
                  const SizedBox(height: 12),
                  const Text('الفاتورة الأصلية:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButton<SaleInvoice>(
                    isExpanded: true,
                    value: selectedOriginal,
                    hint: Text(selectedProject == null
                        ? 'اختر المشروع أولاً'
                        : originals.isEmpty
                            ? 'لا توجد فواتير لهذا المشروع'
                            : 'اختر الفاتورة الأصلية'),
                    items: originals
                        .map((o) => DropdownMenuItem(
                            value: o,
                            child: Text(
                                '#${o.invoiceNumber} — ${o.totalAmount.toStringAsFixed(0)} ${settings.currency} (${o.date.toString().split(' ').first})')))
                        .toList(),
                    onChanged: (val) => setDialogState(() {
                      selectedOriginal = val;
                      qtyCtrls.clear();
                      if (val != null) {
                        for (final item in val.items) {
                          qtyCtrls[item.productId] =
                              TextEditingController(text: '0');
                        }
                      }
                    }),
                  ),
                  if (selectedOriginal != null) ...[
                    const SizedBox(height: 12),
                    const Text(
                        'الكميات المرجعة (0 = بدون إرجاع لهذا الصنف):',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...selectedOriginal!.items.map((item) {
                      final ctrl = qtyCtrls[item.productId]!;
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                  '${item.productName} (الأصلية: ${item.quantity} ${item.unit} × ${item.unitPrice})',
                                  style: const TextStyle(
                                      fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: ctrl,
                                keyboardType:
                                    TextInputType.number,
                                onChanged: (_) =>
                                    setDialogState(() {}),
                                decoration:
                                    const InputDecoration(
                                        labelText:
                                            'الكمية المرجعة'),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Text(
                      'قيمة الإرجاع: ${returnTotal.toStringAsFixed(0)} ${settings.currency}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.warning),
                    ),
                    const Text(
                      'تنبيه: الفاتورة الأصلية تبقى كما هي. سيُنشأ سند إرجاع يعيد البضاعة للمخزن ويخصم القيمة من رصيد المشروع.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (selectedProject == null ||
                            selectedProject!.id == null) {
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'اختر المشروع المعتمد أولاً')),
                          );
                          return;
                        }
                        if (selectedOriginal == null ||
                            selectedOriginal!.id == null) {
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'اختر الفاتورة الأصلية للإرجاع')),
                          );
                          return;
                        }
                        final List<InvoiceItem> retItems =
                            [];
                        for (final item
                            in selectedOriginal!.items) {
                          final q = double.tryParse(
                                  qtyCtrls[item.productId]
                                          ?.text
                                          .trim() ??
                                      '') ??
                              -1;
                          if (q < 0) {
                            ScaffoldMessenger.of(ctx)
                                .showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'كمية الإرجاع غير صالحة للصنف "${item.productName}"')),
                            );
                            return;
                          }
                          if (q == 0) continue;
                          if (q > item.quantity) {
                            ScaffoldMessenger.of(ctx)
                                .showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'كمية الإرجاع للصنف "${item.productName}" تتجاوز الكمية الأصلية (${item.quantity})')),
                            );
                            return;
                          }
                          retItems.add(InvoiceItem(
                            productId: item.productId,
                            productName: item.productName,
                            quantity: q,
                            unitPrice: item.unitPrice,
                            unit: item.unit,
                          ));
                        }
                        if (retItems.isEmpty) {
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'حدد كمية مرجعة واحدة على الأقل')),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          final ret = SaleInvoice(
                            invoiceNumber: '',
                            clientId: selectedProject!
                                .clientId,
                            clientName: selectedProject!
                                .clientName,
                            type:
                                SaleInvoiceType.salesReturn,
                            date: DateTime.now(),
                            notes:
                                'إرجاع للفاتورة الأصلية #${selectedOriginal!.invoiceNumber}',
                            items: retItems,
                            projectId:
                                selectedProject!.id,
                            projectName:
                                '${selectedProject!.clientName} — ${selectedProject!.location}',
                            isReturnInvoice: true,
                            returnOfInvoiceId:
                                selectedOriginal!.id,
                          );
                          await ref
                              .read(saleInvoicesProvider
                                  .notifier)
                              .saveInvoice(ret);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'تم تأكيد فاتورة الإرجاع وإعادة البضاعة للمخزن')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(
                                () => isSaving = false);
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'فشل حفظ فاتورة الإرجاع: $e')),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('تأكيد الإرجاع'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }
}
