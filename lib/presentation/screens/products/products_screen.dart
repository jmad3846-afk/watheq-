import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/models/product.dart';
import '../../providers/products_provider.dart';
import '../../providers/app_settings_provider.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productsProvider);
    final currency = ref.watch(appSettingsProvider).currency;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              children: [
                const Text(
                  'كتالوج المنتجات والمخزن',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                if (state.lowStockCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text(
                          '${state.lowStockCount} منتجات منخفضة المخزون',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditProductDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة منتج جديد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            TextField(
              onChanged: (q) => ref.read(productsProvider.notifier).setSearchQuery(q),
              decoration: InputDecoration(
                hintText: 'ابحث عن صنف بالاسم...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Product Cards Grid / List
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.filteredProducts.isEmpty
                      ? const Center(child: Text('لا توجد منتجات مضافين حالياً'))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 340,
                            mainAxisExtent: 180,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: state.filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = state.filteredProducts[index];

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: AppColors.cardShadow,
                                border: Border.all(
                                  color: product.isLowStock ? AppColors.warning.withOpacity(0.6) : AppColors.border,
                                  width: product.isLowStock ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          product.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (product.isLowStock)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.warning.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'مخزون منخفض',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.warning,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'المخزون الحالي: ${product.quantity} ${product.unit}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: product.isLowStock ? AppColors.warning : AppColors.primary,
                                        ),
                                      ),
                                      Text(
                                        'الحد الأدنى: ${product.lowStockThreshold}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  const Divider(height: 12),
                                  Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'التكلفة: ${product.costPrice} $currency',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                          Text(
                                            'البيع: ${product.salePrice} $currency',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.receivables,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                        onPressed: () => _showAddEditProductDialog(context, ref, product: product),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.payables),
                                        onPressed: () => ref.read(productsProvider.notifier).deleteProduct(product.id!),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditProductDialog(BuildContext context, WidgetRef ref, {Product? product}) {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final qtyCtrl = TextEditingController(text: product?.quantity.toString() ?? '0');
    final unitCtrl = TextEditingController(text: product?.unit ?? 'قطعة');
    final costCtrl = TextEditingController(text: product?.costPrice.toString() ?? '0');
    final saleCtrl = TextEditingController(text: product?.salePrice.toString() ?? '0');
    final thresholdCtrl = TextEditingController(text: product?.lowStockThreshold.toString() ?? '5');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product == null ? 'إضافة منتج جديد' : 'تعديل بيانات المنتج'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج / الصنف')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'الكمية الأولية بالمخزن'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(labelText: 'وحدة القياس (كغ، قطعة، صندوق)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'سعر التكلفة (الشراء)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: saleCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'سعر البيع للمستهلك'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: thresholdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'حد إنذار انخفاض المخزون (Per-product Threshold)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) return;

              final newProduct = Product(
                id: product?.id,
                name: nameCtrl.text.trim(),
                quantity: double.tryParse(qtyCtrl.text) ?? 0.0,
                unit: unitCtrl.text.trim(),
                costPrice: double.tryParse(costCtrl.text) ?? 0.0,
                salePrice: double.tryParse(saleCtrl.text) ?? 0.0,
                lowStockThreshold: double.tryParse(thresholdCtrl.text) ?? 5.0,
              );

              if (product == null) {
                ref.read(productsProvider.notifier).addProduct(newProduct);
              } else {
                ref.read(productsProvider.notifier).updateProduct(newProduct);
              }
              Navigator.pop(ctx);
            },
            child: const Text('حفظ المنتج'),
          ),
        ],
      ),
    );
  }
}
