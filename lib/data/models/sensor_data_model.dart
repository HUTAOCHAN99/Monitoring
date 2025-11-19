import '../../domain/entities/sensor_data.dart';

class SensorDataModel extends SensorData {
  const SensorDataModel({
    required super.id,
    required super.suhu,
    required super.kelembapan,
    required super.timestamp,
  });

  factory SensorDataModel.fromJson(Map<String, dynamic> json) {
    return SensorDataModel(
      id: json['id'] as int,
      suhu: (json['suhu'] as num).toDouble(),
      kelembapan: (json['kelembapan'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'suhu': suhu,
      'kelembapan': kelembapan,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}