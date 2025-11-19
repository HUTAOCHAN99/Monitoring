import 'package:flutter/material.dart';
import 'package:monitoring/core/widgets/loading_widget.dart';
import 'package:monitoring/core/widgets/error_widget.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_provider.dart';
import '../widgets/sensor_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (!_isInitialized) {
      _isInitialized = true;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<SensorProvider>();
        provider.initialize();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Inkubator IoT'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          Consumer<SensorProvider>(
            builder: (context, sensorProvider, child) {
              if (sensorProvider.hasError || !sensorProvider.isConnected) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: sensorProvider.retry,
                  tooltip: 'Refresh Connection',
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: Consumer<SensorProvider>(
        builder: (context, sensorProvider, child) {
          // Loading State
          if (sensorProvider.isLoading) {
            return _buildLoadingState(sensorProvider);
          }

          // Error State
          if (sensorProvider.hasError) {
            return CustomErrorWidget(
              message: sensorProvider.error!,
              onRetry: sensorProvider.retry,
            );
          }

          // No Data State (connected but no data received)
          if (!sensorProvider.hasData) {
            return _buildNoDataState(sensorProvider);
          }

          // Data Available State
          return _buildDataState(sensorProvider);
        },
      ),
    );
  }

  Widget _buildLoadingState(SensorProvider provider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const LoadingWidget(message: 'Menghubungkan ke server...'),
        const SizedBox(height: 20),
        _buildConnectionInfo('🔄 Menunggu koneksi real-time...', Colors.orange),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Pastikan:\n• Aplikasi perangkat sedang mengirim data\n• Koneksi internet stabil\n• Database Supabase tersedia',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoDataState(SensorProvider provider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.wifi_tethering_off_rounded,
          size: 64,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 16),
        const Text(
          'Tidak Ada Data',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Menunggu data dari perangkat IoT...',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        _buildConnectionInfo('📡 Connected - Waiting for data', Colors.blue),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          onPressed: provider.retry,
        ),
      ],
    );
  }

  Widget _buildDataState(SensorProvider provider) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SensorCard(
            sensorData: provider.latestSensorData!,
            deviceStatus: provider.latestDeviceStatus!,
          ),
          _buildControlInfo(provider),
          _buildConnectionInfo('✅ Terhubung Real-time', Colors.green),
          _buildLastUpdateTime(provider.latestSensorData!.timestamp),
          _buildHistoryInfo(provider.dataHistory.length),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildControlInfo(SensorProvider provider) {
    final sensorData = provider.latestSensorData!;
    final deviceStatus = provider.latestDeviceStatus!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: deviceStatus.getControlInfoColor(sensorData.kelembapan, sensorData.suhu).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: deviceStatus.getControlInfoColor(sensorData.kelembapan, sensorData.suhu),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.smart_toy,
            color: deviceStatus.getControlInfoColor(sensorData.kelembapan, sensorData.suhu),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Logika Kontrol Otomatis:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deviceStatus.getControlInfo(sensorData.kelembapan, sensorData.suhu),
                  style: TextStyle(
                    fontSize: 12,
                    color: deviceStatus.getControlInfoColor(sensorData.kelembapan, sensorData.suhu),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionInfo(String message, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdateTime(DateTime timestamp) {
    final timeString = '${timestamp.hour.toString().padLeft(2, '0')}:'
                       '${timestamp.minute.toString().padLeft(2, '0')}:'
                       '${timestamp.second.toString().padLeft(2, '0')}';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'Update: $timeString',
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildHistoryInfo(int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'Data diterima: $count',
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}