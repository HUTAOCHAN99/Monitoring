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

  SensorRemoteDataSource() : _supabaseClient = Supabase.instance.client;

  // Method utama untuk mengambil data terbaru dengan polling 3 detik
  Stream<Map<String, dynamic>> getRealtimeData({int intervalSeconds = 3}) {
    _log('🔄 Starting realtime data polling every $intervalSeconds seconds');

    final controller = StreamController<Map<String, dynamic>>.broadcast();

    // Fetch data pertama kali
    _fetchLatestDataWithPolling(controller);

    // Setup polling timer setiap 3 detik
    _pollingTimer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) {
      _fetchLatestDataWithPolling(controller);
    });

    // Cleanup ketika stream di-cancel
    controller.onCancel = () {
      _log('🛑 Stopping realtime data polling');
      _pollingTimer?.cancel();
      _pollingTimer = null;
    };

    return controller.stream;
  }

  // Method untuk fetch data dengan polling
  void _fetchLatestDataWithPolling(
    StreamController<Map<String, dynamic>> controller,
  ) async {
    try {
      _log('⏰ Polling data at ${DateTime.now().toIso8601String()}');

      final data = await _fetchLatestDataFromSupabase();

      // Cek apakah data benar-benar baru
      if (_isNewData(data)) {
        _log('🆕 New data detected, updating stream...');
        _lastData = data;
        _lastUpdateTime = DateTime.now();

        if (!controller.isClosed) {
          controller.add(data);
        }
      } else {
        _log('⏭️ No new data, skipping update');
      }
    } catch (e) {
      _log('❌ Error in polling: $e');
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // Method untuk mengambil data terbaru dari Supabase
  Future<Map<String, dynamic>> _fetchLatestDataFromSupabase() async {
    try {
      _log('📡 Fetching latest data from Supabase...');

      // Ambil data sensor terbaru
      final sensorResponse = await http.get(
        Uri.parse(
          '${AppConstants.supabaseUrl}/rest/v1/sensor_data?order=timestamp.desc&limit=1',
        ),
        headers: _getHeaders(),
      );

      if (sensorResponse.statusCode == 200) {
        final List<dynamic> sensorData = json.decode(sensorResponse.body);

        if (sensorData.isNotEmpty) {
          final sensor = SensorDataModel.fromJson(sensorData.first);

          // ⚡ TRIGGER AUTOMATIC CONTROL SETIAP ADA DATA SENSOR BARU - PASTIKAN INI DIPANGGIL
          await _triggerAutomaticControlOnNewData(sensor);

          // Ambil status device terbaru SETELAH trigger automatic control
          final deviceResponse = await http.get(
            Uri.parse(
              '${AppConstants.supabaseUrl}/rest/v1/device_status?order=timestamp.desc&limit=1',
            ),
            headers: _getHeaders(),
          );

          _log('📊 Sensor Status: ${sensorResponse.statusCode}');
          _log('📊 Device Status: ${deviceResponse.statusCode}');

          DeviceStatusModel device;
          if (deviceResponse.statusCode == 200) {
            final List<dynamic> deviceData = json.decode(deviceResponse.body);

            if (deviceData.isNotEmpty) {
              device = DeviceStatusModel.fromJson(deviceData.first);
              _log('📈 Device items found: ${deviceData.length}');
            } else {
              // Buat device status default jika tidak ada data
              final control = AutomaticControl.kontrolOtomatis(
                sensor.suhu,
                sensor.kelembapan,
              );
              device = DeviceStatusModel(
                id: 0,
                statusLampu: AutomaticControl.convertLampuToBoolean(
                  control['lampu']!,
                ),
                jumlahLampu: AutomaticControl.getJumlahLampu(control['lampu']!),
                statusHumidifier: AutomaticControl.convertMistToBoolean(
                  control['mist']!,
                ),
                targetKelembapan: 60.0,
                timestamp: sensor.timestamp,
              );
              _log('⚠️ No device data, using default control');
            }
          } else {
            // Fallback jika device response gagal
            final control = AutomaticControl.kontrolOtomatis(
              sensor.suhu,
              sensor.kelembapan,
            );
            device = DeviceStatusModel(
              id: 0,
              statusLampu: AutomaticControl.convertLampuToBoolean(
                control['lampu']!,
              ),
              jumlahLampu: AutomaticControl.getJumlahLampu(control['lampu']!),
              statusHumidifier: AutomaticControl.convertMistToBoolean(
                control['mist']!,
              ),
              targetKelembapan: 60.0,
              timestamp: sensor.timestamp,
            );
            _log('⚠️ Device response failed, using default control');
          }

          final result = {
            'sensor': sensor,
            'device': device,
            'timestamp': DateTime.now(),
            'isNewData': true,
          };

          _log('✅ Data fetched successfully:');
          _log(
            '   - Sensor: ${sensor.suhu}°C, ${sensor.kelembapan}% at ${sensor.timestamp}',
          );
          _log(
            '   - Device: Lampu=${device.statusLampu}, Jumlah Lampu=${device.jumlahLampu}, Humidifier=${device.statusHumidifier} at ${device.timestamp}',
          );

          return result;
        } else {
          _log('❌ No sensor data available');
          throw Exception('No sensor data available');
        }
      } else {
        final errorMsg = 'HTTP Error: Sensor=${sensorResponse.statusCode}';
        _log('❌ $errorMsg');
        _log('Sensor Error: ${sensorResponse.body}');

        throw Exception(errorMsg);
      }
    } catch (e) {
      _log('❌ Fetch error: $e');
      throw Exception('Fetch error: $e');
    }
  }

  // Method untuk trigger kontrol otomatis ketika ada data sensor baru - VERSION FIXED
  Future<void> _triggerAutomaticControlOnNewData(SensorData sensorData) async {
    try {
      _log('🔧 Triggering automatic control for new sensor data...');

      // HITUNG kontrol otomatis berdasarkan data sensor baru
      final control = AutomaticControl.kontrolOtomatis(
        sensorData.suhu,
        sensorData.kelembapan,
      );
      final lampuValue = control['lampu']!;
      final mistValue = control['mist']!;

      // Konversi ke boolean untuk database
      final statusLampu = AutomaticControl.convertLampuToBoolean(lampuValue);
      final statusHumidifier = AutomaticControl.convertMistToBoolean(mistValue);
      final jumlahLampu = AutomaticControl.getJumlahLampu(lampuValue);

      _log('🎛️ Automatic Control Calculated from new sensor data:');
      _log(
        '   - Suhu: ${sensorData.suhu}°C, Kelembapan: ${sensorData.kelembapan}%',
      );
      _log(
        '   - Lampu: $lampuValue -> Status: $statusLampu, Jumlah: $jumlahLampu',
      );
      _log('   - Mist: $mistValue -> Status: $statusHumidifier');

      // KIRIM langsung ke device_status
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
          'target_kelembapan': 60.0, // Default value
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _log('✅ Automatic control data SENT to device_status table');
      } else {
        _log('❌ Failed to send automatic control: ${response.statusCode}');
        _log('Error response: ${response.body}');
      }
    } catch (e) {
      _log('❌ Error triggering automatic control: $e');
    }
  }

  // Method untuk mengecek apakah data benar-benar baru
  bool _isNewData(Map<String, dynamic> newData) {
    if (_lastData == null) {
      return true; // Data pertama selalu dianggap baru
    }

    final SensorData newSensor = newData['sensor'];
    final DeviceStatus newDevice = newData['device'];
    final SensorData lastSensor = _lastData!['sensor'];
    final DeviceStatus lastDevice = _lastData!['device'];

    // Bandingkan timestamp untuk melihat apakah data berubah
    final bool sensorChanged = newSensor.timestamp != lastSensor.timestamp;
    final bool deviceChanged = newDevice.timestamp != lastDevice.timestamp;
    final bool valuesChanged =
        newSensor.suhu != lastSensor.suhu ||
        newSensor.kelembapan != lastSensor.kelembapan ||
        newDevice.statusLampu != lastDevice.statusLampu ||
        newDevice.jumlahLampu != lastDevice.jumlahLampu ||
        newDevice.statusHumidifier != lastDevice.statusHumidifier ||
        newDevice.targetKelembapan != lastDevice.targetKelembapan;

    final bool isNew = sensorChanged || deviceChanged || valuesChanged;

    if (isNew) {
      _log('🆕 Data changed detected:');
      if (sensorChanged) _log('   - Sensor timestamp changed');
      if (deviceChanged) _log('   - Device timestamp changed');
      if (valuesChanged) _log('   - Values changed');
    }

    return isNew;
  }

  // Method untuk mendapatkan headers HTTP
  Map<String, String> _getHeaders() {
    return {
      'apikey': AppConstants.supabaseAnonKey,
      'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
      'Content-Type': 'application/json',
    };
  }

  // Method untuk mengambil data sekali (untuk initial load)
  Future<Map<String, dynamic>> fetchInitialData() async {
    _log('🚀 Fetching initial data...');
    final data = await _fetchLatestDataFromSupabase();
    _lastData = data;
    _lastUpdateTime = DateTime.now();
    return data;
  }

  // Method untuk mendapatkan data historis (opsional)
  Future<List<Map<String, dynamic>>> fetchHistoricalData({
    int limit = 20,
  }) async {
    try {
      _log('📚 Fetching historical data (limit: $limit)...');

      final sensorResponse = await http.get(
        Uri.parse(
          '${AppConstants.supabaseUrl}/rest/v1/sensor_data?order=timestamp.desc&limit=$limit',
        ),
        headers: _getHeaders(),
      );

      final deviceResponse = await http.get(
        Uri.parse(
          '${AppConstants.supabaseUrl}/rest/v1/device_status?order=timestamp.desc&limit=$limit',
        ),
        headers: _getHeaders(),
      );

      if (sensorResponse.statusCode == 200 &&
          deviceResponse.statusCode == 200) {
        final List<dynamic> sensorData = json.decode(sensorResponse.body);
        final List<dynamic> deviceData = json.decode(deviceResponse.body);

        final List<Map<String, dynamic>> historicalData = [];

        // Gabungkan data berdasarkan timestamp terdekat
        for (int i = 0; i < sensorData.length; i++) {
          final sensor = SensorDataModel.fromJson(sensorData[i]);

          // Cari device status dengan timestamp terdekat
          DeviceStatusModel? closestDevice;
          Duration? closestTimeDiff;

          for (final deviceJson in deviceData) {
            final device = DeviceStatusModel.fromJson(deviceJson);
            final timeDiff = (sensor.timestamp.difference(
              device.timestamp,
            )).abs();

            if (closestTimeDiff == null || timeDiff < closestTimeDiff) {
              closestTimeDiff = timeDiff;
              closestDevice = device;
            }
          }

          historicalData.add({
            'sensor': sensor,
            'device':
                closestDevice ??
                DeviceStatusModel(
                  id: 0,
                  statusLampu: false,
                  jumlahLampu: 0,
                  statusHumidifier: false,
                  targetKelembapan: 60.0,
                  timestamp: sensor.timestamp,
                ),
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
      // Hitung kontrol otomatis
      final control = AutomaticControl.kontrolOtomatis(suhu, kelembapan);
      final lampuValue = control['lampu']!;
      final mistValue = control['mist']!;

      // Konversi ke boolean untuk database
      final statusLampu = AutomaticControl.convertLampuToBoolean(lampuValue);
      final statusHumidifier = AutomaticControl.convertMistToBoolean(mistValue);
      final jumlahLampu = AutomaticControl.getJumlahLampu(lampuValue);

      // Default target kelembapan
      const double targetKelembapan = 60.0;

      _log('🎛️ Automatic Control Calculated:');
      _log('   - Suhu: $suhu°C, Kelembapan: $kelembapan%');
      _log(
        '   - Lampu: $lampuValue (${AutomaticControl.getStatusDescription(lampuValue, mistValue)['lampu']})',
      );
      _log(
        '   - Mist: $mistValue (${AutomaticControl.getStatusDescription(lampuValue, mistValue)['mist']})',
      );
      _log('   - Status Lampu (DB): $statusLampu');
      _log('   - Jumlah Lampu: $jumlahLampu');
      _log('   - Status Humidifier (DB): $statusHumidifier');

      // Kirim ke Supabase
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
        _log('Error response: ${response.body}');
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
        // Jika statusLampu true tapi jumlahLampu tidak diset, default ke 1
        commandData['jumlah_lampu'] = 1;
      } else {
        commandData['jumlah_lampu'] = 0;
      }
      if (statusHumidifier != null)
        commandData['status_humidifier'] = statusHumidifier;
      if (targetKelembapan != null)
        commandData['target_kelembapan'] = targetKelembapan;

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
      'polling_interval': '3 seconds',
      'data_count': _lastData != null ? 1 : 0,
    };

    _log('📡 Polling Status: $status');
    return status;
  }

  // Helper method untuk logging
  void _log(String message) {
    // Untuk sementara tetap pakai print, bisa diganti dengan logger nanti
    print(message);
  }

  void dispose() {
    _log('🛑 Disposing SensorRemoteDataSource...');

    // Cancel polling timer
    _pollingTimer?.cancel();
    _pollingTimer = null;

    // Unsubscribe dari realtime channels
    _sensorChannel?.unsubscribe();
    _deviceChannel?.unsubscribe();

    // Remove semua channels
    _supabaseClient.removeAllChannels();

    // Close controller
    if (_controller != null && !_controller!.isClosed) {
      _controller!.close();
    }

    _controller = null;
    _sensorChannel = null;
    _deviceChannel = null;
    _lastData = null;
    _lastUpdateTime = null;

    _log('✅ SensorRemoteDataSource disposed');
  }

  // Method untuk trigger scheduled control manually
  Future<bool> triggerScheduledControl() async {
    try {
      final response = await http.post(
        Uri.parse(
          '${AppConstants.supabaseUrl}/rest/v1/rpc/manual_trigger_control',
        ),
        headers: {
          'apikey': AppConstants.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
        body: json.encode({}),
      );

      return response.statusCode == 200;
    } catch (e) {
      _log('❌ Error triggering scheduled control: $e');
      return false;
    }
  }

  // Method untuk get system status
  Future<Map<String, dynamic>> getControlSystemStatus() async {
    try {
      final response = await http.post(
        Uri.parse(
          '${AppConstants.supabaseUrl}/rest/v1/rpc/get_control_system_status',
        ),
        headers: {
          'apikey': AppConstants.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      return {'system_status': 'UNKNOWN'};
    } catch (e) {
      _log('❌ Error getting system status: $e');
      return {'system_status': 'ERROR', 'error': e.toString()};
    }
  }
}
