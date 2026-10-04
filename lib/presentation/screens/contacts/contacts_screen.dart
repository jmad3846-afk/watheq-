import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/models/supplier.dart';
import '../../../domain/models/client.dart';
import '../../providers/suppliers_provider.dart';
import '../../providers/clients_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/payments_provider.dart';
import '../../providers/purchase_invoices_provider.dart';
import '../../providers/sale_invoices_provider.dart';
import '../../widgets/payment_history_dialog.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Keep the header add-button in sync with the visible tab.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header Bar with Tabs & Search
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
                    width: 320,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.accent,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      tabs: const [
                        Tab(text: 'قسم الموردين'),
                        Tab(text: 'قسم المعتمدين (العملاء)'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_tabController.index == 0) {
                        _showAddEditSupplierDialog(context, ref);
                      } else {
                        _showAddEditClientDialog(context, ref);
                      }
                    },
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: Text(_tabController.index == 0 ? 'إضافة مورد جديد' : 'إضافة معتمد جديد'),
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

          // Tab Body Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSuppliersTab(context, ref),
                _buildClientsTab(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // SUPPLIERS TAB
  Widget _buildSuppliersTab(BuildContext context, WidgetRef ref) {
    final state = ref.watch(suppliersProvider);
    final currency = ref.watch(appSettingsProvider).currency;
    final invoices = ref.watch(purchaseInvoicesProvider).invoices;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Search Field
          TextField(
            onChanged: (q) => ref.read(suppliersProvider.notifier).setSearchQuery(q),
            decoration: InputDecoration(
              hintText: 'ابحث عن مورد بالاسم، الهاتف، أو الموقع...',
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
                : state.filteredSuppliers.isEmpty
                    ? const Center(child: Text('لا يوجد موردين مطاطين'))
                    : ListView.builder(
                        itemCount: state.filteredSuppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = state.filteredSuppliers[index];
                          final suppInvoices = invoices.where((i) => i.supplierId == supplier.id).toList();
                          final totalDebt = suppInvoices.fold(0.0, (sum, i) => sum + i.remainingBalance);

                          // Explicit Row layout (not ListTile): ListTile caps the
                          // trailing height to the tile height, which clipped
                          // the debt text + edit/delete buttons. Here the card
                          // sizes itself to its content — no overflow.
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    child: const Icon(Icons.local_shipping, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          supplier.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'الهاتف: ${supplier.phone} • العنوان / المنطقة: ${supplier.location}\n'
                                          'الأصناف: ${supplier.itemsSold.isEmpty ? "غير محدد" : supplier.itemsSold}'
                                          '${supplier.notes.isNotEmpty ? "\nملاحظات: ${supplier.notes}" : ""}',
                                        ),
                                        const SizedBox(height: 4),
                                        _lastPaymentLine(
                                          ref,
                                          entityType: 'supplier',
                                          entityId: supplier.id,
                                          currency: currency,
                                          emptyLabel: 'لا توجد دفعات مسددة لهذا المورد بعد',
                                          filledPrefix: 'آخر دفعة مسددة للمورد',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 220),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'المتبقي للمورد: ${totalDebt.toStringAsFixed(0)} $currency',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: totalDebt > 0 ? AppColors.payables : AppColors.receivables,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.history, size: 18, color: AppColors.accent),
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
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                              onPressed: () => _showAddEditSupplierDialog(context, ref, supplier: supplier),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.payables),
                                              onPressed: () => _confirmDeleteSupplier(context, ref, supplier.id, supplier.name),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // CLIENTS TAB
  Widget _buildClientsTab(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clientsProvider);
    final currency = ref.watch(appSettingsProvider).currency;
    final invoices = ref.watch(saleInvoicesProvider).invoices;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            onChanged: (q) => ref.read(clientsProvider.notifier).setSearchQuery(q),
            decoration: InputDecoration(
              hintText: 'ابحث عن معتمد بالاسم، الهاتف، السكن، أو المهنة...',
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
                : state.filteredClients.isEmpty
                    ? const Center(child: Text('لا يوجد معتمدين مضافين'))
                    : ListView.builder(
                        itemCount: state.filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = state.filteredClients[index];
                          final clientInvoices = invoices.where((i) => i.clientId == client.id).toList();
                          // Effective balance: normal invoices' remainder minus
                          // return-invoice values (returns deduct from balance).
                          double issuedSum = 0.0, paidSum = 0.0, returnsSum = 0.0;
                          for (final i in clientInvoices) {
                            if (i.isReturnInvoice) {
                              returnsSum += i.totalAmount;
                            } else {
                              issuedSum += i.totalAmount;
                              paidSum += i.paidAmount;
                            }
                          }
                          final totalDebt = issuedSum - paidSum - returnsSum;

                          // Explicit Row layout (not ListTile): ListTile caps the
                          // trailing height to the tile height, which clipped
                          // the debt text + edit/delete buttons. Here the card
                          // sizes itself to its content — no overflow.
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.accent.withOpacity(0.15),
                                    child: const Icon(Icons.person, color: AppColors.accent),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          client.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'الهاتف: ${client.phone} • السكن: ${client.address} • المهنة: ${client.profession}',
                                        ),
                                        const SizedBox(height: 4),
                                        _lastPaymentLine(
                                          ref,
                                          entityType: 'client',
                                          entityId: client.id,
                                          currency: currency,
                                          emptyLabel: 'لا توجد دفعات مستلمة من هذا المعتمد بعد',
                                          filledPrefix: 'آخر دفعة مستلمة من المعتمد',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 220),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'المستحق ("لنا"): ${totalDebt.toStringAsFixed(0)} $currency',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: totalDebt > 0 ? AppColors.receivables : AppColors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.history, size: 18, color: AppColors.accent),
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
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                              onPressed: () => _showAddEditClientDialog(context, ref, client: client),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.payables),
                                              onPressed: () => _confirmDeleteClient(context, ref, client.id, client.name),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddEditSupplierDialog(BuildContext context, WidgetRef ref, {Supplier? supplier}) {
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final locCtrl = TextEditingController(text: supplier?.location ?? '');
    final itemsCtrl = TextEditingController(text: supplier?.itemsSold ?? '');
    final notesCtrl = TextEditingController(text: supplier?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text(supplier == null ? 'إضافة مورد جديد' : 'تعديل بيانات المورد'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المورد')),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                const SizedBox(height: 10),
                TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'العنوان / المنطقة')),
                const SizedBox(height: 10),
                TextField(controller: itemsCtrl, decoration: const InputDecoration(labelText: 'الأصناف المباعة')),
                const SizedBox(height: 10),
                TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات / الرصيد الأولي إن وجد')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;

                final newSupplier = Supplier(
                  id: supplier?.id,
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  location: locCtrl.text.trim(),
                  itemsSold: itemsCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                );

                if (supplier == null) {
                  ref.read(suppliersProvider.notifier).addSupplier(newSupplier);
                } else {
                  ref.read(suppliersProvider.notifier).updateSupplier(newSupplier);
                }
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
    );
  }

  void _showAddEditClientDialog(BuildContext context, WidgetRef ref, {Client? client}) {
    final nameCtrl = TextEditingController(text: client?.name ?? '');
    final phoneCtrl = TextEditingController(text: client?.phone ?? '');
    final addrCtrl = TextEditingController(text: client?.address ?? '');
    final profCtrl = TextEditingController(text: client?.profession ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(client == null ? 'إضافة معتمد جديد' : 'تعديل بيانات المعتمد'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المعتمد / العميل')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
              const SizedBox(height: 10),
              TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'عنوان السكن')),
              const SizedBox(height: 10),
              TextField(controller: profCtrl, decoration: const InputDecoration(labelText: 'المهنة / العمل')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) return;

              final newClient = Client(
                id: client?.id,
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                address: addrCtrl.text.trim(),
                profession: profCtrl.text.trim(),
              );

              if (client == null) {
                ref.read(clientsProvider.notifier).addClient(newClient);
              } else {
                ref.read(clientsProvider.notifier).updateClient(newClient);
              }
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  /// One-line "last payment" summary with its date, e.g.
  /// "آخر دفعة مسددة للمورد: 150 ... بتاريخ 2026/09/12".
  Widget _lastPaymentLine(
    WidgetRef ref, {
    required String entityType,
    required int? entityId,
    required String currency,
    required String emptyLabel,
    required String filledPrefix,
  }) {
    final last = ref.watch(paymentsProvider).lastFor(entityType, entityId);
    if (last == null) {
      return Text(
        emptyLabel,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      );
    }
    return Text(
      '$filledPrefix: ${last.amount.toStringAsFixed(0)} $currency • بتاريخ ${DateFormat('yyyy/MM/dd').format(last.date)}',
      style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600),
    );
  }

  double _supplierOutstanding(int? supplierId) {
    if (supplierId == null) return 0.0;
    final invoices = ref.read(purchaseInvoicesProvider).invoices;
    return invoices
        .where((i) => i.supplierId == supplierId)
        .fold(0.0, (sum, i) => sum + i.remainingBalance);
  }

  double _clientOutstanding(int? clientId) {
    if (clientId == null) return 0.0;
    final invoices = ref.read(saleInvoicesProvider).invoices;
    double issued = 0.0, paid = 0.0, returns = 0.0;
    for (final i in invoices.where((e) => e.clientId == clientId)) {
      if (i.isReturnInvoice) {
        returns += i.totalAmount;
      } else {
        issued += i.totalAmount;
        paid += i.paidAmount;
      }
    }
    return issued - paid - returns;
  }

  /// Deletes a supplier only when nothing is owed to them.
  Future<void> _confirmDeleteSupplier(
      BuildContext context, WidgetRef ref, int? id, String name) async {
    if (id == null) return;
    final currency = ref.read(appSettingsProvider).currency;
    final debt = _supplierOutstanding(id);
    if (debt > 0.01) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'لا يمكن حذف المورد "$name" — يوجد رصيد مستحق له: ${debt.toStringAsFixed(0)} $currency. سدد مستحقاته أولاً.'),
          ),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المورد "$name"؟'),
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
    if (confirmed == true) {
      try {
        await ref.read(suppliersProvider.notifier).deleteSupplier(id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل حذف المورد: $e')),
          );
        }
      }
    }
  }

  /// Deletes a client only when they owe us nothing.
  Future<void> _confirmDeleteClient(
      BuildContext context, WidgetRef ref, int? id, String name) async {
    if (id == null) return;
    final currency = ref.read(appSettingsProvider).currency;
    final debt = _clientOutstanding(id);
    if (debt > 0.01) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'لا يمكن حذف المعتمد "$name" — يوجد مبلغ مستحق علينا تحصيله: ${debt.toStringAsFixed(0)} $currency. حصّل المستحقات أولاً.'),
          ),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المعتمد "$name"؟'),
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
    if (confirmed == true) {
      try {
        await ref.read(clientsProvider.notifier).deleteClient(id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل حذف المعتمد: $e')),
          );
        }
      }
    }
  }
}
