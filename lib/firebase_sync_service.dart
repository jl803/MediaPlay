import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

enum FirebaseCrashStatus {
  unavailable,
  connecting,
  connected,
  error,
}

class FirebaseSyncService extends ChangeNotifier {
  FirebaseSyncService._();

  static final FirebaseSyncService instance = FirebaseSyncService._();

  FirebaseCrashStatus _status = FirebaseCrashStatus.unavailable;
  bool _initialized = false;
  bool _initializing = false;
  String? _errorMessage;
  bool _hasPendingCrashReport = false;
  bool _didCrashOnPreviousExecution = false;

  FirebaseCrashStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == FirebaseCrashStatus.connected;
  bool get hasPendingCrashReport => _hasPendingCrashReport;
  bool get didCrashOnPreviousExecution => _didCrashOnPreviousExecution;

  String get statusLabel => switch (_status) {
        FirebaseCrashStatus.unavailable => 'Not configured',
        FirebaseCrashStatus.connecting => 'Connecting',
        FirebaseCrashStatus.connected => 'Crash reporting ready',
        FirebaseCrashStatus.error => 'Configuration issue',
      };

  Future<void> initialize() async {
    if (_initialized || _initializing) {
      return;
    }

    _initializing = true;
    _status = FirebaseCrashStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      await Firebase.initializeApp();
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      _didCrashOnPreviousExecution =
          await FirebaseCrashlytics.instance.didCrashOnPreviousExecution();
      _hasPendingCrashReport =
          await FirebaseCrashlytics.instance.checkForUnsentReports();
      _initialized = true;
      _status = FirebaseCrashStatus.connected;
    } catch (e) {
      _status = FirebaseCrashStatus.error;
      _errorMessage = e.toString();
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    if (!_initialized) {
      return;
    }

    await FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  }

  Future<bool> sendPendingCrashReport() async {
    await initialize();
    if (!_initialized || !_hasPendingCrashReport) {
      return false;
    }

    try {
      await FirebaseCrashlytics.instance.sendUnsentReports();
      _hasPendingCrashReport = false;
      notifyListeners();
      return true;
    } catch (e) {
      _status = FirebaseCrashStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> discardPendingCrashReport() async {
    await initialize();
    if (!_initialized || !_hasPendingCrashReport) {
      return false;
    }

    try {
      await FirebaseCrashlytics.instance.deleteUnsentReports();
      _hasPendingCrashReport = false;
      notifyListeners();
      return true;
    } catch (e) {
      _status = FirebaseCrashStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> triggerTestCrash() async {
    await initialize();
    if (!_initialized) {
      return false;
    }

    await FirebaseCrashlytics.instance.log('Intentional Crashlytics test crash triggered from Settings.');
    FirebaseCrashlytics.instance.crash();
    return true;
  }
}
