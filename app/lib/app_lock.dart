import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'app_lock_enabled';

/// Locks the app behind the phone's fingerprint, face or screen-lock PIN.
class AppLock {
  AppLock._();

  static final _auth = LocalAuthentication();

  /// Set while the app deliberately leaves the foreground (camera, file picker)
  /// so coming back does not count as re-opening the app.
  static bool suspended = false;

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  /// Whether the phone has a screen lock or biometrics that we can use.
  static Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock HealthVault to see your reports',
      );
    } catch (_) {
      return false;
    }
  }
}
