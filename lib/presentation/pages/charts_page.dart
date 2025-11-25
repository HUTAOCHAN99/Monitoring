import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../providers/sensor_provider.dart';
import '../../domain/entities/sensor_data.dart';

class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  List<ChartData> _temperatureData = [];
  List<ChartData> _humidityData = [];
  bool _isLoading = true;
  late ZoomPanBehavior _zoomPanBehavior;

  @override
  void initState() {
    super.initState();
    _initializeZoomPanBehavior();
    _loadChartData();
  }

  void _initializeZoomPanBehavior() {
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      enableSelectionZooming: true,
      zoomMode: ZoomMode.x,
      selectionRectBorderColor: Colors.red,
      selectionRectColor: Color.alphaBlend(Colors.red.withOpacity(0.2), Colors.transparent),
    );
  }

  void _loadChartData() {
    final provider = Provider.of<SensorProvider>(context, listen: false);
    
    print('📊 Loading chart data...');
    
    // Cek jika masih loading data historis
    if (provider.isLoadingHistory) {
      print('⏳ Waiting for historical data to load...');
      // Tunggu sebentar lalu coba lagi
      Future.delayed(const Duration(seconds: 1), () {
        _loadChartData();
      });
      return;
    }
    
    print('📊 Total data history: ${provider.dataHistory.length}');
    
    // Konversi data history ke format chart - AMBIL SEMUA DATA
    _temperatureData = provider.dataHistory.map((data) {
      final sensor = data['sensor'] as SensorData;
      return ChartData(
        time: sensor.timestamp,
        value: sensor.suhu,
        label: '${_formatTemperature(sensor.suhu)}°C',
        type: 'Suhu',
      );
    }).toList();

    _humidityData = provider.dataHistory.map((data) {
      final sensor = data['sensor'] as SensorData;
      return ChartData(
        time: sensor.timestamp,
        value: sensor.kelembapan,
        label: '${_formatHumidity(sensor.kelembapan)}%',
        type: 'Kelembapan',
      );
    }).toList();

    // Urutkan data berdasarkan waktu (dari terlama ke terbaru)
    _temperatureData.sort((a, b) => a.time.compareTo(b.time));
    _humidityData.sort((a, b) => a.time.compareTo(b.time));

    // Debug: Print informasi data
    if (_temperatureData.isNotEmpty) {
      print('📊 Data range (All data):');
      print('   Oldest: ${_temperatureData.first.time} - ${_temperatureData.first.value}°C');
      print('   Latest: ${_temperatureData.last.time} - ${_temperatureData.last.value}°C');
      print('   Total points: ${_temperatureData.length}');
      
      // Cek rentang waktu
      final difference = _temperatureData.last.time.difference(_temperatureData.first.time);
      print('   Time range: ${difference.inHours} hours ${difference.inMinutes.remainder(60)} minutes');
      
      // Hitung berapa lama data tersimpan
      final now = DateTime.now();
      final dataAge = now.difference(_temperatureData.first.time);
      print('   Data age: ${dataAge.inHours} hours ${dataAge.inMinutes.remainder(60)} minutes');
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Method untuk format suhu - hilangkan .00
  String _formatTemperature(double temperature) {
    if (temperature % 1 == 0) {
      return temperature.toInt().toString(); // 36.0 -> "36"
    } else {
      return temperature.toStringAsFixed(1); // 36.5 -> "36.5"
    }
  }

  // Method untuk format kelembapan - hilangkan .00
  String _formatHumidity(double humidity) {
    if (humidity % 1 == 0) {
      return humidity.toInt().toString(); // 63.0 -> "63"
    } else {
      return humidity.toStringAsFixed(1); // 63.5 -> "63.5"
    }
  }

  void _resetZoom() {
    _zoomPanBehavior.reset();
    setState(() {});
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    
    final provider = Provider.of<SensorProvider>(context, listen: false);
    
    print('🔄 Refreshing historical data...');
    await provider.refreshHistoricalData();
    
    _loadChartData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grafik Monitoring'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            onPressed: _resetZoom,
            tooltip: 'Reset Zoom',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data Historis',
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: _isLoading
            ? _buildLoadingState()
            : _buildChartContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Consumer<SensorProvider>(
              builder: (context, provider, child) {
                if (provider.isLoadingHistory) {
                  return Column(
                    children: [
                      const Text(
                        'Memuat data historis...',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mengambil semua data dari database',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  );
                } else {
                  return const Text('Mempersiapkan grafik...');
                }
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text('Refresh Data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContent() {
    if (_temperatureData.isEmpty || _humidityData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Belum ada data untuk ditampilkan',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const Text(
                'Data akan muncul setelah perangkat mengirim data',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Data'),
                onPressed: _refreshData,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // GRAFIK GABUNGAN SUHU DAN KELEMBAPAN
        Expanded(
          child: _buildCombinedChart(),
        ),
        
        // PANEL INFORMASI DAN KONTROL
        _buildBottomPanel(),
      ],
    );
  }

  Widget _buildCombinedChart() {
    // Tentukan rentang sumbu X berdasarkan data
    final oldestTime = _temperatureData.first.time;
    final latestTime = _temperatureData.last.time;
    
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header dengan informasi waktu
            _buildChartHeader(oldestTime, latestTime),
            const SizedBox(height: 16),
            
            // Grafik
            Expanded(
              child: SfCartesianChart(
                zoomPanBehavior: _zoomPanBehavior,
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.top,
                  overflowMode: LegendItemOverflowMode.wrap,
                  orientation: LegendItemOrientation.horizontal,
                  toggleSeriesVisibility: true,
                ),
                primaryXAxis: DateTimeAxis(
                  title: AxisTitle(text: 'Waktu'),
                  dateFormat: _getDateFormatBasedOnRange(oldestTime, latestTime),
                  intervalType: _getIntervalTypeBasedOnRange(oldestTime, latestTime),
                  majorGridLines: const MajorGridLines(width: 0),
                  edgeLabelPlacement: EdgeLabelPlacement.shift,
                  // Atur range minimum dan maximum berdasarkan data
                  minimum: oldestTime,
                  maximum: latestTime,
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: 'Suhu (°C)'),
                  minimum: _getMinTemperature() - 2,
                  maximum: _getMaxTemperature() + 2,
                  numberFormat: NumberFormat('#°C'),
                  majorGridLines: const MajorGridLines(width: 0),
                  name: 'Suhu',
                ),
                axes: <ChartAxis>[
                  NumericAxis(
                    name: 'Kelembapan',
                    opposedPosition: true,
                    title: AxisTitle(text: 'Kelembapan (%)'),
                    minimum: _getMinHumidity() - 5,
                    maximum: _getMaxHumidity() + 5,
                    numberFormat: NumberFormat('#%'),
                    majorGridLines: const MajorGridLines(width: 0),
                  )
                ],
                series: <LineSeries<ChartData, DateTime>>[
                  // Garis Suhu
                  LineSeries<ChartData, DateTime>(
                    dataSource: _temperatureData,
                    xValueMapper: (ChartData data, _) => data.time,
                    yValueMapper: (ChartData data, _) => data.value,
                    name: 'Suhu',
                    color: Colors.red,
                    width: 3,
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      height: 6,
                      width: 6,
                      borderWidth: 2,
                      borderColor: Colors.red,
                      shape: DataMarkerType.circle,
                    ),
                  ),
                  // Garis Kelembapan
                  LineSeries<ChartData, DateTime>(
                    dataSource: _humidityData,
                    xValueMapper: (ChartData data, _) => data.time,
                    yValueMapper: (ChartData data, _) => data.value,
                    name: 'Kelembapan',
                    color: Colors.blue,
                    width: 3,
                    yAxisName: 'Kelembapan',
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      height: 6,
                      width: 6,
                      borderWidth: 2,
                      borderColor: Colors.blue,
                      shape: DataMarkerType.circle,
                    ),
                  ),
                ],
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  header: '',
                  format: 'point.x\npoint.series.name: point.y',
                  builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                    final chartData = data as ChartData;
                    final formattedValue = series.name == 'Suhu' 
                        ? _formatTemperature(chartData.value)
                        : _formatHumidity(chartData.value);
                    
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd/MM/yy HH:mm:ss').format(chartData.time),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${series.name}: $formattedValue${series.name == 'Suhu' ? '°C' : '%'}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: series.name == 'Suhu' ? Colors.red : Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildLegendInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartHeader(DateTime oldestTime, DateTime latestTime) {
    final timeRange = latestTime.difference(oldestTime);
    final totalHours = timeRange.inHours;
    final totalMinutes = timeRange.inMinutes;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Grafik Suhu & Kelembapan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        const SizedBox(height: 8),
        _buildTimeRangeInfo(oldestTime, latestTime, timeRange),
        const SizedBox(height: 8),
        _buildQuickStats(),
      ],
    );
  }

  Widget _buildTimeRangeInfo(DateTime oldest, DateTime latest, Duration range) {
    final dateFormat = DateFormat('dd/MM HH:mm');
    final totalHours = range.inHours;
    final totalMinutes = range.inMinutes;
    
    String durationText;
    if (totalHours > 0) {
      durationText = '$totalHours jam ${totalMinutes.remainder(60)} menit';
    } else {
      durationText = '$totalMinutes menit';
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rentang: ${dateFormat.format(oldest)} - ${dateFormat.format(latest)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total: $durationText | ${_temperatureData.length} data points',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final currentTemp = _getCurrentTemperature();
    final currentHumidity = _getCurrentHumidity();
    
    return Row(
      children: [
        _buildQuickStatItem('Suhu', '${_formatTemperature(currentTemp)}°C', Colors.red),
        const SizedBox(width: 12),
        _buildQuickStatItem('Kelembapan', '${_formatHumidity(currentHumidity)}%', Colors.blue),
        const SizedBox(width: 12),
        _buildQuickStatItem('Data', '${_temperatureData.length}', Colors.green),
        const SizedBox(width: 12),
        _buildQuickStatItem('Durasi', _getTotalDuration(), Colors.orange),
      ],
    );
  }

  Widget _buildQuickStatItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(0.1), Colors.transparent),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Color.alphaBlend(color.withOpacity(0.3), Colors.transparent)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          _buildZoomControls(),
          const SizedBox(height: 12),
          _buildDataInfo(),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kontrol Grafik:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _buildControlHint('👆 Geser', 'Horizontal untuk melihat data lama'),
                  _buildControlHint('🤏 Cubit', 'Zoom in/out pada timeline'),
                  _buildControlHint('👆 Double tap', 'Reset zoom'),
                  _buildControlHint('📊 Klik legenda', 'Sembunyikan/tampilkan garis'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.zoom_out_map, size: 16),
          label: const Text('Reset Zoom'),
          onPressed: _resetZoom,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildControlHint(String gesture, String description) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          gesture,
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(width: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange[100]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.orange[700]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Menampilkan semua data dari awal monitoring. Geser untuk melihat detail.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataInfo() {
    final provider = Provider.of<SensorProvider>(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data points: ${_temperatureData.length}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              'Rentang waktu: ${_getTotalDuration()}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              'Rentang data: Semua data',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Update: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              'Mulai: ${DateFormat('HH:mm').format(_temperatureData.first.time)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              'Sekarang: ${DateFormat('HH:mm').format(_temperatureData.last.time)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  // Helper methods untuk format waktu berdasarkan rentang
  DateFormat _getDateFormatBasedOnRange(DateTime oldest, DateTime latest) {
    final difference = latest.difference(oldest);
    if (difference.inDays > 1) {
      return DateFormat('dd/MM HH:mm');
    } else if (difference.inHours > 12) {
      return DateFormat('HH:mm');
    } else {
      return DateFormat('HH:mm:ss');
    }
  }

  DateTimeIntervalType _getIntervalTypeBasedOnRange(DateTime oldest, DateTime latest) {
    final difference = latest.difference(oldest);
    if (difference.inDays > 7) {
      return DateTimeIntervalType.days;
    } else if (difference.inDays > 1) {
      return DateTimeIntervalType.hours;
    } else if (difference.inHours > 6) {
      return DateTimeIntervalType.hours;
    } else {
      return DateTimeIntervalType.minutes;
    }
  }

  String _getTotalDuration() {
    if (_temperatureData.length < 2) return '-';
    
    final first = _temperatureData.first.time;
    final last = _temperatureData.last.time;
    final difference = last.difference(first);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}h ${difference.inHours.remainder(24)}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}j ${difference.inMinutes.remainder(60)}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return '${difference.inSeconds}d';
    }
  }

  double _getCurrentTemperature() {
    return _temperatureData.isNotEmpty ? _temperatureData.last.value : 0;
  }

  double _getCurrentHumidity() {
    return _humidityData.isNotEmpty ? _humidityData.last.value : 0;
  }

  double _getMinTemperature() {
    if (_temperatureData.isEmpty) return 0;
    return _temperatureData.map((d) => d.value).reduce((a, b) => a < b ? a : b);
  }

  double _getMaxTemperature() {
    if (_temperatureData.isEmpty) return 0;
    return _temperatureData.map((d) => d.value).reduce((a, b) => a > b ? a : b);
  }

  double _getMinHumidity() {
    if (_humidityData.isEmpty) return 0;
    return _humidityData.map((d) => d.value).reduce((a, b) => a < b ? a : b);
  }

  double _getMaxHumidity() {
    if (_humidityData.isEmpty) return 0;
    return _humidityData.map((d) => d.value).reduce((a, b) => a > b ? a : b);
  }
}

class ChartData {
  final DateTime time;
  final double value;
  final String label;
  final String type;

  ChartData({
    required this.time,
    required this.value,
    required this.label,
    required this.type,
  });
}