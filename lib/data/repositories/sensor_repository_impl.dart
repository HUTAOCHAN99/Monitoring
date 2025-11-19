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
    
    print('🔄 Repository: Started 3-second polling stream');
    return _currentStream!;
  }

  @override
  Stream<Map<String, dynamic>> getDataPolling({int intervalSeconds = 3}) {
    _currentStream = _remoteDataSource.getRealtimeData(intervalSeconds: intervalSeconds);
    _usePolling = true;
    _isStreamActive = true;
    
    print('🔄 Repository: Started polling stream with $intervalSeconds seconds interval');
    return _currentStream!;
  }

  @override
  Future<Map<String, dynamic>> fetchInitialData() {
    print('🚀 Repository: Fetching initial data');
    return _remoteDataSource.fetchInitialData();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchHistoricalData({int limit = 20}) {
    print('📚 Repository: Fetching historical data (limit: $limit)');
    return _remoteDataSource.fetchHistoricalData(limit: limit);
  }

  @override
  Future<bool> sendAutomaticControl(double suhu, double kelembapan) {
    print('🎛️ Repository: Sending automatic control - Suhu: $suhu°C, Kelembapan: $kelembapan%');
    return _remoteDataSource.sendAutomaticControl(suhu, kelembapan);
  }

  @override
  Future<bool> sendManualControl({
    bool? statusLampu,
    bool? statusHumidifier,
    double? targetKelembapan,
  }) {
    print('🔄 Repository: Sending manual control - '
        'Lampu: $statusLampu, Humidifier: $statusHumidifier, Target: $targetKelembapan');
    
    return _remoteDataSource.sendManualControl(
      statusLampu: statusLampu,
      statusHumidifier: statusHumidifier,
      targetKelembapan: targetKelembapan,
    );
  }

  @override
  Future<bool> checkConnection() {
    print('🌐 Repository: Checking connection');
    return _remoteDataSource.checkConnection();
  }

  @override
  bool get isStreamActive => _isStreamActive;

  @override
  bool get isUsingPolling => _usePolling;

  @override
  Future<void> dispose() async {
    print('🛑 Repository: Disposing...');
    _remoteDataSource.dispose();
    _currentStream = null;
    _isStreamActive = false;
    _usePolling = false;
    print('✅ Repository disposed');
  }
}