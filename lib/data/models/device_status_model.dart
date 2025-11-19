import '../../domain/entities/device_status.dart';

class DeviceStatusModel extends DeviceStatus {
  const DeviceStatusModel({
    required super.id,
    required super.statusLampu,
    required super.jumlahLampu,
    required super.statusHumidifier,
    required super.targetKelembapan,
    required super.timestamp,
  });

  factory DeviceStatusModel.fromJson(Map<String, dynamic> json) {
    return DeviceStatusModel(
      id: json['id'] as int,
      statusLampu: json['status_lampu'] as bool,
      jumlahLampu: (json['jumlah_lampu'] as num?)?.toInt() ?? 0,
      statusHumidifier: json['status_humidifier'] as bool,
      targetKelembapan: (json['target_kelembapan'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status_lampu': statusLampu,
      'jumlah_lampu': jumlahLampu,
      'status_humidifier': statusHumidifier,
      'target_kelembapan': targetKelembapan,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}