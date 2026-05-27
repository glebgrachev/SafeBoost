import 'package:flutter/foundation.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vpn_config.dart';
 
enum VpnStatus { disconnected, connecting, connected, disconnecting, error, limitReached }
 
class VpnService extends ChangeNotifier {
  late final FlutterVless _vless;
 
  int _trafficLimitBytes = 10 * 1024 * 1024 * 1024;
  String _activeVlessUri = VpnConfig.defaultVlessUri;
  String? _activeConfigId;
  bool _isUserCounted = false;
 
  VpnStatus _status = VpnStatus.disconnected;
  String _statusMessage = 'Отключено';
  String _upload = '0 B/s';
  String _download = '0 B/s';
  String? _errorMessage;
 
  int _totalUpload = 0;
  int _totalDownload = 0;
 
  VpnStatus get status => _status;
  String get statusMessage => _statusMessage;
  String get upload => _upload;
  String get download => _download;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == VpnStatus.connected;
  bool get isLimitReached => _status == VpnStatus.limitReached;
  bool get isBusy =>
      _status == VpnStatus.connecting || _status == VpnStatus.disconnecting;
 
  double get trafficProgress =>
      ((_totalUpload + _totalDownload) / _trafficLimitBytes).clamp(0.0, 1.0);
 
  String get trafficUsed {
    final total = _totalUpload + _totalDownload;
    if (total < 1024 * 1024) return '${(total / 1024).toStringAsFixed(1)} KB';
    return '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
 
  String get trafficLimit {
    final mb = _trafficLimitBytes ~/ (1024 * 1024);
    if (mb >= 1024) return '${mb ~/ 1024} GB';
    return '$mb MB';
  }
 
  VpnService() {
    _vless = FlutterVless(onStatusChanged: _onStatusChanged);
    _init();
  }
 
  Future<void> _init() async {
    try {
      await _vless.initializeVless(
        providerBundleIdentifier: '',
        groupIdentifier: '',
      );
    } catch (e) {
      debugPrint('[VPN] initializeVless() ERROR: $e');
    }
    await _loadRemoteConfig();
    await _loadFirestoreConfig();
  }
 
  Future<void> _loadRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.setDefaults({'traffic_limit_mb': 10240});
      await remoteConfig.fetchAndActivate();
      final limitMb = remoteConfig.getInt('traffic_limit_mb');
      debugPrint('[RC] traffic_limit_mb = $limitMb');
      _trafficLimitBytes = limitMb * 1024 * 1024;
      notifyListeners();
    } catch (e) {
      debugPrint('[VPN] Remote Config ERROR: $e — используем дефолт 10GB');
    }
  }
 
  Future<void> _loadFirestoreConfig() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('configs')
          .where('is_active', isEqualTo: true)
          .orderBy('current_users')
          .orderBy('priority')
          .limit(1)
          .get();
 
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        _activeConfigId = doc.id;
 
        final uri = data['vless_uri'] as String?;
        final limitMb = data['limit_mb'] as int?;
 
        if (uri != null && uri.isNotEmpty) {
          _activeVlessUri = uri;
          debugPrint('[FS] vless_uri loaded, config: $_activeConfigId');
        }
        if (limitMb != null) {
          _trafficLimitBytes = limitMb * 1024 * 1024;
          debugPrint('[FS] limit_mb = $limitMb');
        }
        notifyListeners();
      } else {
        debugPrint('[FS] No active config — using default');
      }
    } catch (e) {
      debugPrint('[FS] Firestore ERROR: $e — используем дефолт');
    }
  }
 
  Future<void> _incrementUsers() async {
    if (_activeConfigId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('configs')
          .doc(_activeConfigId)
          .update({'current_users': FieldValue.increment(1)});
      debugPrint('[FS] current_users +1');
    } catch (e) {
      debugPrint('[FS] increment ERROR: $e');
    }
  }
 
  Future<void> _decrementUsers() async {
    if (_activeConfigId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('configs')
          .doc(_activeConfigId)
          .update({'current_users': FieldValue.increment(-1)});
      debugPrint('[FS] current_users -1');
    } catch (e) {
      debugPrint('[FS] decrement ERROR: $e');
    }
  }
 
  void _onStatusChanged(VlessStatus status) {
    switch (status.state) {
      case 'CONNECTED':
        debugPrint('[FS] CONNECTED, isUserCounted=$_isUserCounted');
        if (!_isUserCounted) {
          _incrementUsers();
          _isUserCounted = true;
        }
        _totalUpload += status.upload;
        _totalDownload += status.download;
        _upload = _formatBytes(status.uploadSpeed);
        _download = _formatBytes(status.downloadSpeed);
        if (_totalUpload + _totalDownload >= _trafficLimitBytes) {
          _reachLimit();
          return;
        }
        _status = VpnStatus.connected;
        _statusMessage = 'Подключено';
        _errorMessage = null;
        break;
      case 'CONNECTING':
        _status = VpnStatus.connecting;
        _statusMessage = 'Подключение...';
        break;
      case 'DISCONNECTING':
        _status = VpnStatus.disconnecting;
        _statusMessage = 'Отключение...';
        break;
      case 'DISCONNECTED':
        debugPrint('[FS] DISCONNECTED, isUserCounted=$_isUserCounted');
        if (_isUserCounted) {
          _decrementUsers();
          _isUserCounted = false;
        }
        if (_status != VpnStatus.limitReached) {
          _status = VpnStatus.disconnected;
          _statusMessage = 'Отключено';
        }
        _upload = '0 B/s';
        _download = '0 B/s';
        break;
      case 'ERROR':
        _setError('Ошибка подключения');
        break;
    }
    notifyListeners();
  }
 
  Future<void> _reachLimit() async {
    _status = VpnStatus.limitReached;
    _statusMessage = 'Лимит исчерпан';
    _upload = '0 B/s';
    _download = '0 B/s';
    notifyListeners();
    try { await _vless.stopVless(); } catch (_) {}
  }
 
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
 
  Future<void> toggleConnection() async {
    if (isBusy || isLimitReached) return;
    if (isConnected) { await disconnect(); } else { await connect(); }
  }
 
  Future<void> connect() async {
    if (isLimitReached) return;
    _status = VpnStatus.connecting;
    _statusMessage = 'Подключение...';
    _errorMessage = null;
    notifyListeners();
    try {
      final hasPermission = await _vless.requestPermission();
      if (!hasPermission) { _setError('Разрешение VPN отклонено'); return; }
      final parser = FlutterVless.parseFromURL(_activeVlessUri);
      final config = parser.getFullConfiguration();
      await _vless.startVless(
        remark: 'SafeBoost',
        config: config,
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );
    } catch (e, stack) {
      debugPrint('[VPN] ERROR: $e\n$stack');
      _setError('Ошибка: ${e.toString()}');
    }
  }
 
  Future<void> disconnect() async {
    _status = VpnStatus.disconnecting;
    _statusMessage = 'Отключение...';
    notifyListeners();
    try {
      await _vless.stopVless();
    } catch (e) {
      _status = VpnStatus.disconnected;
      _statusMessage = 'Отключено';
      notifyListeners();
    }
  }
 
  void _setError(String message) {
    _status = VpnStatus.error;
    _statusMessage = 'Ошибка';
    _errorMessage = message;
    notifyListeners();
    Future.delayed(const Duration(seconds: 10), () {
      if (_status == VpnStatus.error) {
        _status = VpnStatus.disconnected;
        _statusMessage = 'Отключено';
        _errorMessage = null;
        notifyListeners();
      }
    });
  }
 
  @override
  void dispose() {
    if (_isUserCounted) {
      _decrementUsers();
      _isUserCounted = false;
    }
    super.dispose();
  }
}