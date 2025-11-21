import 'package:flutter/material.dart';
import '../../domain/entities/sensor_data.dart';
import '../../domain/entities/device_status.dart';
import '../../core/utils/date_formatter.dart';

class SensorCard extends StatelessWidget {
  final SensorData sensorData;
  final DeviceStatus deviceStatus;

  const SensorCard({
    super.key,
    required this.sensorData,
    required this.deviceStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header dengan status sistem
            _buildHeader(),
            const SizedBox(height: 20),
            
            // Data Sensor
            _buildInfoRow(
              icon: Icons.thermostat,
              label: 'Suhu',
              value: '${sensorData.suhu.toStringAsFixed(1)}°C',
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow(
              icon: Icons.water_drop,
              label: 'Kelembapan',
              value: '${sensorData.kelembapan.toStringAsFixed(1)}%',
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            
            // Target Kelembapan
            _buildInfoRow(
              icon: Icons.flag,
              label: 'Target Kelembapan',
              value: '${deviceStatus.targetKelembapan.toStringAsFixed(1)}%',
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            
            // Status Lampu - DIUBAH untuk 2 lampu
            _buildLightInfo(),
            const SizedBox(height: 16),
            
            // Status Humidifier
            _buildHumidifierInfo(),
            const SizedBox(height: 16),
            
            // Waktu Update
            _buildInfoRow(
              icon: Icons.access_time,
              label: 'Terakhir Update',
              value: DateFormatter.formatFullDate(sensorData.timestamp.toIso8601String()),
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'Monitoring Inkubator IoT',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: deviceStatus.getSystemStatusColor(sensorData.kelembapan).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: deviceStatus.getSystemStatusColor(sensorData.kelembapan)),
          ),
          child: Text(
            deviceStatus.getSystemStatus(sensorData.kelembapan),
            style: TextStyle(
              color: deviceStatus.getSystemStatusColor(sensorData.kelembapan),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLightInfo() {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.lightbulb,
              color: deviceStatus.lightStatusColor,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lampu Pemanas',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        // DIUBAH: Menampilkan status dengan maksimal 2 lampu
                        deviceStatus.lightStatusText,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: deviceStatus.lightStatusColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: deviceStatus.lightStatusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: deviceStatus.lightStatusColor),
                        ),
                        child: Text(
                          deviceStatus.statusLampu ? 'ON' : 'OFF',
                          style: TextStyle(
                            fontSize: 10,
                            color: deviceStatus.lightStatusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        // DIUBAH: Menampilkan indikator progress lampu untuk 2 lampu
        if (deviceStatus.statusLampu) ...[
          const SizedBox(height: 12),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Intensitas Pemanasan:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${deviceStatus.jumlahLampu}/2 lampu',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: deviceStatus.lightStatusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: deviceStatus.lightIntensity, // 0, 0.5, atau 1.0
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  deviceStatus.lightStatusColor,
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rendah',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Tinggi',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHumidifierInfo() {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.air,
              color: deviceStatus.humidifierStatusColor,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Humidifier',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        deviceStatus.humidifierStatusText,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: deviceStatus.humidifierStatusColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: deviceStatus.getHumidifierEfficiencyColor(sensorData.kelembapan).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: deviceStatus.getHumidifierEfficiencyColor(sensorData.kelembapan)),
                        ),
                        child: Text(
                          deviceStatus.getHumidifierEfficiency(sensorData.kelembapan),
                          style: TextStyle(
                            fontSize: 10,
                            color: deviceStatus.getHumidifierEfficiencyColor(sensorData.kelembapan),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress menuju target
        _buildHumidityProgress(),
      ],
    );
  }

  Widget _buildHumidityProgress() {
    final difference = deviceStatus.targetKelembapan - sensorData.kelembapan;
    final progress = sensorData.kelembapan / deviceStatus.targetKelembapan;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress menuju target:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '${(progress * 100).clamp(0, 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: deviceStatus.getHumidifierEfficiencyColor(sensorData.kelembapan),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress.clamp(0, 1),
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            deviceStatus.getHumidifierEfficiencyColor(sensorData.kelembapan),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Selisih: ${difference.abs().toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}