import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/sensor_repository.dart';
import '../datasources/sensor_remote_data_source.dart';

class SensorRepositoryImpl implements SensorRepository {
  final SensorRemoteDataSource _remoteDataSource;
  Stream<Map<String, dynamic>>? _currentStream;
  bool _isStreamActive = false;
  bool _usePolling = false;

  SensorRepositoryImpl(this._remoteDataSource);

  @override
  Stream<Map<String, dynamic>> getDataStream() {
    if (_isStreamActive && _currentStream != null) {
      return _currentStream!;
    }

    // Selalu gunakan polling 3 detik untuk update realtime
    _currentStream = _remoteDataSource.getRealtimeData(intervalSeconds: 3);
    _usePolling = true;
    _isStreamActive = true;
    
    _log('🔄 Repository: Started 3-second polling stream');
    return _currentStream!;
  }

  @override
  Stream<Map<String, dynamic>> getDataPolling({int intervalSeconds = 3}) {
    _currentStream = _remoteDataSource.getRealtimeData(intervalSeconds: intervalSeconds);
    _usePolling = true;
    _isStreamActive = true;
    
    _log('🔄 Repository: Started polling stream with $intervalSeconds seconds interval');
    return _currentStream!;
  }

  @override
  Future<Map<String, dynamic>> fetchInitialData() async {
    _log('🚀 Repository: Fetching initial data with retry logic');
    
    // Retry logic untuk initial data
    for (int i = 0; i < 3; i++) {
      try {
        final data = await _remoteDataSource.fetchInitialData();
        _log('✅ Repository: Initial data fetched successfully on attempt ${i + 1}');
        return data;
      } catch (e) {
        _log('❌ Repository: Attempt ${i + 1} failed: $e');
        if (i < 2) {
          _log('⏳ Repository: Waiting 2 seconds before retry...');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    
    _log('💥 Repository: Failed to fetch initial data after 3 attempts');
    throw Exception('Failed to fetch initial data after 3 attempts');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchHistoricalData({int limit = 20}) {
    _log('📚 Repository: Fetching historical data (limit: $limit)');
    return _remoteDataSource.fetchHistoricalData(limit: limit);
  }

  @override
  Future<bool> sendAutomaticControl(double suhu, double kelembapan) {
    _log('🎛️ Repository: Sending automatic control - Suhu: $suhu°C, Kelembapan: $kelembapan%');
    return _remoteDataSource.sendAutomaticControl(suhu, kelembapan);
  }

  @override
  Future<bool> sendManualControl({
    bool? statusLampu,
    bool? statusHumidifier,
    double? targetKelembapan,
  }) {
    _log('🔄 Repository: Sending manual control - '
        'Lampu: $statusLampu, Humidifier: $statusHumidifier, Target: $targetKelembapan');
    
    return _remoteDataSource.sendManualControl(
      statusLampu: statusLampu,
      statusHumidifier: statusHumidifier,
      targetKelembapan: targetKelembapan,
    );
  }

  @override
  Future<bool> checkConnection() {
    _log('🌐 Repository: Checking connection');
    return _remoteDataSource.checkConnection();
  }

  @override
  bool get isStreamActive => _isStreamActive;

  @override
  bool get isUsingPolling => _usePolling;

  @override
  Future<void> dispose() async {
    _log('🛑 Repository: Disposing...');
    _remoteDataSource.dispose();
    _currentStream = null;
    _isStreamActive = false;
    _usePolling = false;
    _log('✅ Repository disposed');
  }

  // Helper method untuk logging yang aman
  void _log(String message) {
    if (kDebugMode) {
      print('SensorRepositoryImpl: $message');
    }
  }
}