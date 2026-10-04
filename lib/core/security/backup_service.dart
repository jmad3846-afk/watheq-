import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import '../database/database_helper.dart';

class BackupService {
  // Master key derived from secret key (32 bytes for AES-256)
  static enc.Key get _aesKey {
    final bytes = utf8.encode(AppConstants.secretKey.padRight(32, '0')).sublist(0, 32);
    return enc.Key(Uint8List.fromList(bytes));
  }

  static enc.IV get _aesIv {
    final bytes = utf8.encode('WATHAQ_IV_16BYTE').sublist(0, 16);
    return enc.IV(Uint8List.fromList(bytes));
  }

  /// Export database and settings into a single encrypted .wthaq file
  /// Includes: all database tables, app settings, and stored license key.
  /// Images are NOT included in the archive to keep it simple and reliable;
  /// they reside in the app's document directory and are typically backed up
  /// by the OS file system.
  static Future<Uint8List> generateBackupData() async {
    final db = await DatabaseHelper.instance.database;
    final prefs = await SharedPreferences.getInstance();

    // 1. Export database tables
    Future<List<Map<String, dynamic>>> safeQuery(String table) async {
      try {
        return await db.query(table);
      } catch (_) {
        return [];
      }
    }

    final Map<String, List<Map<String, dynamic>>> dbDump = {
      'products': await safeQuery('products'),
      'suppliers': await safeQuery('suppliers'),
      'clients': await safeQuery('clients'),
      'approved_projects': await safeQuery('approved_projects'),
      'purchase_invoices': await safeQuery('purchase_invoices'),
      'purchase_invoice_items': await safeQuery('purchase_invoice_items'),
      'sale_invoices': await safeQuery('sale_invoices'),
      'sale_invoice_items': await safeQuery('sale_invoice_items'),
      'payments': await safeQuery('payments'),
      'invoice_counters': await safeQuery('invoice_counters'),
    };

    // 2. Export app settings
    final settings = <String, dynamic>{
      'currency': prefs.getString(AppConstants.prefCurrency) ?? AppConstants.defaultCurrency,
      'printerHeader': prefs.getString(AppConstants.prefPrinterHeader) ?? AppConstants.defaultPrinterHeader,
      'isFirstLaunch': prefs.getBool(AppConstants.prefFirstLaunch) ?? true,
    };

    // 3. Export stored license key (if any)
    final licenseKey = prefs.getString(AppConstants.prefLicenseKey);

    // 4. Build JSON payload
    final jsonPayload = jsonEncode({
      'version': 1,
      'created_at': DateTime.now().toIso8601String(),
      'tables': dbDump,
      'settings': settings,
      'license_key': licenseKey,
    });

    // 5. Build ZIP archive with single file db_data.json
    final archive = Archive();
    final jsonBytes = utf8.encode(jsonPayload);
    archive.addFile(ArchiveFile('db_data.json', jsonBytes.length, jsonBytes));

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    if (zipBytes == null) {
      throw Exception('فشل في ضغط بيانات النسخة الاحتياطية');
    }

    // 6. Encrypt payload with AES-256-CBC
    final encrypter = enc.Encrypter(enc.AES(_aesKey, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(zipBytes, iv: _aesIv);

    return encrypted.bytes;
  }

  /// Import and restore data from raw encrypted .wthaq bytes
  static Future<bool> restoreFromBackupData(Uint8List encryptedBytes) async {
    try {
      // 1. Decrypt AES-256 payload
      final encrypter = enc.Encrypter(enc.AES(_aesKey, mode: enc.AESMode.cbc));
      final decryptedZipBytes = encrypter.decryptBytes(
        enc.Encrypted(encryptedBytes),
        iv: _aesIv,
      );

      // 2. Unzip archive
      final archive = ZipDecoder().decodeBytes(decryptedZipBytes);
      ArchiveFile? jsonFile;

      for (var file in archive) {
        if (file.name == 'db_data.json') {
          jsonFile = file;
          break;
        }
      }

      if (jsonFile == null) {
        throw Exception('ملف النسخة الاحتياطية غير صالح أو تالف: لا يوجد db_data.json');
      }

      // 3. Parse JSON payload
      final jsonContent = utf8.decode(jsonFile.content as List<int>);
      final Map<String, dynamic> payload = jsonDecode(jsonContent) as Map<String, dynamic>;

      final tables = payload['tables'] as Map<String, dynamic>;
      final settingsData = payload['settings'] as Map<String, dynamic>?;
      final licenseKeyFromPayload = payload['license_key'] as String?;

      // 4. Restore to SQLite Database atomically
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        // Clear existing tables in reverse dependency order
        await _safeDeleteAll(txn, [
          'sale_invoice_items',
          'purchase_invoice_items',
          'sale_invoices',
          'purchase_invoices',
          'payments',
          'approved_projects',
          'clients',
          'suppliers',
          'products',
          'invoice_counters',
        ]);

        // Restore tables in correct order (parents before children)
        for (var tableName in [
          'products',
          'suppliers',
          'clients',
          'approved_projects',
          'purchase_invoices',
          'sale_invoices',
          'purchase_invoice_items',
          'sale_invoice_items',
          'payments',
          'invoice_counters',
        ]) {
          final rows =
              List<Map<String, dynamic>>.from(tables[tableName] ?? []);
          for (var row in rows) {
            try {
              await txn.insert(tableName, Map<String, dynamic>.from(row),
                  conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (_) {
              // Skip rows that don't fit legacy schemas.
            }
          }
        }
      });

      // 5. Restore app settings
      if (settingsData != null && settingsData.isNotEmpty) {
        await _restoreAppSettings(settingsData);
      }

      // 6. Restore license key
      if (licenseKeyFromPayload != null && licenseKeyFromPayload.isNotEmpty) {
        await _importLicenseKey(licenseKeyFromPayload);
      }

      return true;
    } catch (e) {
      debugPrint('Restore Backup Error: $e');
      rethrow;
    }
  }

  /// Safely delete all rows from tables
  static Future<void> _safeDeleteAll(Transaction txn, List<String> tables) async {
    for (final table in tables) {
      try {
        await txn.delete(table);
      } catch (_) {}
    }
  }

  /// Restore app settings from backup data
  static Future<void> _restoreAppSettings(Map<String, dynamic> settingsData) async {
    final prefs = await SharedPreferences.getInstance();
    // Restore currency
    final currency = settingsData['currency'] as String?;
    if (currency != null && currency.isNotEmpty) {
      await prefs.setString(AppConstants.prefCurrency, currency);
    }
    // Restore printer header
    final printerHeader = settingsData['printerHeader'] as String?;
    if (printerHeader != null && printerHeader.isNotEmpty) {
      await prefs.setString(AppConstants.prefPrinterHeader, printerHeader);
    }
    // Restore first launch flag
    final isFirstLaunch = settingsData['isFirstLaunch'] as bool?;
    if (isFirstLaunch != null) {
      await prefs.setBool(AppConstants.prefFirstLaunch, isFirstLaunch);
    }
  }

  /// Import and store license key from backup
  static Future<void> _importLicenseKey(String licenseKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLicenseKey, licenseKey.trim());
  }

  /// Write encrypted backup file to disk (.wthaq)
  static Future<File> exportBackupToFile(String targetFilePath) async {
    final backupBytes = await generateBackupData();
    final file = File(targetFilePath);
    await file.writeAsBytes(backupBytes);
    return file;
  }

  /// Import and restore from file (.wthaq)
  static Future<bool> restoreFromFile(File file) async {
    final bytes = await file.readAsBytes();
    return await restoreFromBackupData(bytes);
  }
}