import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/projects_provider.dart';
import '../../providers/suppliers_provider.dart';
import '../../providers/sale_invoices_provider.dart';
import '../../providers/purchase_invoices_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(dashboardKPIProvider);
    final settings = ref.watch(appSettingsProvider);

    final double receivables = kpis['receivables'] as double;
    final double payables = kpis['payables'] as double;
    final int productCount = kpis['productCount'] as int;
    final int lowStockCount = kpis['lowStockCount'] as int;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Welcome Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مرحباً بك في نظام "وثق" المحاسبي',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'إدارة المخازن والفواتير والديون بأمان وسرعة عالية دون الحاجة للاتصال بالإنترنت.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.currency_exchange, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'العملة: ${settings.currency}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'ملخص المؤشرات المالية والمخزون',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // KPI Summary Cards (stack vertically on narrow windows).
            LayoutBuilder(
              builder: (ctx, constraints) {
                final narrow = constraints.maxWidth < 720;
                final cards = <Widget>[
                  _buildKPICard(
                    context: context,
                    title: 'ديون المستحقات ("لنا")',
                    value:
                        '${receivables.toStringAsFixed(0)} ${settings.currency}',
                    subtitle:
                        'مستحقات المشاريع المعتمدة فقط — اضغط للتفصيل',
                    icon: Icons.call_made_rounded,
                    color: AppColors.receivables,
                    onTap: () => _showReceivablesModal(
                        context, ref, settings.currency),
                  ),
                  _buildKPICard(
                    context: context,
                    title: 'ديون الموردين ("علينا")',
                    value:
                        '${payables.toStringAsFixed(0)} ${settings.currency}',
                    subtitle:
                        'إجمالي المستحقات الواجب دفعها للموردين',
                    icon: Icons.call_received_rounded,
                    color: AppColors.payables,
                    onTap: () => _showPayablesModal(
                        context, ref, settings.currency),
                  ),
                  _buildKPICard(
                    context: context,
                    title: 'عدد المنتجات',
                    value: '$productCount صنف',
                    subtitle: lowStockCount > 0
                        ? '$lowStockCount صنف منخفض المخزون'
                        : 'المخزون بوضع ممتاز',
                    icon: Icons.inventory_2_rounded,
                    color: lowStockCount > 0
                        ? AppColors.warning
                        : AppColors.info,
                    onTap: null,
                  ),
                ];
                if (narrow) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      cards[0],
                      const SizedBox(height: 16),
                      cards[1],
                      const SizedBox(height: 16),
                      cards[2],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 20),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 20),
                    Expanded(child: cards[2]),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                if (onTap != null)
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Project-only receivables breakdown: each project with its collectible
  /// amount (issued − paid − returns), plus legacy unlinked credit invoices.
  /// Standard cash sales never appear here — they are settled immediately.
  void _showReceivablesModal(BuildContext context, WidgetRef ref, String currency) {
    final projects = ref.read(projectsProvider).projects;
    final invoices = ref.read(saleInvoicesProvider).invoices;

    double projectOwed(int? projectId) {
      double issued = 0.0, paid = 0.0, returns = 0.0;
      for (final i in invoices) {
        if (i.projectId != projectId) continue;
        if (i.isReturnInvoice) {
          returns += i.totalAmount;
        } else {
          issued += i.totalAmount;
          paid += i.paidAmount;
        }
      }
      return issued - paid - returns;
    }

    final activeProjects =
        projects.where((p) => projectOwed(p.id) > 0.01).toList();
    final legacy = invoices
        .where((i) =>
            !i.isReturnInvoice &&
            i.projectId == null &&
            i.type.name == 'long' &&
            i.remainingBalance > 0)
        .toList();
    final legacyOwed =
        legacy.fold(0.0, (sum, i) => sum + i.remainingBalance);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'مستحقات المشاريع المعتمدة ("لنا")',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: (activeProjects.isEmpty && legacy.isEmpty)
                    ? const Center(
                        child: Text(
                            'لا توجد مستحقات — جميع المشاريع مسددة'))
                    : ListView(
                        children: [
                          ...activeProjects.map((p) {
                            final owed = projectOwed(p.id);
                            final pins = invoices
                                .where((i) =>
                                    i.projectId == p.id &&
                                    !i.isReturnInvoice)
                                .toList();
                            final rets = invoices
                                .where((i) =>
                                    i.projectId == p.id &&
                                    i.isReturnInvoice)
                                .toList();
                            return ExpansionTile(
                              leading: const Icon(Icons.business,
                                  color: AppColors.primary),
                              title: Text(
                                  '${p.clientName} — ${p.location.isEmpty ? "بدون موقع" : p.location}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  'فواتير: ${pins.length} • إرجاع: ${rets.length}'),
                              trailing: Text(
                                  '${owed.toStringAsFixed(0)} $currency',
                                  style: const TextStyle(
                                      color: AppColors.receivables,
                                      fontWeight: FontWeight.bold)),
                              children: [
                                ...pins.map((inv) {
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                        Icons.receipt_long,
                                        color: AppColors.primary,
                                        size: 20),
                                    title: Text(
                                        'فاتورة رقم: ${inv.invoiceNumber}',
                                        style: const TextStyle(
                                            fontSize: 13)),
                                    subtitle: Text(
                                        'تاريخ: ${inv.date.toString().split(' ').first} • مسدد: ${inv.paidAmount.toStringAsFixed(0)} $currency',
                                        style: const TextStyle(
                                            fontSize: 12)),
                                    trailing: Text(
                                        'يُحصّل: ${inv.remainingBalance.toStringAsFixed(0)} $currency',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.bold)),
                                  );
                                }),
                                ...rets.map((inv) {
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                        Icons.keyboard_return,
                                        color: AppColors.warning,
                                        size: 20),
                                    title: Text(
                                        'إرجاع #${inv.invoiceNumber}',
                                        style: const TextStyle(
                                            fontSize: 13)),
                                    trailing: Text(
                                        '-${inv.totalAmount.toStringAsFixed(0)} $currency',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color:
                                                AppColors.warning,
                                            fontWeight:
                                                FontWeight.bold)),
                                  );
                                }),
                              ],
                            );
                          }),
                          if (legacy.isNotEmpty)
                            ExpansionTile(
                              leading: const Icon(Icons.history,
                                  color: AppColors.warning),
                              title: const Text(
                                  'فواتير آجلة قديمة (بدون مشروع)',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                              trailing: Text(
                                  '${legacyOwed.toStringAsFixed(0)} $currency',
                                  style: const TextStyle(
                                      color: AppColors.receivables,
                                      fontWeight: FontWeight.bold)),
                              children: legacy.map((inv) {
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                      Icons.receipt_long,
                                      color: AppColors.primary,
                                      size: 20),
                                  title: Text(
                                      'فاتورة رقم: ${inv.invoiceNumber} (${inv.clientName ?? "—"})',
                                      style: const TextStyle(
                                          fontSize: 13)),
                                  subtitle: Text(
                                      'تاريخ: ${inv.date.toString().split(' ').first}',
                                      style: const TextStyle(
                                          fontSize: 12)),
                                  trailing: Text(
                                      'يُحصّل: ${inv.remainingBalance.toStringAsFixed(0)} $currency',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.bold)),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPayablesModal(BuildContext context, WidgetRef ref, String currency) {
    final suppliers = ref.read(suppliersProvider).suppliers;
    final invoices = ref.read(purchaseInvoicesProvider).invoices;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تفاصيل ديون الموردين ("علينا")',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: suppliers.isEmpty
                    ? const Center(child: Text('لا يوجد موردين مضافين'))
                    : ListView.builder(
                        itemCount: suppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = suppliers[index];
                          final suppInvoices = invoices.where((i) => i.supplierId == supplier.id && i.remainingBalance > 0).toList();
                          final totalDebt = suppInvoices.fold(0.0, (sum, i) => sum + i.remainingBalance);

                          if (totalDebt <= 0) return const SizedBox.shrink();

                          return ExpansionTile(
                            title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('الهاتف: ${supplier.phone} • المستحق للمورد: ${totalDebt.toStringAsFixed(0)} $currency'),
                            trailing: Text('${totalDebt.toStringAsFixed(0)} $currency', style: const TextStyle(color: AppColors.payables, fontWeight: FontWeight.bold)),
                            children: suppInvoices.map((inv) {
                              return ListTile(
                                leading: const Icon(Icons.receipt, color: AppColors.accent),
                                title: Text('فاتورة رقم: ${inv.invoiceNumber}'),
                                subtitle: Text('تاريخ: ${inv.date.toString().split(' ').first} • الإجمالي: ${inv.totalAmount.toStringAsFixed(0)} • مدفوع: ${inv.paidAmount.toStringAsFixed(0)} $currency'),
                                trailing: Text('متبقي: ${inv.remainingBalance.toStringAsFixed(0)} $currency', style: const TextStyle(fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
