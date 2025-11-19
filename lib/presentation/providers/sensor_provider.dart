import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/sensor_data.dart';
import '../../domain/entities/device_status.dart';
import '../../domain/repositories/sensor_repository.dart';

class SensorProvider with ChangeNotifier {
  final SensorRepository _sensorRepository;
  
  SensorData? _latestSensorData;
  DeviceStatus? _latestDeviceStatus;
  bool _isLoading = true;
  String? _error;
  Stream<Map<String, dynamic>>? _dataStream;
  bool _isConnected = false;
  List<Map<String, dynamic>> _dataHistory = [];
  StreamSubscription<Map<String, dynamic>>? _subscription;

  SensorProvider(this._sensorRepository);

  SensorData? get latestSensorData => _latestSensorData;
  DeviceStatus? get latestDeviceStatus => _latestDeviceStatus;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasData => _latestSensorData != null && _latestDeviceStatus != null;
  bool get isConnected => _isConnected;
  List<Map<String, dynamic>> get dataHistory => _dataHistory;

  void initialize() {
    if (_subscription != null) {
      return;
    }
    
    _listenToData();
  }

  void _listenToData() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dataStream = _sensorRepository.getDataStream();
      _setupSubscription();
    } catch (e) {
      print('Realtime failed, falling back to polling: $e');
      _usePollingFallback();
    }
  }

  void _usePollingFallback() {
    try {
      _dataStream = _sensorRepository.getDataPolling(intervalSeconds: 5);
      _setupSubscription();
    } catch (e) {
      _error = 'Gagal memulai monitoring: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupSubscription() {
    _subscription = _dataStream?.listen(
      (data) {
        _latestSensorData = data['sensor'] as SensorData;
        _latestDeviceStatus = data['device'] as DeviceStatus;
        
        _dataHistory.add(data);
        if (_dataHistory.length > 10) {
          _dataHistory.removeAt(0);
        }
        
        _isLoading = false;
        _isConnected = true;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Koneksi gagal: $error';
        _isLoading = false;
        _isConnected = false;
        notifyListeners();
      },
      onDone: () {
        _isConnected = false;
        _subscription = null;
      },
      cancelOnError: false,
    );

    // Set timeout untuk loading
    Future.delayed(const Duration(seconds: 15), () {
      if (_isLoading && _latestSensorData == null) {
        _error = 'Tidak ada data. Pastikan perangkat mengirim data.';
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  void retry() {
    _subscription?.cancel();
    _subscription = null;
    
    _isLoading = true;
    _error = null;
    _dataHistory.clear();
    _latestSensorData = null;
    _latestDeviceStatus = null;
    notifyListeners();
    
    _sensorRepository.dispose();
    
    Future.delayed(const Duration(seconds: 1), () {
      initialize();
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _sensorRepository.dispose();
    super.dispose();
  }
}