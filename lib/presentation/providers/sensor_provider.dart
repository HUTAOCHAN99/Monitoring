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
  
  // Counter untuk tracking data source
  int _newDataCount = 0;
  int _databaseDataCount = 0;
  
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
  int get newDataCount => _newDataCount;
  int get databaseDataCount => _databaseDataCount;

  Stream<Map<String, dynamic>> getDataStream() {
    return _dataStream ??= _sensorRepository.getDataStream();
  }

  void initialize() {
    if (_subscription != null) {
      return;
    }
    
    _log('🚀 Initializing SensorProvider...');
    
    _loadInitialDataWithRetry().then((_) {
      _log('✅ Initial data loaded, starting history and stream...');
      _loadHistoricalData();
      _listenToData();
    }).catchError((e) {
      _log('❌ Failed to load initial data: $e');
      _error = 'Gagal memuat data awal: $e';
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _loadInitialDataWithRetry() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    _log('🔄 Starting initial data load with retry mechanism...');
    
    while (retryCount < maxRetries && _latestSensorData == null) {
      try {
        _log('🔄 Attempting to load initial data (attempt ${retryCount + 1}/$maxRetries)');
        await _loadInitialData();
        
        if (_latestSensorData != null) {
          _log('✅ Initial data loaded successfully on attempt ${retryCount + 1}');
          break;
        } else {
          _log('⚠️  No data received on attempt ${retryCount + 1}');
        }
      } catch (e) {
        _log('❌ Initial data load failed on attempt ${retryCount + 1}: $e');
        retryCount++;
        if (retryCount < maxRetries) {
          _log('⏳ Waiting 2 seconds before retry...');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    
    if (_latestSensorData == null) {
      _log('💥 Failed to load initial data after $maxRetries attempts');
      _error = 'Tidak dapat memuat data awal. Pastikan perangkat sudah mengirim data ke database.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadInitialData() async {
    try {
      _log('🚀 Loading initial data from repository...');
      final initialData = await _sensorRepository.fetchInitialData();
      
      if (initialData != null) {
        final sensorData = initialData['sensor'] as SensorData;
        final deviceStatus = initialData['device'] as DeviceStatus;
        
        _latestSensorData = sensorData;
        _latestDeviceStatus = deviceStatus;
        _lastDataTimestamp = sensorData.timestamp;
        
        // Tambahkan ke history
        _dataHistory.add(initialData);
        
        _isLoading = false;
        _isConnected = true;
        _error = null;
        
        _log('✅ Initial data set: ${sensorData.suhu}°C, ${sensorData.kelembapan}% at ${sensorData.timestamp}');
        notifyListeners();
      } else {
        _log('⚠️  Initial data is null');
        throw Exception('No initial data received');
      }
    } catch (e) {
      _log('❌ Error loading initial data: $e');
      rethrow;
    }
  }

  Future<void> _loadHistoricalData() async {
    try {
      _isLoadingHistory = true;
      notifyListeners();

      _log('📚 Loading historical data...');
      
      final historicalData = await _sensorRepository.fetchHistoricalData(limit: 500);
      
      _dataHistory = historicalData;
      
      if (_dataHistory.isNotEmpty) {
        final latestSensor = _dataHistory.last['sensor'] as SensorData;
        _lastDataTimestamp = latestSensor.timestamp;
        _log('📊 Historical data loaded: ${_dataHistory.length} items, latest: $_lastDataTimestamp');
      } else {
        _log('💤 No historical data found');
      }
      
      _isLoadingHistory = false;
      notifyListeners();
    } catch (e) {
      _log('❌ Error loading historical data: $e');
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
      _log('🎯 Real-time stream started');
    } catch (e) {
      _log('❌ Realtime failed, falling back to polling: $e');
      _usePollingFallback();
    }
  }

  void _usePollingFallback() {
    try {
      _dataStream = _sensorRepository.getDataPolling(intervalSeconds: 5);
      _setupSubscription();
      _log('🔄 Fallback to polling mode (5 seconds)');
    } catch (e) {
      _error = 'Gagal memulai monitoring: $e';
      _isLoading = false;
      notifyListeners();
      _log('💥 Polling fallback also failed: $e');
    }
  }

  void _setupSubscription() {
    _subscription = _dataStream?.listen(
      (data) {
        final sensorData = data['sensor'] as SensorData;
        final deviceStatus = data['device'] as DeviceStatus;
        final source = data['source'] as String? ?? 'unknown';
        
        // Track data source
        if (source == 'sequential' || source == 'initial') {
          _newDataCount++;
          _log('🆕 New data from sensor: ${sensorData.suhu}°C, ${sensorData.kelembapan}%');
        } else if (source == 'database_latest') {
          _databaseDataCount++;
          _log('📋 Data from database: ${sensorData.suhu}°C, ${sensorData.kelembapan}%');
        }

        // SELALU update data, regardless of timestamp
        // Ini memastikan data terbaru dari database selalu ditampilkan
        _latestSensorData = sensorData;
        _latestDeviceStatus = deviceStatus;
        _lastDataTimestamp = sensorData.timestamp;
        
        // Tambahkan ke history
        _addToHistory(data);
        
        _isLoading = false;
        _isConnected = true;
        _error = null;
        
        _log('✅ Data updated - Source: $source, Total new: $_newDataCount, Total db: $_databaseDataCount');
        
        notifyListeners();
      },
      onError: (error) {
        _error = 'Koneksi gagal: $error';
        _isLoading = false;
        _isConnected = false;
        _log('❌ Stream error: $error');
        notifyListeners();
      },
      onDone: () {
        _isConnected = false;
        _subscription = null;
        _log('📭 Data stream closed, attempting to restart...');
        Future.delayed(const Duration(seconds: 3), () {
          if (_subscription == null) {
            _log('🔄 Restarting data stream...');
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
        _log('⏰ Loading timeout - no data received');
        notifyListeners();
      }
    });
  }

  // Method untuk menambah data ke history (selalu update)
  void _addToHistory(Map<String, dynamic> newData) {
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
      
      // Batasi history
      _cleanupOldData();
      
      _log('📈 ADDED data to history - Total: ${_dataHistory.length}');
    } else {
      // Update data existing
      _dataHistory[existingIndex] = newData;
      _log('🔄 UPDATED existing data at index $existingIndex');
    }
  }

  void _cleanupOldData() {
    if (_dataHistory.length > MAX_HISTORY_LENGTH) {
      _dataHistory = _dataHistory.sublist(_dataHistory.length - (MAX_HISTORY_LENGTH ~/ 2));
      _log('🧹 Cleaned up old history data, now: ${_dataHistory.length} records');
    }
  }

  Future<void> refreshHistoricalData() async {
    _log('🔄 Manual refresh: Loading all historical data...');
    await _loadHistoricalData();
  }

  Future<void> forceRefresh() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      _log('🔁 Force refreshing data...');
      
      final newData = await _sensorRepository.fetchInitialData();
      
      _latestSensorData = newData['sensor'] as SensorData;
      _latestDeviceStatus = newData['device'] as DeviceStatus;
      _lastDataTimestamp = _latestSensorData!.timestamp;
      
      _addToHistory(newData);
      
      _isLoading = false;
      _isConnected = true;
      _error = null;
      notifyListeners();
      
      _log('✅ Force refresh completed');
      
    } catch (e) {
      _error = 'Refresh failed: $e';
      _isLoading = false;
      notifyListeners();
      _log('❌ Force refresh error: $e');
    }
  }

  Map<String, dynamic> getDataStatistics() {
    if (_dataHistory.isEmpty) {
      return {
        'totalPoints': 0,
        'timeRange': 'No data',
        'avgTemperature': 0,
        'avgHumidity': 0,
        'lastTimestamp': null,
        'newDataCount': _newDataCount,
        'databaseDataCount': _databaseDataCount,
      };
    }

    final oldest = (_dataHistory.first['sensor'] as SensorData).timestamp;
    final latest = (_dataHistory.last['sensor'] as SensorData).timestamp;
    final duration = latest.difference(oldest);

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
      'newDataCount': _newDataCount,
      'databaseDataCount': _databaseDataCount,
    };
  }

  List<Map<String, dynamic>> getDataInTimeRange(DateTime start, DateTime end) {
    return _dataHistory.where((data) {
      final sensor = data['sensor'] as SensorData;
      return sensor.timestamp.isAfter(start) && sensor.timestamp.isBefore(end);
    }).toList();
  }

  void clearHistory() {
    _dataHistory.clear();
    _lastDataTimestamp = null;
    _log('🗑️ Cleared all history data');
    notifyListeners();
  }

  void retry() {
    _log('🔄 Retrying connection...');
    
    _subscription?.cancel();
    _subscription = null;
    
    _isLoading = true;
    _error = null;
    _dataHistory.clear();
    _latestSensorData = null;
    _latestDeviceStatus = null;
    _lastDataTimestamp = null;
    _newDataCount = 0;
    _databaseDataCount = 0;
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

  void _log(String message) {
    if (kDebugMode) {
      print('SensorProvider: $message');
    }
  }

  @override
  void dispose() {
    _log('🛑 Disposing SensorProvider...');
    _subscription?.cancel();
    _sensorRepository.dispose();
    super.dispose();
  }
}