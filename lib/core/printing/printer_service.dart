import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/models/sale_invoice.dart';
import '../../domain/models/purchase_invoice.dart';
import '../../domain/models/approved_project.dart';

/// Central helper for **standard A4** invoice printing with print preview.
///
/// Layout (PdfPageFormat.a4):
/// - Header: App Title ("وثق للمحاسبة والمخازن"), Invoice Number, Date,
///   Customer/Supplier Details, Project Name.
/// - Body: full-width itemized table (Description, Qty, Unit Price, Total).
/// - Summary: Subtotal, Delivery Cost, Net Total, Paid, Remaining,
///   Payment Status, Delivery Status.
/// - Footer: Terms/Notes + signature placeholders.
///
/// All print entry-points show an interactive [PdfPreview] dialog first
/// (معاينة قبل الطباعة) with Print / Save-as-PDF actions — no silent
/// background printing.
class PrinterService {
  static const String fallbackNoPrinterMessage =
      'تم حفظ الفاتورة بنجاح (تعذر الاتصال بالطابعة)';

  static const String defaultAppTitle = 'وثق للمحاسبة والمخازن';

  // ---------------------------------------------------------------------------
  // A4 bytes builders
  // ---------------------------------------------------------------------------

  /// Build standard A4 PDF bytes for a Sale invoice.
  ///
  /// Kept under the legacy name [buildSaleReceiptPdf] so existing callers
  /// keep working — output is now a full A4 page, not an 80mm roll.
  static Future<Uint8List> buildSaleReceiptPdf({
    required SaleInvoice invoice,
    required String headerTitle,
    required String currency,
  }) {
    return buildSaleInvoiceA4(
      invoice: invoice,
      headerTitle: headerTitle,
      currency: currency,
    );
  }

  /// Build standard A4 PDF bytes for a Purchase invoice.
  ///
  /// Kept under the legacy name [buildPurchaseReceiptPdf] so existing
  /// callers keep working — output is now a full A4 page, not an 80mm roll.
  static Future<Uint8List> buildPurchaseReceiptPdf({
    required PurchaseInvoice invoice,
    required String headerTitle,
    required String currency,
  }) {
    return buildPurchaseInvoiceA4(
      invoice: invoice,
      headerTitle: headerTitle,
      currency: currency,
    );
  }

