class SensorData {
  final int id;
  final double suhu;
  final double kelembapan;
  final DateTime timestamp;

  const SensorData({
    required this.id,
    required this.suhu,
    required this.kelembapan,
    required this.timestamp,
  });

  SensorData copyWith({
    int? id,
    double? suhu,
    double? kelembapan,
    DateTime? timestamp,
  }) {
    return SensorData(
      id: id ?? this.id,
      suhu: suhu ?? this.suhu,
      kelembapan: kelembapan ?? this.kelembapan,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is SensorData &&
        other.id == id &&
        other.suhu == suhu &&
        other.kelembapan == kelembapan &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        suhu.hashCode ^
        kelembapan.hashCode ^
        timestamp.hashCode;
  }
}