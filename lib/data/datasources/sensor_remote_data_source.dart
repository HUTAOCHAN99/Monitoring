import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:monitoring/domain/entities/device_status.dart';
import 'package:monitoring/domain/entities/sensor_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sensor_data_model.dart';
import '../models/device_status_model.dart';
import '../../core/constants/app_constant.dart';
import '../../core/utils/automatic_control.dart';

class SensorRemoteDataSource {
  final SupabaseClient _supabaseClient;
  StreamController<Map<String, dynamic>>? _controller;
  RealtimeChannel? _sensorChannel;
  RealtimeChannel? _deviceChannel;
  Timer? _pollingTimer;
  DateTime? _lastUpdateTime;
  Map<String, dynamic>? _lastData;
  DateTime? _lastProcessedTimestamp;

  // Konstanta optimasi
  static const int MAX_HISTORY_LENGTH = 500;
  static const int SEQUENTIAL_BATCH_SIZE = 10;
  static const int POLLING_INTERVAL = 3; // seconds

  SensorRemoteDataSource() : _supabaseClient = Supabase.instance.client;

  // Method utama untuk real-time data dengan fallback ke data terbaru
  Stream<Map<String, dynamic>> getRealtimeData({int intervalSeconds = 3}) {
    _log('🔄 Starting realtime data polling every $intervalSeconds seconds');

    final controller = StreamController<Map<String, dynamic>>.broadcast();

    // Fetch data pertama kali
    _fetchDataWithFallback(controller);

    // Setup polling timer
    _pollingTimer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) {
      _fetchDataWithFallback(controller);
    });

    controller.onCancel = () {
      _log('🛑 Stopping realtime data polling');
      _pollingTimer?.cancel();
      _pollingTimer = null;
    };

    return controller.stream;
  }

  // Method dengan fallback: jika tidak ada data baru, ambil data terbaru
  void _fetchDataWithFallback(
    StreamController<Map<String, dynamic>> controller,
  ) async {
    try {
      _log('⏰ Polling at ${DateTime.now().toIso8601String()}');
      
      // Coba ambil data sequential terbaru
      final sequentialData = await _fetchLatestSequentialData();
      
      if (sequentialData != null && sequentialData['isNewData'] == true) {
        // Ada data baru
        _lastProcessedTimestamp = sequentialData['timestamp'] as DateTime;
        _lastData = sequentialData;
        
        if (!controller.isClosed) {
          controller.add(sequentialData);
          _log('🆕 New sequential data added to stream');
        }
      } else {
        // Tidak ada data baru, ambil data terbaru dari database
        _log('⏭️ No new data, fetching latest data from database');
        final latestData = await _fetchLatestDataFromDatabase();
        
        if (latestData != null) {
          _lastData = latestData;
          
          if (!controller.isClosed) {
            controller.add(latestData);
            _log('📋 Latest database data added to stream');
          }
        } else {
          _log('💤 No data available in database');
        }
      }
    } catch (e) {
      _log('❌ Error in polling: $e');
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // Method untuk mengambil data terbaru dari database (tanpa filter timestamp)
  Future<Map<String, dynamic>?> _fetchLatestDataFromDatabase() async {
    try {
      _log('📋 Fetching latest data from database...');
      
      // Query untuk ambil data sensor terbaru
      final sensorResponse = await http.get(
        Uri.parse('${AppConstants.supabaseUrl}/rest/v1/sensor_data?order=timestamp.desc&limit=1'),
        headers: _getHeaders(),
      );

      if (sensorResponse.statusCode == 200) {
        final List<dynamic> sensorDataList = json.decode(sensorResponse.body);

        if (sensorDataList.isNotEmpty) {
          final sensor = SensorDataModel.fromJson(sensorDataList.first);
          _log('📊 Latest sensor data: ${sensor.suhu}°C, ${sensor.kelembapan}% at ${sensor.timestamp}');

          // Ambil device status terbaru
          final deviceResponse = await http.get(
            Uri.parse('${AppConstants.supabaseUrl}/rest/v1/device_status?order=timestamp.desc&limit=1'),
            headers: _getHeaders(),
          );

          DeviceStatusModel device;
          if (deviceResponse.statusCode == 200) {
            final List<dynamic> deviceData = json.decode(deviceResponse.body);
            device = deviceData.isNotEmpty 
                ? DeviceStatusModel.fromJson(deviceData.first)
                : _createDefaultDeviceStatus(sensor);
          } else {
            device = _createDefaultDeviceStatus(sensor);
          }

          final result = {
            'sensor': sensor,
            'device': device,
            'timestamp': sensor.timestamp,
            'isNewData': false, // Mark as not new data
            'source': 'database_latest',
          };

          _log('✅ Latest database data fetched successfully');
          return result;
        } else {
          _log('💤 No data available in database');
          return null;
        }
      } else {
        throw Exception('HTTP Error: ${sensorResponse.statusCode}');
      }
    } catch (e) {
      _log('❌ Error fetching latest data: $e');
      return null;
    }
  }

  // Method untuk mengambil data sequential terbaru
  Future<Map<String, dynamic>?> _fetchLatestSequentialData() async {
    try {
      _log('🕒 Last processed timestamp: $_lastProcessedTimestamp');
      
      String query;
      
      if (_lastProcessedTimestamp != null) {
        // Untuk data sequential setelah timestamp terakhir
        final isoTime = _lastProcessedTimestamp!.toIso8601String();
        query = '${AppConstants.supabaseUrl}/rest/v1/sensor_data?timestamp=gt.$isoTime&order=timestamp.asc&limit=$SEQUENTIAL_BATCH_SIZE';
        _log('🔍 Query: sequential data after $isoTime');
      } else {
        // Untuk data pertama kali - ambil data terbaru
        query = '${AppConstants.supabaseUrl}/rest/v1/sensor_data?order=timestamp.desc&limit=1';
        _log('🔍 Query: initial data (latest record)');
      }

      final sensorResponse = await http.get(
        Uri.parse(query),
        headers: _getHeaders(),
      );

      if (sensorResponse.statusCode == 200) {
        final List<dynamic> sensorDataList = json.decode(sensorResponse.body);
        _log('📊 Found ${sensorDataList.length} sensor records');

        if (sensorDataList.isNotEmpty) {
          for (var data in sensorDataList) {
            _log('📝 Data: ${data['timestamp']} - Suhu: ${data['suhu']}°C, Kelembapan: ${data['kelembapan']}%');
          }
          
          // Ambil data yang sesuai
          final sensorJson = _lastProcessedTimestamp != null 
              ? sensorDataList.last // Untuk sequential, ambil yang terakhir
              : sensorDataList.first; // Untuk initial, ambil yang terbaru
              
          final sensor = SensorDataModel.fromJson(sensorJson);

          // Untuk data pertama kali, trigger automatic control
          if (_lastProcessedTimestamp == null && sensorDataList.isNotEmpty) {
            _log('🎯 First time data - triggering automatic control');
            await _triggerAutomaticControlOnNewData(sensor);
          } else if (_lastProcessedTimestamp != null) {
            // Untuk data sequential, trigger untuk setiap data baru
            for (final sensorJson in sensorDataList) {
              final sequentialSensor = SensorDataModel.fromJson(sensorJson);
              await _triggerAutomaticControlOnNewData(sequentialSensor);
            }
          }

          // Ambil device status terbaru
          final deviceResponse = await http.get(
            Uri.parse('${AppConstants.supabaseUrl}/rest/v1/device_status?order=timestamp.desc&limit=1'),
            headers: _getHeaders(),
          );

          DeviceStatusModel device;
          if (deviceResponse.statusCode == 200) {
            final List<dynamic> deviceData = json.decode(deviceResponse.body);
            device = deviceData.isNotEmpty 
                ? DeviceStatusModel.fromJson(deviceData.first)
                : _createDefaultDeviceStatus(sensor);
          } else {
            device = _createDefaultDeviceStatus(sensor);
          }

          final result = {
            'sensor': sensor,
            'device': device,
            'timestamp': sensor.timestamp,
            'isNewData': true,
            'sequentialCount': sensorDataList.length,
            'source': _lastProcessedTimestamp != null ? 'sequential' : 'initial',
          };

          _log('✅ Sequential data processed successfully');
          return result;
        } else {
          _log('⏭️ No new sequential data available');
          return null;
        }
      } else {
        throw Exception('HTTP Error: ${sensorResponse.statusCode}');
      }
    } catch (e) {
      _log('❌ Error in sequential data fetch: $e');
      return null;
    }
  }

  // Helper method untuk membuat device status default
  DeviceStatusModel _createDefaultDeviceStatus(SensorData sensor) {
    final control = AutomaticControl.kontrolOtomatis(
      sensor.suhu,
      sensor.kelembapan,
    );
    return DeviceStatusModel(
      id: 0,
      statusLampu: AutomaticControl.convertLampuToBoolean(control['lampu']!),
      jumlahLampu: AutomaticControl.getJumlahLampu(control['lampu']!),
      statusHumidifier: AutomaticControl.convertMistToBoolean(control['mist']!),
      targetKelembapan: 60.0,
      timestamp: sensor.timestamp,
    );
  }

  // Method untuk trigger kontrol otomatis ketika ada data sensor baru
  Future<void> _triggerAutomaticControlOnNewData(SensorData sensorData) async {
    try {
      _log('🔧 Triggering automatic control for new sensor data...');

      final control = AutomaticControl.kontrolOtomatis(
        sensorData.suhu,
        sensorData.kelembapan,
      );
      final lampuValue = control['lampu']!;
      final mistValue = control['mist']!;

      final statusLampu = AutomaticControl.convertLampuToBoolean(lampuValue);
      final statusHumidifier = AutomaticControl.convertMistToBoolean(mistValue);
      final jumlahLampu = AutomaticControl.getJumlahLampu(lampuValue);

      _log('🎛️ Automatic Control:');
      _log('   - Suhu: ${sensorData.suhu}°C, Kelembapan: ${sensorData.kelembapan}%');
      _log('   - Lampu: $lampuValue -> Status: $statusLampu, Jumlah: $jumlahLampu');
      _log('   - Mist: $mistValue -> Status: $statusHumidifier');

      // Kirim ke device_status
      final response = await http.post(
        Uri.parse('${AppConstants.supabaseUrl}/rest/v1/device_status'),
        headers: {
          'apikey': AppConstants.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: json.encode({
          'status_lampu': statusLampu,
          'jumlah_lampu': jumlahLampu,
          'status_humidifier': statusHumidifier,
          'target_kelembapan': 60.0,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _log('✅ Automatic control data SENT to device_status table');
      } else {
        _log('❌ Failed to send automatic control: ${response.statusCode}');
      }
    } catch (e) {
      _log('❌ Error triggering automatic control: $e');
    }
  }

  // Method untuk mengambil data sekali (untuk initial load)
  Future<Map<String, dynamic>> fetchInitialData() async {
    _log('🚀 Fetching initial data...');
    try {
      // Reset last processed timestamp untuk memastikan ambil data terbaru
      _lastProcessedTimestamp = null;
      
      final data = await _fetchLatestDataFromDatabase();
      
      if (data != null) {
        _lastData = data;
        _lastUpdateTime = DateTime.now();
        _log('✅ Initial data fetched successfully');
        return data;
      } else {
        _log('❌ No data available for initial load');
        throw Exception('No data available in database');
      }
    } catch (e) {
      _log('💥 Error fetching initial data: $e');
      rethrow;
    }
  }

  // Method untuk mendapatkan data historis
  Future<List<Map<String, dynamic>>> fetchHistoricalData({
    int limit = 100,
  }) async {
    try {
      _log('📚 Fetching historical data (limit: $limit)...');

      final sensorResponse = await http.get(
        Uri.parse('${AppConstants.supabaseUrl}/rest/v1/sensor_data?order=timestamp.asc&limit=$limit'),
        headers: _getHeaders(),
      );

      final deviceResponse = await http.get(
        Uri.parse('${AppConstants.supabaseUrl}/rest/v1/device_status?order=timestamp.asc&limit=$limit'),
        headers: _getHeaders(),
      );

      if (sensorResponse.statusCode == 200 && deviceResponse.statusCode == 200) {
        final List<dynamic> sensorData = json.decode(sensorResponse.body);
        final List<dynamic> deviceData = json.decode(deviceResponse.body);

        final List<Map<String, dynamic>> historicalData = [];

        // Gabungkan data berdasarkan timestamp terdekat
        for (int i = 0; i < sensorData.length; i++) {
          final sensor = SensorDataModel.fromJson(sensorData[i]);

          // Cari device status dengan timestamp terdekat (dalam 10 detik)
          DeviceStatusModel? closestDevice;
          Duration? closestTimeDiff;

          for (final deviceJson in deviceData) {
            final device = DeviceStatusModel.fromJson(deviceJson);
            final timeDiff = (sensor.timestamp.difference(device.timestamp)).abs();

            if (timeDiff.inSeconds <= 10) {
              if (closestTimeDiff == null || timeDiff < closestTimeDiff) {
                closestTimeDiff = timeDiff;
                closestDevice = device;
              }
            }
          }

          historicalData.add({
            'sensor': sensor,
            'device': closestDevice ?? _createDefaultDeviceStatus(sensor),
            'timestamp': sensor.timestamp,
          });
        }

        _log('✅ Historical data fetched: ${historicalData.length} items');
        return historicalData;
      } else {
        throw Exception('Failed to fetch historical data');
      }
    } catch (e) {
      _log('❌ Historical data error: $e');
      throw Exception('Historical data fetch error: $e');
    }
  }

  // Method untuk mengirim status perangkat berdasarkan kontrol otomatis
  Future<bool> sendAutomaticControl(double suhu, double kelembapan) async {
    try {
      final control = AutomaticControl.kontrolOtomatis(suhu, kelembapan);
      final lampuValue = control['lampu']!;
      final mistValue = control['mist']!;

      final statusLampu = AutomaticControl.convertLampuToBoolean(lampuValue);
      final statusHumidifier = AutomaticControl.convertMistToBoolean(mistValue);
      final jumlahLampu = AutomaticControl.getJumlahLampu(lampuValue);

      const double targetKelembapan = 60.0;

      _log('🎛️ Automatic Control Calculated:');
      _log('   - Suhu: $suhu°C, Kelembapan: $kelembapan%');

      final response = await http.post(
        Uri.parse('${AppConstants.supabaseUrl}/rest/v1/device_status'),
        headers: {
          'apikey': AppConstants.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: json.encode({
          'status_lampu': statusLampu,
          'jumlah_lampu': jumlahLampu,
          'status_humidifier': statusHumidifier,
          'target_kelembapan': targetKelembapan,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      final success = response.statusCode == 201 || response.statusCode == 200;

      if (success) {
        _log('✅ Automatic control sent successfully to Supabase');
      } else {
        _log('❌ Failed to send automatic control: ${response.statusCode}');
      }

      return success;
    } catch (e) {
      _log('❌ Error sending automatic control: $e');
      return false;
    }
  }

  // Method untuk mengirim perintah kontrol manual
  Future<bool> sendManualControl({
    bool? statusLampu,
    int? jumlahLampu,
    bool? statusHumidifier,
    double? targetKelembapan,
  }) async {
    try {
      final Map<String, dynamic> commandData = {
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (statusLampu != null) commandData['status_lampu'] = statusLampu;
      if (jumlahLampu != null) {
        commandData['jumlah_lampu'] = jumlahLampu;
      } else if (statusLampu != null && statusLampu) {
        commandData['jumlah_lampu'] = 1;
      } else {
        commandData['jumlah_lampu'] = 0;
      }
      if (statusHumidifier != null) commandData['status_humidifier'] = statusHumidifier;
      if (targetKelembapan != null) commandData['target_kelembapan'] = targetKelembapan;

      _log('🔄 Sending manual control command: $commandData');

      final response = await http.post(
        Uri.parse('${AppConstants.supabaseUrl}/rest/v1/device_status'),
        headers: {
          'apikey': AppConstants.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: json.encode(commandData),
      );

      _log('📊 Manual control response: ${response.statusCode}');

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      _log('❌ Error sending manual control: $e');
      return false;
    }
  }

  // Method untuk mengecek koneksi ke Supabase
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.supabaseUrl}/rest/v1/'),
        headers: {'apikey': AppConstants.supabaseAnonKey},
      );

      final isConnected = response.statusCode == 200;
      _log('🌐 Connection check: ${isConnected ? 'Connected' : 'Failed'}');
      return isConnected;
    } catch (e) {
      _log('❌ Connection check error: $e');
      return false;
    }
  }

  // Method untuk mendapatkan status polling
  Map<String, dynamic> getPollingStatus() {
    final status = {
      'polling_active': _pollingTimer != null && _pollingTimer!.isActive,
      'last_update_time': _lastUpdateTime?.toIso8601String(),
      'last_processed_timestamp': _lastProcessedTimestamp?.toIso8601String(),
      'polling_interval': '$POLLING_INTERVAL seconds',
      'data_count': _lastData != null ? 1 : 0,
      'sequential_batch_size': SEQUENTIAL_BATCH_SIZE,
    };

    _log('📡 Polling Status: $status');
    return status;
  }

  // Helper method untuk headers HTTP
  Map<String, String> _getHeaders() {
    return {
      'apikey': AppConstants.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
      'Content-Type': 'application/json',
    };
  }

  // Helper method untuk logging
  void _log(String message) {
    print('$runtimeType: $message');
  }

  void dispose() {
    _log('🛑 Disposing SensorRemoteDataSource...');

    _pollingTimer?.cancel();
    _pollingTimer = null;

    _sensorChannel?.unsubscribe();
    _deviceChannel?.unsubscribe();

    _supabaseClient.removeAllChannels();

    if (_controller != null && !_controller!.isClosed) {
      _controller!.close();
    }

    _controller = null;
    _sensorChannel = null;
    _deviceChannel = null;
    _lastData = null;
    _lastUpdateTime = null;
    _lastProcessedTimestamp = null;

    _log('✅ SensorRemoteDataSource disposed');
  }
}