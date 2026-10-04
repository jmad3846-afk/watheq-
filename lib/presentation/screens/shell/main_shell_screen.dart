import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/security/backup_service.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/payments_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/projects_provider.dart';
import '../../providers/suppliers_provider.dart';
import '../../providers/clients_provider.dart';
import '../../providers/purchase_invoices_provider.dart';
import '../../providers/sale_invoices_provider.dart';
import '../../providers/financials_provider.dart';

import '../dashboard/dashboard_screen.dart';
import '../contacts/contacts_screen.dart';
import '../products/products_screen.dart';
import '../invoices/invoices_screen.dart';
import '../financials/financials_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    ContactsScreen(),
    ProductsScreen(),
    InvoicesScreen(),
    FinancialsScreen(),
  ];

  void _onSelectTab(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _exportBackup() async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ النسخة الاحتياطية Encrypted (.wthaq)',
        fileName: 'wathaq_backup_${DateTime.now().toString().split(' ').first}.wthaq',
        allowedExtensions: ['wthaq'],
        type: FileType.custom,
      );

      if (result != null) {
        await BackupService.exportBackupToFile(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تصدير النسخة الاحتياطية بنجاح!'),
              backgroundColor: AppColors.receivables,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء حفظ النسخة الاحتياطية: $e'),
            backgroundColor: AppColors.payables,
          ),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'استعادة نسخة احتياطية (.wthaq)',
        type: FileType.custom,
        allowedExtensions: ['wthaq'],
        withData: true, // Required: without this FilePicker does NOT return bytes on Windows
      );

      if (result != null && result.files.isNotEmpty) {
        // Always try bytes first; fall back to reading the path from disk
        Uint8List? fileBytes = result.files.single.bytes;
        if (fileBytes == null && result.files.single.path != null) {
          try {
            final f = File(result.files.single.path!);
            fileBytes = await f.readAsBytes();
          } catch (readErr) {
            fileBytes = null;
          }
        }

        if (fileBytes != null && fileBytes.isNotEmpty) {
          final success = await BackupService.restoreFromBackupData(fileBytes);
          if (success) {
            // Refresh all providers
            ref.read(productsProvider.notifier).loadProducts();
            ref.read(suppliersProvider.notifier).loadSuppliers();
            ref.read(clientsProvider.notifier).loadClients();
            ref.read(projectsProvider.notifier).loadProjects();
            ref.read(purchaseInvoicesProvider.notifier).loadInvoices();
            ref.read(saleInvoicesProvider.notifier).loadInvoices();
            ref.read(paymentsProvider.notifier).loadPayments();
            ref.read(financialsProvider.notifier).refreshFinancials();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تمت استعادة كافة البيانات والنسخة الاحتياطية بنجاح!'),
                  backgroundColor: AppColors.receivables,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تعذر قراءة ملف النسخة الاحتياطية من القرص'),
                backgroundColor: AppColors.payables,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشلت استعادة النسخة الاحتياطية: $e'),
            backgroundColor: AppColors.payables,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar Navigation Rail (Modern Dark Theme)
          Container(
            width: 240,
            color: AppColors.sidebarBackground,
            child: Column(
              children: [
                // Header Logo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.verified_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تطبيق وثق',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'العملة: ${settings.currency}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.accentLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 16),

                // Nav Items
                _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'الرئيسية'),
                _buildNavItem(1, Icons.people_outline, Icons.people, 'الأشخاص'),
                _buildNavItem(2, Icons.inventory_2_outlined, Icons.inventory_2, 'المنتجات والشرائح'),
                _buildNavItem(3, Icons.receipt_long_outlined, Icons.receipt_long, 'الفواتير'),
                _buildNavItem(4, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'المالية والحسابات'),

                const Spacer(),
                const Divider(color: Colors.white12, height: 1),

                // Backup & Settings Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _exportBackup,
                        icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                        label: const Text('تصدير نسخة احتياطية'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.08),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          alignment: Alignment.centerRight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _importBackup,
                        icon: const Icon(Icons.cloud_download_outlined, size: 18),
                        label: const Text('استعادة نسخة احتياطية'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.08),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          alignment: Alignment.centerRight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main View Area
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => _onSelectTab(index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: AppColors.accent.withOpacity(0.5)) : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? AppColors.accent : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
