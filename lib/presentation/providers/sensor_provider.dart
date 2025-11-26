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
  DateTime? _lastDataTimestamp;
  
  // Konstanta optimasi
  static const int MAX_HISTORY_LENGTH = 500;

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

  // Method untuk mendapatkan data stream
  Stream<Map<String, dynamic>> getDataStream() {
    return _dataStream ??= _sensorRepository.getDataStream();
  }

  void initialize() {
    if (_subscription != null) {
      return;
    }
    
    _loadHistoricalData(); // Load data historis dulu
    _listenToData();
  }

  // Method untuk load SEMUA data historis dari awal
  Future<void> _loadHistoricalData() async {
    try {
      _isLoadingHistory = true;
      notifyListeners();

      // Ambil SEMUA data historis (limit besar untuk cover semua data)
      final historicalData = await _sensorRepository.fetchHistoricalData(limit: 500);
      
      // Simpan semua data tanpa filter waktu
      _dataHistory = historicalData;
      
      // Set last timestamp dari data historis
      if (_dataHistory.isNotEmpty) {
        final latestSensor = _dataHistory.last['sensor'] as SensorData;
        _lastDataTimestamp = latestSensor.timestamp;
      }
      
      // Debug info
      if (_dataHistory.isNotEmpty) {
        final oldest = (_dataHistory.first['sensor'] as SensorData).timestamp;
        final latest = (_dataHistory.last['sensor'] as SensorData).timestamp;
        final duration = latest.difference(oldest);
        if (kDebugMode) {
          print('📊 Loaded ${_dataHistory.length} data points (ALL DATA FROM BEGINNING)');
          print('📊 Data range: ${duration.inHours} hours ${duration.inMinutes.remainder(60)} minutes');
          print('📊 From: $oldest to $latest');
          print('📊 Last timestamp set to: $_lastDataTimestamp');
        }
      }
      
      _isLoadingHistory = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading historical data: $e');
      }
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
      if (kDebugMode) {
        print('Realtime failed, falling back to polling: $e');
      }
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
        final sensorData = data['sensor'] as SensorData;
        final deviceStatus = data['device'] as DeviceStatus;
        final sequentialCount = data['sequentialCount'] as int? ?? 1;
        
        // Cek apakah ini data sequential baru
        final isSequentialNew = _lastDataTimestamp == null || 
                               sensorData.timestamp.isAfter(_lastDataTimestamp!);
        
        if (isSequentialNew) {
          _latestSensorData = sensorData;
          _latestDeviceStatus = deviceStatus;
          _lastDataTimestamp = sensorData.timestamp;
          
          // Tambahkan ke history dengan penanganan sequential
          _addSequentialToHistory(data);
          
          _isLoading = false;
          _isConnected = true;
          _error = null;
          
          if (kDebugMode) {
            print('🔄 Sequential data updated: ${sensorData.timestamp}');
            print('📦 Sequential count: $sequentialCount records');
          }
          
          notifyListeners();
        } else {
          if (kDebugMode) {
            print('⏭️ Skipping duplicate/older data: ${sensorData.timestamp}');
          }
        }
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
        if (kDebugMode) {
          print('📭 Data stream closed, attempting to restart...');
        }
        Future.delayed(const Duration(seconds: 3), () {
          if (_subscription == null) {
            _listenToData();
          }
        });
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

  // Method improved untuk sequential history
  void _addSequentialToHistory(Map<String, dynamic> newData) {
    final sensor = newData['sensor'] as SensorData;
    
    // Cek apakah data sudah ada berdasarkan timestamp
    final existingIndex = _dataHistory.indexWhere((existing) {
      final existingSensor = existing['sensor'] as SensorData;
      return existingSensor.timestamp == sensor.timestamp;
    });
    
    if (existingIndex == -1) {
      // Data baru, tambahkan ke history
      _dataHistory.add(newData);
      
      // Urutkan history berdasarkan timestamp
      _dataHistory.sort((a, b) {
        final sensorA = a['sensor'] as SensorData;
        final sensorB = b['sensor'] as SensorData;
        return sensorA.timestamp.compareTo(sensorB.timestamp);
      });
      
      // Batasi history untuk menghindari memory overflow
      _cleanupOldData();
      
      if (kDebugMode) {
        print('📈 ADDED sequential data - Total: ${_dataHistory.length}');
      }
    } else {
      // Update data existing
      _dataHistory[existingIndex] = newData;
      if (kDebugMode) {
        print('🔄 UPDATED existing sequential data');
      }
    }
  }

  // Method untuk cleanup data lama
  void _cleanupOldData() {
    if (_dataHistory.length > MAX_HISTORY_LENGTH) {
      _dataHistory = _dataHistory.sublist(_dataHistory.length - (MAX_HISTORY_LENGTH ~/ 2));
      if (kDebugMode) {
        print('🧹 Cleaned up old history data, now: ${_dataHistory.length} records');
      }
    }
  }

  // Method untuk refresh data historis (load ulang semua data)
  Future<void> refreshHistoricalData() async {
    if (kDebugMode) {
      print('🔄 Manual refresh: Loading all historical data...');
    }
    await _loadHistoricalData();
  }

  // Method untuk memaksa update data terbaru
  Future<void> forceRefresh() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Fetch data terbaru langsung
      final newData = await _sensorRepository.fetchInitialData();
      
      _latestSensorData = newData['sensor'] as SensorData;
      _latestDeviceStatus = newData['device'] as DeviceStatus;
      _lastDataTimestamp = _latestSensorData!.timestamp;
      
      // Update history
      _addSequentialToHistory(newData);
      
      _isLoading = false;
      _isConnected = true;
      _error = null;
      notifyListeners();
      
      if (kDebugMode) {
        print('✅ Force refresh completed');
      }
      
    } catch (e) {
      _error = 'Refresh failed: $e';
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('❌ Force refresh error: $e');
      }
    }
  }

  // Method untuk mendapatkan statistik data
  Map<String, dynamic> getDataStatistics() {
    if (_dataHistory.isEmpty) {
      return {
        'totalPoints': 0,
        'timeRange': 'No data',
        'avgTemperature': 0,
        'avgHumidity': 0,
        'lastTimestamp': null,
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
      'lastTimestamp': _lastDataTimestamp,
    };
  }

  // Method untuk mendapatkan data dalam rentang waktu tertentu
  List<Map<String, dynamic>> getDataInTimeRange(DateTime start, DateTime end) {
    return _dataHistory.where((data) {
      final sensor = data['sensor'] as SensorData;
      return sensor.timestamp.isAfter(start) && sensor.timestamp.isBefore(end);
    }).toList();
  }

  // Method untuk clear data history (opsional, untuk debugging)
  void clearHistory() {
    _dataHistory.clear();
    _lastDataTimestamp = null;
    if (kDebugMode) {
      print('🗑️ Cleared all history data');
    }
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
    _lastDataTimestamp = null;
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