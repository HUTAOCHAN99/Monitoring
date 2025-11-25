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
  bool _isLoadingHistory = false;

  SensorProvider(this._sensorRepository);

  SensorData? get latestSensorData => _latestSensorData;
  DeviceStatus? get latestDeviceStatus => _latestDeviceStatus;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasData => _latestSensorData != null && _latestDeviceStatus != null;
  bool get isConnected => _isConnected;
  List<Map<String, dynamic>> get dataHistory => _dataHistory;
  bool get isLoadingHistory => _isLoadingHistory;

  void initialize() {
    if (_subscription != null) {
      return;
    }
    
    _loadHistoricalData(); // Load data historis dulu
    _listenToData();
  }

  // Method baru: Load SEMUA data historis dari awal
  Future<void> _loadHistoricalData() async {
    try {
      _isLoadingHistory = true;
      notifyListeners();

      // Ambil SEMUA data historis (limit besar untuk cover semua data)
      final historicalData = await _sensorRepository.fetchHistoricalData(limit: 500);
      
      // Simpan semua data tanpa filter waktu
      _dataHistory = historicalData;
      
      // Urutkan data berdasarkan timestamp (terlama ke terbaru)
      _dataHistory.sort((a, b) {
        final sensorA = a['sensor'] as SensorData;
        final sensorB = b['sensor'] as SensorData;
        return sensorA.timestamp.compareTo(sensorB.timestamp);
      });

      print('📊 Loaded ${_dataHistory.length} data points (ALL DATA FROM BEGINNING)');
      
      // Debug info
      if (_dataHistory.isNotEmpty) {
        final oldest = (_dataHistory.first['sensor'] as SensorData).timestamp;
        final latest = (_dataHistory.last['sensor'] as SensorData).timestamp;
        final duration = latest.difference(oldest);
        print('📊 Data range: ${duration.inHours} hours ${duration.inMinutes.remainder(60)} minutes');
        print('📊 From: $oldest to $latest');
      }
      
      _isLoadingHistory = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading historical data: $e');
      _isLoadingHistory = false;
      notifyListeners();
    }
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
        
        // Tambahkan data baru ke history
        _addToHistory(data);
        
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

  // Method baru: Tambah data ke history (semua data disimpan)
  void _addToHistory(Map<String, dynamic> newData) {
    final sensor = newData['sensor'] as SensorData;
    
    // Cek apakah data sudah ada (berdasarkan timestamp)
    final existingIndex = _dataHistory.indexWhere((existing) {
      final existingSensor = existing['sensor'] as SensorData;
      return existingSensor.timestamp == sensor.timestamp;
    });
    
    if (existingIndex == -1) {
      // Data baru, tambahkan
      _dataHistory.add(newData);
      
      // Urutkan berdasarkan timestamp (terlama ke terbaru)
      _dataHistory.sort((a, b) {
        final sensorA = a['sensor'] as SensorData;
        final sensorB = b['sensor'] as SensorData;
        return sensorA.timestamp.compareTo(sensorB.timestamp);
      });
      
      print('📈 History updated: ${_dataHistory.length} total data points');
      
      // Debug: Info tentang data terbaru
      if (_dataHistory.length % 10 == 0) { // Log setiap 10 data baru
        final oldest = (_dataHistory.first['sensor'] as SensorData).timestamp;
        final latest = (_dataHistory.last['sensor'] as SensorData).timestamp;
        final duration = latest.difference(oldest);
        print('📊 Current data range: ${duration.inHours}h ${duration.inMinutes.remainder(60)}m');
      }
    } else {
      // Data sudah ada, update dengan data baru
      _dataHistory[existingIndex] = newData;
      print('🔄 Updated existing data point at index $existingIndex');
    }
  }

  // Method untuk refresh data historis (load ulang semua data)
  Future<void> refreshHistoricalData() async {
    print('🔄 Manual refresh: Loading all historical data...');
    await _loadHistoricalData();
  }

  // Method untuk mendapatkan statistik data
  Map<String, dynamic> getDataStatistics() {
    if (_dataHistory.isEmpty) {
      return {
        'totalPoints': 0,
        'timeRange': 'No data',
        'avgTemperature': 0,
        'avgHumidity': 0,
      };
    }

    final oldest = (_dataHistory.first['sensor'] as SensorData).timestamp;
    final latest = (_dataHistory.last['sensor'] as SensorData).timestamp;
    final duration = latest.difference(oldest);

    // Hitung rata-rata suhu dan kelembapan
    double totalTemp = 0;
    double totalHumidity = 0;
    
    for (final data in _dataHistory) {
      final sensor = data['sensor'] as SensorData;
      totalTemp += sensor.suhu;
      totalHumidity += sensor.kelembapan;
    }

    final avgTemp = totalTemp / _dataHistory.length;
    final avgHumidity = totalHumidity / _dataHistory.length;

    return {
      'totalPoints': _dataHistory.length,
      'timeRange': '${duration.inHours}h ${duration.inMinutes.remainder(60)}m',
      'avgTemperature': avgTemp,
      'avgHumidity': avgHumidity,
      'oldestData': oldest,
      'latestData': latest,
    };
  }

  // Method untuk mendapatkan data dalam rentang waktu tertentu (opsional)
  List<Map<String, dynamic>> getDataInTimeRange(DateTime start, DateTime end) {
    return _dataHistory.where((data) {
      final sensor = data['sensor'] as SensorData;
      return sensor.timestamp.isAfter(start) && sensor.timestamp.isBefore(end);
    }).toList();
  }

  // Method untuk clear data history (opsional, untuk debugging)
  void clearHistory() {
    _dataHistory.clear();
    print('🗑️ Cleared all history data');
    notifyListeners();
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