  static Future<Uint8List> buildSaleInvoiceA4({
    required SaleInvoice invoice,
    required String headerTitle,
    required String currency,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.tajawalMedium();
    final fontBold = await PdfGoogleFonts.tajawalBold();
    final appName =
        headerTitle.trim().isEmpty ? defaultAppTitle : headerTitle.trim();
    final dateFormatted =
        intl.DateFormat('yyyy/MM/dd HH:mm').format(invoice.date);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context ctx) {
          if (ctx.pageNumber > 1) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(appName,
                      style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.Text('صفحة ${ctx.pageNumber}',
                      style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              ),
            );
          }
          return pw.SizedBox();
        },
        build: (pw.Context context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ---- Header ----
                _a4TitleBlock(
                  appName: appName,
                  docLabel: _saleTypeLabel(invoice),
                  font: font,
                  fontBold: fontBold,
                ),
                pw.SizedBox(height: 10),
                _a4MetaBox(
                  rows: [
                    (
                      'رقم الفاتورة:',
                      invoice.invoiceNumber.isEmpty
                          ? '#'
                          : invoice.invoiceNumber
                    ),
                    ('التاريخ:', dateFormatted),
                    if (invoice.clientName != null &&
                        invoice.clientName!.isNotEmpty)
                      ('العميل:', invoice.clientName!),
                    if ((invoice.projectName?.isNotEmpty ?? false))
                      ('المشروع:', invoice.projectName!),
                    (
                      'حالة الدفع:',
                      invoice.isFullyPaid
                          ? 'مدفوعة بالكامل'
                          : 'غير مكتملة — المتبقي ${invoice.remainingBalance.toStringAsFixed(0)} $currency'
                    ),
                  ],
                  font: font,
                  fontBold: fontBold,
                ),
                pw.SizedBox(height: 12),
                // ---- Body: full-width items table ----
                _a4ItemsTable(
                  headers: const [
                    'م',
                    'الصنف / البيان',
                    'الكمية',
                    'سعر الوحدة',
                    'الإجمالي'
                  ],
                  rows: [
                    for (int i = 0; i < invoice.items.length; i++)
                      [
                        '${i + 1}',
                        '${invoice.items[i].productName}${invoice.items[i].isReturn ? " (مرتجع)" : ""}',
                        '${invoice.items[i].quantity} ${invoice.items[i].unit}',
                        _fmtNum(invoice.items[i].unitPrice),
                        '${invoice.items[i].subtotal.toStringAsFixed(0)} $currency',
                      ],
                  ],
                  font: font,
                  fontBold: fontBold,
                ),
                pw.SizedBox(height: 12),
                // ---- Summary ----
                _a4SummaryBox(
                  rows: [
                    (
                      'المجموع الفرعي:',
                      '${invoice.totalAmount.toStringAsFixed(0)} $currency',
                      false
                    ),
                    (
                      'المدفوع / الدفعة:',
                      '${invoice.paidAmount.toStringAsFixed(0)} $currency',
                      false
                    ),
                    (
                      'الصافي الإجمالي:',
                      '${invoice.totalAmount.toStringAsFixed(0)} $currency',
                      true
                    ),
                    (
                      'المتبقي:',
                      '${invoice.remainingBalance.toStringAsFixed(0)} $currency',
                      true
                    ),
                    (
                      'حالة الدفع:',
                      invoice.isFullyPaid
                          ? 'مدفوعة بالكامل'
                          : 'مستحق الدفع',
                      true
                    ),
                  ],
                  font: font,
                  fontBold: fontBold,
                ),
                pw.SizedBox(height: 10),
                _a4FooterBlock(
                  notes: invoice.notes,
                  font: font,
                  fontBold: fontBold,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> buildPurchaseInvoiceA4({
    required PurchaseInvoice invoice,
    required String headerTitle,
    required String currency,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.tajawalMedium();
    final fontBold = await PdfGoogleFonts.tajawalBold();
    final appName =
        headerTitle.trim().isEmpty ? defaultAppTitle : headerTitle.trim();
    final dateFormatted =
        intl.DateFormat('yyyy/MM/dd HH:mm').format(invoice.date);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context ctx) {
          if (ctx.pageNumber > 1) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(appName,
                      style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.Text('صفحة ${ctx.pageNumber}',
                      style: pw.TextStyle(font: font, fontSize: 9)),
                ],
              ),
            );
          }
          return pw.SizedBox();
        },
        build: (pw.Context context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _a4TitleBlock(
                  appName: appName,
                  docLabel: 'فاتورة شراء من مورد',
                  font: font,
                  fontBold: fontBold,
                ),
                pw.SizedBox(height: 10),
                _a4MetaBox(
                  rows: [
                    (
                      'رقم الفاتورة:',
                      invoice.invoiceNumber.isEmpty
                          ? '#'
                          : invoice.invoiceNumber
                    ),
                    ('التاريخ:', dateFormatted),
                    ('المورد:', invoice.supplierName),
                    (
                      'حالة وصول البضاعة:',
                      invoice.isDelivered ? 'واصلة' : 'غير واصلة'
                    ),
                    if (!invoice.isDelivered &&
                        (invoice.driverName?.isNotEmpty ?? false))
                      (
                        'السائق:',
                        '${invoice.driverName} (${invoice.driverPhone ?? ""})'
                      ),
                    (
                      'حالة الدفع:',
                      invoice.isFullyPaid
                          ? 'مدفوعة بالكامل'
                          : 'غير مكتملة — المتبقي ${invoice.remainingBalance.toStringAsFixed(0)} $currency'
                    ),
                  ],
                  font: font,
                  fontBold: fontBold,
                ),
                pw.SizedBox(height: 12),
                _a4ItemsTable(
                  headers: const [
                    'م',
                    'الصنف / البيان',
                    'الكمية',
                    'تكلفة الوحدة',
                    'الإجمالي'
                  ],
                  rows: [
                    for (int i = 0; i < invoice.items.length; i++)
                      [
                        '${i + 1}',
                        '${invoice.items[i].productName}${invoice.items[i].isReturn ? " (مرتجع)" : ""}',
                        '${invoice.items[i].quantity} ${invoice.items[i].unit}',
                        _fmtNum(invoice.items[i].unitPrice),
                        '${invoice.items[i].subtotal.toStringAsFixed(0)} $currency',
                      ],
                  ],
                  font: font,
                  fontBold: fontBold,
                ),
                pw.SizedBox(height: 12),
                _a4SummaryBox(
                  rows: [
                    (
                      'المجموع الفرعي:',
                      '${invoice.subtotal.toStringAsFixed(0)} $currency',
                      false
                    ),
                    (
                      'تكلفة التوصيل:',
                      '${invoice.effectiveDeliveryCost.toStringAsFixed(0)} $currency',
                      false
                    ),
                    (
                      'الصافي الإجمالي (شامل التوصيل):',
                      '${invoice.totalAmount.toStringAsFixed(0)} $currency',
                      true
                    ),
                    (
                      'المدفوع للمورد:',
                      '${invoice.paidAmount.toStringAsFixed(0)} $currency',
                      false
                    ),
                    (
                      'المتبقي للمورد:',
                      '${invoice.remainingBalance.toStringAsFixed(0)} $currency',
                      true
                    ),
                    (
                      'حالة الدفع:',
                      invoice.isFullyPaid
                          ? 'مدفوعة بالكامل'
                          : 'مستحق الدفع',
                      true
                    ),
                    (
                      'حالة التوصيل:',
                      invoice.isDelivered ? 'واصلة' : 'غير واصلة',
                      false
                    ),
                  ],
                  font: font,
                  fontBold: fontBold,
                ),
                if (!invoice.isDelivered &&
                    invoice.deliveryNotes.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 6),
                    child: pw.Text(
                      'ملاحظات التوصيل: ${invoice.deliveryNotes}',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ),
                pw.SizedBox(height: 10),
                _a4FooterBlock(
                  notes: invoice.notes,
                  font: font,
                  fontBold: fontBold,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ---------------------------------------------------------------------------
  // Whole-project consolidated report (A4)
  // ---------------------------------------------------------------------------

  /// Build an A4 consolidated statement for one [ApprovedProject]:
  /// project summary header + itemized table of all linked sale invoices
  /// (+ optional purchase invoices) + grand totals.
  static Future<Uint8List> buildProjectReportPdf({
    required ApprovedProject project,
    required List<SaleInvoice> invoices,
    List<PurchaseInvoice> purchases = const [],
    required String headerTitle,
    required String currency,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.tajawalMedium();
    final fontBold = await PdfGoogleFonts.tajawalBold();
    final appName =
        headerTitle.trim().isEmpty ? defaultAppTitle : headerTitle.trim();

    final projectInvoices =
        invoices.where((i) => !i.isReturnInvoice).toList();
    final returnInvoices =
        invoices.where((i) => i.isReturnInvoice).toList();

    final issued =
        projectInvoices.fold(0.0, (s, i) => s + i.totalAmount);
    final returnsTotal =
        returnInvoices.fold(0.0, (s, i) => s + i.totalAmount);
    final paid = projectInvoices.fold(0.0, (s, i) => s + i.paidAmount);
    final owed = issued - paid - returnsTotal;
    final purchaseTotal =
        purchases.fold(0.0, (s, i) => s + i.totalAmount);

    String dateRange = '—';
    final allDates = invoices.map((i) => i.date).toList();
    if (allDates.isNotEmpty) {
      allDates.sort();
      final fmt = intl.DateFormat('yyyy/MM/dd');
      dateRange =
          '${fmt.format(allDates.first)} ← ${fmt.format(allDates.last)}';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _a4TitleBlock(
                  appName: appName,
                  docLabel:
                      'كشف حساب مشروع — ${project.clientName} — ${project.location.isEmpty ? "بدون موقع" : project.location}',
                  font: font,
                  fontBold: fontBold,
                ),
                pw.SizedBox(height: 10),
                _a4MetaBox(
                  rows: [
                    ('المشروع:', project.location.isEmpty
                        ? project.clientName
                        : '${project.clientName} — ${project.location}'),
                    ('العميل:', project.clientName),
                    ('الفترة الزمنية:', dateRange),
                    ('عدد فواتير البيع:', '${projectInvoices.length}'),
                    ('عدد فواتير الإرجاع:', '${returnInvoices.length}'),
                    (
                      'الوضع المالي العام:',
                      owed <= 0.01
                          ? 'مخالص — لا مستحقات متبقية'
                          : 'مستحق ${owed.toStringAsFixed(0)} $currency'
                    ),
                  ],
                  font: font,
                  fontBold: fontBold,
                ),
                pw.SizedBox(height: 12),
                pw.Text('فواتير المشروع (بيع وإرجاع):',
                    style: pw.TextStyle(font: fontBold, fontSize: 12)),
                pw.SizedBox(height: 6),
                _a4ItemsTable(
                  headers: const [
                    'م',
                    'رقم الفاتورة',
                    'التاريخ',
                    'النوع',
                    'الإجمالي',
                    'المدفوع',
                    'المتبقي'
                  ],
                  columnFlex: const [1, 2, 2, 2, 2, 2, 2],
                  rows: [
                    for (int i = 0; i < invoices.length; i++)
                      [
                        '${i + 1}',
                        invoices[i].invoiceNumber.isEmpty
                            ? '#'
                            : invoices[i].invoiceNumber,
                        intl.DateFormat('yyyy/MM/dd')
                            .format(invoices[i].date),
                        invoices[i].isReturnInvoice
                            ? 'إرجاع'
                            : 'بيع',
                        invoices[i].totalAmount.toStringAsFixed(0),
                        invoices[i].paidAmount.toStringAsFixed(0),
                        invoices[i].remainingBalance.toStringAsFixed(0),
                      ],
                  ],
                  font: font,
                  fontBold: fontBold,
                  smallFont: true,
                ),
                if (purchases.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pw.Text('فواتير الشراء المرتبطة بالمشروع:',
                      style: pw.TextStyle(font: fontBold, fontSize: 12)),
                  pw.SizedBox(height: 6),
                  _a4ItemsTable(
                    headers: const [
                      'م',
                      'رقم الفاتورة',
                      'التاريخ',
                      'المورد',
                      'الإجمالي',
                      'المدفوع',
                      'المتبقي'
                    ],
                    columnFlex: const [1, 2, 2, 3, 2, 2, 2],
                    rows: [
                      for (int i = 0; i < purchases.length; i++)
                        [
                          '${i + 1}',
                          purchases[i].invoiceNumber.isEmpty
                              ? '#'
                              : purchases[i].invoiceNumber,
                          intl.DateFormat('yyyy/MM/dd')
                              .format(purchases[i].date),
                          purchases[i].supplierName,
                          purchases[i].totalAmount.toStringAsFixed(0),
                          purchases[i].paidAmount.toStringAsFixed(0),
                          purchases[i].remainingBalance.toStringAsFixed(0),
                        ],
                    ],
                    font: font,
                    fontBold: fontBold,
                    smallFont: true,
                  ),
                ],
                pw.SizedBox(height: 12),
                _a4SummaryBox(
                  rows: [
                    (
                      'إجمالي فواتير البيع:',
                      '$issued $currency'.replaceAll(
                          '.0 $currency', ' $currency'),
                      false
                    ),
                    (
                      'إجمالي الإرجاع:',
                      '${returnsTotal.toStringAsFixed(0)} $currency',
                      false
                    ),
                    (
                      'إجمالي المدفوع:',
                      '${paid.toStringAsFixed(0)} $currency',
                      false
                    ),
                    if (purchases.isNotEmpty)
                      (
                        'إجمالي المشتريات:',
                        '${purchaseTotal.toStringAsFixed(0)} $currency',
                        false
                      ),
                    (
                      'إجمالي تكاليف / فواتير المشروع (الصافي المستحق):',
                      '${owed.toStringAsFixed(0)} $currency',
                      true
                    ),
                  ],
                  font: font,
                  fontBold: fontBold,
                ),
                pw.SizedBox(height: 10),
                _a4FooterBlock(
                  notes: project.notes,
                  font: font,
                  fontBold: fontBold,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ---------------------------------------------------------------------------
  // Print preview dialogs (معاينة قبل الطباعة)
  // ---------------------------------------------------------------------------

  /// Show an interactive A4 preview for [bytes] with Print / Save-as-PDF.
  static Future<void> showPdfPreviewDialog({
    required BuildContext context,
    required Uint8List pdfBytes,
    required String title,
    required String jobName,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: 820,
            height: 640,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.preview_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'معاينة قبل الطباعة — $title',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'إغلاق',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: PdfPreview(
                    build: (PdfPageFormat format) async => pdfBytes,
                    allowPrinting: true,
                    allowSharing: true,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: '$jobName.pdf',
                    actions: const [],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build + preview a single sale invoice on A4.
  static Future<bool> showSaleInvoicePreview({
    required BuildContext context,
    required SaleInvoice invoice,
    required String headerTitle,
    required String currency,
  }) async {
    try {
      final bytes = await buildSaleInvoiceA4(
        invoice: invoice,
        headerTitle: headerTitle,
        currency: currency,
      );
      if (!context.mounted) return false;
      await showPdfPreviewDialog(
        context: context,
        pdfBytes: bytes,
        title: 'فاتورة #${invoice.invoiceNumber}',
        jobName: 'فاتورة_${invoice.invoiceNumber}',
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ [PrinterService] showSaleInvoicePreview failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(fallbackNoPrinterMessage)),
        );
      }
      return false;
    }
  }

  /// Build + preview a single purchase invoice on A4.
  static Future<bool> showPurchaseInvoicePreview({
    required BuildContext context,
    required PurchaseInvoice invoice,
    required String headerTitle,
    required String currency,
  }) async {
    try {
      final bytes = await buildPurchaseInvoiceA4(
        invoice: invoice,
        headerTitle: headerTitle,
        currency: currency,
      );
      if (!context.mounted) return false;
      await showPdfPreviewDialog(
        context: context,
        pdfBytes: bytes,
        title: 'فاتورة شراء #${invoice.invoiceNumber}',
        jobName: 'فاتورة_شراء_${invoice.invoiceNumber}',
      );
      return true;
    } catch (e) {
      debugPrint(
          '⚠️ [PrinterService] showPurchaseInvoicePreview failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(fallbackNoPrinterMessage)),
        );
      }
      return false;
    }
  }

  /// Build + preview a whole-project consolidated report on A4.
  static Future<bool> showProjectReportPreview({
    required BuildContext context,
    required ApprovedProject project,
    required List<SaleInvoice> invoices,
    List<PurchaseInvoice> purchases = const [],
    required String headerTitle,
    required String currency,
  }) async {
    try {
      final bytes = await buildProjectReportPdf(
        project: project,
        invoices: invoices,
        purchases: purchases,
        headerTitle: headerTitle,
        currency: currency,
      );
      if (!context.mounted) return false;
      await showPdfPreviewDialog(
        context: context,
        pdfBytes: bytes,
        title: 'كشف المشروع — ${project.clientName}',
        jobName: 'كشف_مشروع_${project.clientName}',
      );
      return true;
    } catch (e) {
      debugPrint(
          '⚠️ [PrinterService] showProjectReportPreview failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(fallbackNoPrinterMessage)),
        );
      }
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Legacy entry-points — now route to the A4 preview instead of silent
  // direct thermal printing. Never throws.
  // ---------------------------------------------------------------------------

  /// Legacy: print a sale invoice. Now opens the A4 print-preview dialog
  /// when [contextForFeedback] is supplied; otherwise falls back to the
  /// system print sheet via [Printing.layoutPdf].
  static Future<bool> printSaleInvoice({
    required SaleInvoice invoice,
    required String headerTitle,
    required String currency,
    BuildContext? contextForFeedback,
  }) async {
    try {
      if (contextForFeedback != null && contextForFeedback.mounted) {
        return showSaleInvoicePreview(
          context: contextForFeedback,
          invoice: invoice,
          headerTitle: headerTitle,
          currency: currency,
        );
      }
      final bytes = await buildSaleInvoiceA4(
        invoice: invoice,
        headerTitle: headerTitle,
        currency: currency,
      );
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'فاتورة_${invoice.invoiceNumber}.pdf',
        format: PdfPageFormat.a4,
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ [PrinterService] printSaleInvoice failed: $e');
      if (contextForFeedback != null && contextForFeedback.mounted) {
        ScaffoldMessenger.of(contextForFeedback).showSnackBar(
          const SnackBar(content: Text(fallbackNoPrinterMessage)),
        );
      }
      return false;
    }
  }

  /// Legacy: print a purchase invoice. Same preview-first contract as
  /// [printSaleInvoice].
  static Future<bool> printPurchaseInvoice({
    required PurchaseInvoice invoice,
    required String headerTitle,
    required String currency,
    BuildContext? contextForFeedback,
  }) async {
    try {
      if (contextForFeedback != null && contextForFeedback.mounted) {
        return showPurchaseInvoicePreview(
          context: contextForFeedback,
          invoice: invoice,
          headerTitle: headerTitle,
          currency: currency,
        );
      }
      final bytes = await buildPurchaseInvoiceA4(
        invoice: invoice,
        headerTitle: headerTitle,
        currency: currency,
      );
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'فاتورة_شراء_${invoice.invoiceNumber}.pdf',
        format: PdfPageFormat.a4,
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ [PrinterService] printPurchaseInvoice failed: $e');
      if (contextForFeedback != null && contextForFeedback.mounted) {
        ScaffoldMessenger.of(contextForFeedback).showSnackBar(
          const SnackBar(content: Text(fallbackNoPrinterMessage)),
        );
      }
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // A4 building blocks
  // ---------------------------------------------------------------------------

  static String _saleTypeLabel(SaleInvoice invoice) {
    if (invoice.isReturnInvoice) {
      return 'فاتورة إرجاع (مشروع معتمد)${invoice.returnOfInvoiceId != null ? " — للأصلية #${invoice.returnOfInvoiceId}" : ""}';
    }
    switch (invoice.type) {
      case SaleInvoiceType.project:
        return 'فاتورة مشروع معتمد${(invoice.projectName?.isNotEmpty ?? false) ? " — ${invoice.projectName}" : ""}';
      case SaleInvoiceType.long:
        return 'فاتورة مبيعات طويلة';
      case SaleInvoiceType.salesReturn:
        return 'فاتورة إرجاع مبيعات';
      case SaleInvoiceType.regular:
        return 'فاتورة مبيعات';
    }
  }

  static String _fmtNum(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  static pw.Widget _a4TitleBlock({
    required String appName,
    required String docLabel,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          appName,
          style: pw.TextStyle(font: fontBold, fontSize: 20),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          docLabel,
          style: pw.TextStyle(font: font, fontSize: 12),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.2),
      ],
    );
  }

  static pw.Widget _a4MetaBox({
    required List<(String, String)> rows,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.7),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          for (final r in rows)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(r.$1,
                      style: pw.TextStyle(font: fontBold, fontSize: 10)),
                  pw.Expanded(
                    child: pw.Text(
                      r.$2,
                      style: pw.TextStyle(font: font, fontSize: 10),
                      textAlign: pw.TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _a4ItemsTable({
    required List<String> headers,
    required List<List<String>> rows,
    required pw.Font font,
    required pw.Font fontBold,
    List<int>? columnFlex,
    bool smallFont = false,
  }) {
    final headerSize = smallFont ? 9.0 : 10.0;
    final cellSize = smallFont ? 8.5 : 10.0;
    final flex = columnFlex ??
        [
          1,
          if (headers.length > 2) 5,
          for (int i = 2; i < headers.length; i++) 2,
        ];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
      columnWidths: {
        for (int i = 0; i < headers.length; i++)
          i: pw.FlexColumnWidth(flex[i].toDouble()),
      },
      children: [
        pw.TableRow(
          decoration:
              const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            for (final h in headers)
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(font: fontBold, fontSize: headerSize),
                  textAlign: pw.TextAlign.center,
                ),
              ),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              for (int i = 0; i < row.length; i++)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    row[i],
                    style: pw.TextStyle(font: font, fontSize: cellSize),
                    textAlign: i == 1
                        ? pw.TextAlign.right
                        : pw.TextAlign.center,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _a4SummaryBox({
    required List<(String, String, bool)> rows,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.7),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          for (final r in rows)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    r.$1,
                    style: pw.TextStyle(
                      font: r.$3 ? fontBold : font,
                      fontSize: r.$3 ? 11 : 10,
                    ),
                  ),
                  pw.Text(
                    r.$2,
                    style: pw.TextStyle(
                      font: r.$3 ? fontBold : font,
                      fontSize: r.$3 ? 11 : 10,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _a4FooterBlock({
    required String notes,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (notes.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              'ملاحظات / الشروط: $notes',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          )
        else
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              'الشروط: البضاعة المباعة لا ترد ولا تستبدل إلا بموجب فاتورة إرجاع معتمدة.',
              style: pw.TextStyle(font: font, fontSize: 9),
            ),
          ),
        pw.SizedBox(height: 18),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            pw.Column(
              children: [
                pw.Text('............................',
                    style: pw.TextStyle(font: font, fontSize: 10)),
                pw.SizedBox(height: 2),
                pw.Text('توقيع المحاسب',
                    style: pw.TextStyle(font: fontBold, fontSize: 10)),
              ],
            ),
            pw.Column(
              children: [
                pw.Text('............................',
                    style: pw.TextStyle(font: font, fontSize: 10)),
                pw.SizedBox(height: 2),
                pw.Text('توقيع المستلم',
                    style: pw.TextStyle(font: fontBold, fontSize: 10)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            'شكراً لتعاملكم معنا',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        ),
      ],
    );
  }
}
