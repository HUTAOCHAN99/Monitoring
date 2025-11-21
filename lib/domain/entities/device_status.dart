import 'package:flutter/material.dart';

class DeviceStatus {
  final int id;
  final bool statusLampu;
  final int jumlahLampu; 
  final bool statusHumidifier;
  final double targetKelembapan;
  final DateTime timestamp;

  const DeviceStatus({
    required this.id,
    required this.statusLampu,
    required this.jumlahLampu, 
    required this.statusHumidifier,
    required this.targetKelembapan,
    required this.timestamp,
  });

  DeviceStatus copyWith({
    int? id,
    bool? statusLampu,
    int? jumlahLampu,
    bool? statusHumidifier,
    double? targetKelembapan,
    DateTime? timestamp,
  }) {
    return DeviceStatus(
      id: id ?? this.id,
      statusLampu: statusLampu ?? this.statusLampu,
      jumlahLampu: jumlahLampu ?? this.jumlahLampu, 
      statusHumidifier: statusHumidifier ?? this.statusHumidifier,
      targetKelembapan: targetKelembapan ?? this.targetKelembapan,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  // Helper methods
  String get lightStatusText => statusLampu ? 'MENYALA ($jumlahLampu/2 lampu)' : 'MATI';
  String get humidifierStatusText => statusHumidifier ? 'AKTIF' : 'MATI';
  
  Color get lightStatusColor => statusLampu ? Colors.amber : Colors.grey;
  Color get humidifierStatusColor => statusHumidifier ? Colors.blue : Colors.grey;

  // Method untuk mendapatkan deskripsi jumlah lampu - DIUBAH
  String get jumlahLampuDescription {
    switch (jumlahLampu) {
      case 0:
        return 'Mati';
      case 1:
        return '1 Lampu Menyala (Rendah)';
      case 2:
        return '2 Lampu Menyala (Tinggi)'; // Maksimal 2
      default:
        return '$jumlahLampu Lampu Menyala';
    }
  }

  // Method untuk mendapatkan intensitas lampu dalam persentase
  double get lightIntensity {
    return jumlahLampu / 2; // 0, 0.5, atau 1.0
  }

  // Method untuk menghitung status humidifier
  String getHumidifierEfficiency(double currentHumidity) {
    final difference = targetKelembapan - currentHumidity;
    if (statusHumidifier) {
      if (difference > 5.0) return 'Meningkatkan Signifikan';
      if (difference > 2.0) return 'Meningkatkan Perlahan';
      return 'Hampir Mencapai Target';
    } else {
      if (currentHumidity >= targetKelembapan) return 'Target Tercapai';
      if (difference <= 2.0) return 'Dalam Toleransi';
      return 'Menunggu Aktivasi';
    }
  }

  Color getHumidifierEfficiencyColor(double currentHumidity) {
    final difference = targetKelembapan - currentHumidity;
    if (statusHumidifier) {
      if (difference > 5.0) return Colors.blue;
      if (difference > 2.0) return Colors.blue[700]!;
      return Colors.green;
    } else {
      if (currentHumidity >= targetKelembapan) return Colors.green;
      if (difference <= 2.0) return Colors.orange;
      return Colors.grey;
    }
  }

  // Status overall sistem
  String getSystemStatus(double currentHumidity) {
    if (statusHumidifier) {
      final difference = targetKelembapan - currentHumidity;
      if (difference > 5.0) return 'MENINGKATKAN KELEMBAPAN';
      if (difference > 2.0) return 'STABILISASI KELEMBAPAN';
      return 'OPTIMAL - HAMPIR TARGET';
    } else {
      if (currentHumidity >= targetKelembapan) return 'KONDISI OPTIMAL';
      return 'STANDBY - MONITORING';
    }
  }

  Color getSystemStatusColor(double currentHumidity) {
    if (statusHumidifier) {
      final difference = targetKelembapan - currentHumidity;
      if (difference > 5.0) return Colors.blue;
      if (difference > 2.0) return Colors.blue[700]!;
      return Colors.green;
    } else {
      if (currentHumidity >= targetKelembapan) return Colors.green;
      return Colors.orange;
    }
  }

  // Method untuk mendapatkan informasi kontrol - DIUBAH untuk 2 lampu
  String getControlInfo(double currentHumidity, double currentTemperature) {
    if (currentHumidity < 50) {
      if (currentTemperature < 35) {
        return 'Kontrol: $jumlahLampu/2 Lampu=ON, Humidifier=ON\n(Suhu <35°C & Kelembapan <50%)';
      } else {
        return 'Kontrol: Humidifier=ON\n(Kelembapan <50%)';
      }
    } else if (currentHumidity <= 65) {
      if (currentTemperature < 35) {
        return 'Kontrol: $jumlahLampu/2 Lampu=ON\n(Suhu <35°C)';
      } else if (currentTemperature <= 40) {
        return 'Kontrol: $jumlahLampu/2 Lampu=ON\n(Suhu 35-40°C)';
      } else {
        return 'Kontrol: Lampu=OFF\n(Kondisi optimal)';
      }
    } else {
      if (currentTemperature < 35) {
        return 'Kontrol: $jumlahLampu/2 Lampu=ON\n(Suhu <35°C & Kelembapan >65%)';
      } else {
        return 'Kontrol: Lampu=OFF, Humidifier=OFF\n(Kondisi optimal)';
      }
    }
  }

  Color getControlInfoColor(double currentHumidity, double currentTemperature) {
    if (currentHumidity < 50) {
      if (currentTemperature < 35) return Colors.orange;
      return Colors.blue;
    } else if (currentHumidity <= 65) {
      if (currentTemperature < 35) return Colors.orange;
      if (currentTemperature <= 40) return Colors.amber;
      return Colors.green;
    } else {
      if (currentTemperature < 35) return Colors.orange;
      return Colors.green;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is DeviceStatus &&
        other.id == id &&
        other.statusLampu == statusLampu &&
        other.jumlahLampu == jumlahLampu &&
        other.statusHumidifier == statusHumidifier &&
        other.targetKelembapan == targetKelembapan &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        statusLampu.hashCode ^
        jumlahLampu.hashCode ^
        statusHumidifier.hashCode ^
        targetKelembapan.hashCode ^
        timestamp.hashCode;
  }
}