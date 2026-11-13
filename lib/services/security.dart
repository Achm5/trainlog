import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:trainlog/i18n.dart';

/// Хэш PIN-кода для settings.pin_hash (сам PIN не хранится).
String pinHash(String pin) => sha256.convert(utf8.encode('achm-trainlog:$pin')).toString();

bool isValidPin(String pin) => RegExp(r'^\d{4,8}$').hasMatch(pin);

/// Биометрия устройства (отпечаток, лицо).
class BiometricService {
  final _auth = LocalAuthentication();

  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(localizedReason: tr('Вход в приложение'));
    } catch (_) {
      return false;
    }
  }
}
