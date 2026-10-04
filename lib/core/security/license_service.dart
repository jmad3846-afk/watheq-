import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class LicenseValidationResult {
  final bool isValid;
  final bool isExpired;
  final String? expiryDateStr;
  final String errorMessage;

  const LicenseValidationResult({
    required this.isValid,
    this.isExpired = false,
    this.expiryDateStr,
    this.errorMessage = '',
  });
}

class LicenseService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Extract host system hardware ID (HWID)
  static Future<String> getHWID() async {
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        final raw = '${webInfo.vendor}_${webInfo.userAgent}_${webInfo.hardwareConcurrency}';
        return _hashString(raw).substring(0, 16).toUpperCase();
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        final raw = '${windowsInfo.deviceId}_${windowsInfo.computerName}_${windowsInfo.numberOfCores}';
        return _hashString(raw).substring(0, 16).toUpperCase();
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        final raw = '${linuxInfo.machineId}_${linuxInfo.name}';
        return _hashString(raw).substring(0, 16).toUpperCase();
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        final raw = '${macInfo.systemGUID}_${macInfo.computerName}';
        return _hashString(raw).substring(0, 16).toUpperCase();
      }
    } catch (e) {
      debugPrint('HWID Extraction Error: $e');
    }
    return 'WATHAQ-DEFAULT-HWID-2026';
  }

  /// Compute 10-char uppercase HMAC-SHA256 signature for payload "deviceId|YYYY-MM-DD"
  static String computeChecksum({
    required String hwid,
    required String expiryDateStr,
    String secretKey = AppConstants.secretKey,
  }) {
    final msg = "${hwid.trim()}|$expiryDateStr";
    final keyBytes = utf8.encode(secretKey);
    final msgBytes = utf8.encode(msg);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(msgBytes);
    return digest
        .toString()
        .replaceAll('-', '')
        .substring(0, 10)
        .toUpperCase();
  }

  /// Generate a valid license key given an HWID and Expiry Date (YYYY-MM-DD)
  static String generateLicenseKey({
    required String hwid,
    required String expiryDateStr,
    String secretKey = AppConstants.secretKey,
  }) {
    final checksum = computeChecksum(
      hwid: hwid,
      expiryDateStr: expiryDateStr,
      secretKey: secretKey,
    );
    return '$expiryDateStr-$checksum';
  }

  /// Validate a user-provided license key using the exact Admin Key Generator algorithm
  static Future<LicenseValidationResult> validateLicense(String key) async {
    final cleanInput = key.trim().replaceAll(' ', '');
    if (cleanInput.isEmpty) {
      return const LicenseValidationResult(
        isValid: false,
        errorMessage: 'الرجاء أدخل مفتاح التفعيل',
      );
    }

    final parts = cleanInput.split('-');

    // Must have exactly 4 parts: [YYYY, MM, DD, SIGNATURE]
    if (parts.length != 4) {
      return const LicenseValidationResult(
        isValid: false,
        errorMessage: 'صيغة المفتاح غير صالحة. الصيغة المطلوبة: YYYY-MM-DD-SIGNATURE',
      );
    }

    final year = parts[0];
    final month = parts[1];
    final day = parts[2];
    final providedSignature = parts[3].toUpperCase();

    final expiryStr = '$year-$month-$day';
    DateTime expiryDate;
    try {
      expiryDate = DateTime.parse(expiryStr);
    } catch (e) {
      return LicenseValidationResult(
        isValid: false,
        errorMessage: 'تاريخ الانتهاء في المفتاح غير صالح ($expiryStr)',
      );
    }

    final hwid = await getHWID();
    final secretKey = AppConstants.secretKey;

    // 1. Check Date Validity (Not Expired)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (expiryDate.isBefore(today)) {
      return LicenseValidationResult(
        isValid: false,
        isExpired: true,
        expiryDateStr: expiryStr,
        errorMessage: 'مفتاح التفعيل منتهي الصلاحية بتاريخ $expiryStr',
      );
    }

    // 2. Build Payload: "deviceId|YYYY-MM-DD"
    final msg = "${hwid.trim()}|$expiryStr";

    // 3. Compute HMAC-SHA256
    final keyBytes = utf8.encode(secretKey);
    final msgBytes = utf8.encode(msg);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(msgBytes);

    // 4. Extract First 10 Uppercase Hex Chars (removing any dashes)
    final computedSignature = digest
        .toString()
        .replaceAll('-', '')
        .substring(0, 10)
        .toUpperCase();

    // Debug logs to verify on console
    print('--- ACTIVATION DEBUG ---');
    print('Raw Input: $cleanInput');
    print('HWID Used: $hwid');
    print('Secret Used: $secretKey');
    print('Payload Message: "$msg"');
    print('Provided Signature: $providedSignature');
    print('Computed Signature: $computedSignature');
    print('Match Result: ${computedSignature == providedSignature}');
    print('------------------------');

    // 5. Compare Signatures
    if (computedSignature != providedSignature) {
      return LicenseValidationResult(
        isValid: false,
        errorMessage: 'رمز التحقق غير مطابق! (المحسوب: $computedSignature | المدخل: $providedSignature)',
      );
    }

    return LicenseValidationResult(
      isValid: true,
      expiryDateStr: expiryStr,
    );
  }

  /// Store valid license key locally
  static Future<void> saveStoredLicense(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLicenseKey, key.trim());
  }

  /// Retrieve stored license key
  static Future<String?> getStoredLicense() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefLicenseKey);
  }

  /// Clear stored license key
  static Future<void> clearStoredLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefLicenseKey);
  }

  static String _hashString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
