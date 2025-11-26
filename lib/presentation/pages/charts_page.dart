import 'dart:async';
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
  bool _isAutoUpdate = true;
  late TrackballBehavior _trackballBehavior;
  late ZoomPanBehavior _zoomPanBehavior;
  StreamSubscription<Map<String, dynamic>>? _dataSubscription;
  DateTime? _lastUpdateTime;
  
  // Data terbaru yang berkedip
  ChartData? _latestTemperatureData;
  ChartData? _latestHumidityData;
  
  final ScrollController _horizontalScrollController = ScrollController();
  final bool _showScrollBar = false;
  bool _shouldScrollToEnd = false;
  DateTime? _lastProcessedTimestamp;

  // Variabel untuk kontrol zoom dan detail
  double _chartHeight = 400;
  bool _showDetailedView = false;

  @override
  void initState() {
    super.initState();
    _initializeBehaviors();
    _loadChartData();
    _startAutoUpdate();
    _setupHistoryListener();
  }

  void _initializeBehaviors() {
    _trackballBehavior = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
      tooltipSettings: const InteractiveTooltip(
        enable: true,
        color: Colors.black87,
        borderWidth: 2,
        borderColor: Colors.white,
        textStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      lineType: TrackballLineType.vertical,
      lineColor: _colorWithOpacity(Colors.grey, 0.7),
      lineWidth: 2,
      markerSettings: const TrackballMarkerSettings(
        markerVisibility: TrackballVisibilityMode.visible,
        shape: DataMarkerType.circle,
        width: 8,
        height: 8,
        borderWidth: 2,
        color: Colors.white,
      ),
    );

    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enableDoubleTapZooming: true,
      enablePanning: true,
      enableSelectionZooming: true,
      selectionRectColor: Colors.blue.withOpacity(0.3),
      selectionRectBorderColor: Colors.blue,
      zoomMode: ZoomMode.x,
    );
  }

  void _setupHistoryListener() {
    final provider = Provider.of<SensorProvider>(context, listen: false);
    provider.addListener(_onProviderUpdate);
  }

  void _onProviderUpdate() {
    if (mounted && _isAutoUpdate) {
      final provider = Provider.of<SensorProvider>(context, listen: false);
      _updateChartDataFromHistory(provider.dataHistory);
    }
  }

  Color _colorWithOpacity(Color color, double opacity) {
    return Color.fromRGBO(
      (color.red * 255.0).round().clamp(0, 255),
      (color.green * 255.0).round().clamp(0, 255),
      (color.blue * 255.0).round().clamp(0, 255),
      opacity,
    );
  }

  void _loadChartData() {
    final provider = Provider.of<SensorProvider>(context, listen: false);
    
    debugPrint('📊 Loading ALL chart data...');
    
    if (provider.isLoadingHistory) {
      debugPrint('⏳ Waiting for historical data to load...');
      Future.delayed(const Duration(seconds: 1), () {
        _loadChartData();
      });
      return;
    }
    
    debugPrint('📊 Total ALL data history: ${provider.dataHistory.length}');
    
    _updateChartDataFromHistory(provider.dataHistory);
    setState(() {
      _isLoading = false;
    });
  }

  void _updateChartDataFromHistory(List<Map<String, dynamic>> dataHistory) {
    _temperatureData = dataHistory.map((data) {
      final sensor = data['sensor'] as SensorData;
      final isLatest = dataHistory.last == data;
      return ChartData(
        time: sensor.timestamp,
        value: sensor.suhu,
        label: '${_formatTemperature(sensor.suhu)}°C',
        type: 'Suhu',
        isNew: isLatest,
      );
    }).toList();

    _humidityData = dataHistory.map((data) {
      final sensor = data['sensor'] as SensorData;
      final isLatest = dataHistory.last == data;
      return ChartData(
        time: sensor.timestamp,
        value: sensor.kelembapan,
        label: '${_formatHumidity(sensor.kelembapan)}%',
        type: 'Kelembapan',
        isNew: isLatest,
      );
    }).toList();

    // Set data terbaru untuk berkedip
    if (_temperatureData.isNotEmpty) {
      _latestTemperatureData = _temperatureData.last.copyWith(isNew: true);
      _lastProcessedTimestamp = _temperatureData.last.time;
    }
    
    if (_humidityData.isNotEmpty) {
      _latestHumidityData = _humidityData.last.copyWith(isNew: true);
    }

    _lastUpdateTime = DateTime.now();
    
    // Set flag untuk scroll ke akhir setelah widget dibangun
    _shouldScrollToEnd = true;

    debugPrint('📈 Chart data updated: ${_temperatureData.length} points');
    debugPrint('📈 Last processed timestamp: $_lastProcessedTimestamp');
  }

  @override
  void didUpdateWidget(ChartsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll ke akhir setelah widget di-update
    if (_shouldScrollToEnd) {
      _scrollToEndWithPadding();
      _shouldScrollToEnd = false;
    }
  }

  void _scrollToEndWithPadding() {
    if (_horizontalScrollController.hasClients && !_horizontalScrollController.position.outOfRange) {
      final maxScroll = _horizontalScrollController.position.maxScrollExtent;
      final padding = 100.0;
      
      // Gunakan post frame callback untuk memastikan scroll view sudah siap
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_horizontalScrollController.hasClients) {
          _horizontalScrollController.animateTo(
            maxScroll + padding,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  int _calculateRightPadding() {
    if (_temperatureData.length < 2) return 10;
    
    int totalInterval = 0;
    int intervalCount = 0;
    
    for (int i = 1; i < _temperatureData.length; i++) {
      final interval = _temperatureData[i].time.difference(_temperatureData[i-1].time).inMinutes;
      if (interval > 0) {
        totalInterval += interval;
        intervalCount++;
      }
    }
    
    if (intervalCount == 0) return 10;
    
    final averageInterval = totalInterval ~/ intervalCount;
    return (averageInterval * 2).clamp(5, 60);
  }

  void _startAutoUpdate() {
    final provider = Provider.of<SensorProvider>(context, listen: false);
    
    _dataSubscription = provider.getDataStream().listen((newData) {
      if (_isAutoUpdate && mounted) {
        _handleSequentialData(newData);
      }
    }, onError: (error) {
      debugPrint('❌ Error in data stream: $error');
      if (_isAutoUpdate && mounted) {
        Future.delayed(const Duration(seconds: 5), () {
          if (_isAutoUpdate && mounted) {
            debugPrint('🔄 Restarting data stream...');
            _restartDataStream();
          }
        });
      }
    }, onDone: () {
      debugPrint('📭 Data stream closed');
      if (_isAutoUpdate && mounted) {
        Future.delayed(const Duration(seconds: 3), () {
          if (_isAutoUpdate && mounted) {
            debugPrint('🔄 Restarting closed data stream...');
            _restartDataStream();
          }
        });
      }
    });
  }

  void _restartDataStream() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isAutoUpdate) {
        _startAutoUpdate();
      }
    });
  }

  // Method improved untuk handle sequential chart data
  void _handleSequentialData(Map<String, dynamic> newData) {
    final sensor = newData['sensor'] as SensorData;
    final sequentialCount = newData['sequentialCount'] as int? ?? 1;
    
    debugPrint('🔄 Sequential chart data: $sequentialCount records at ${sensor.timestamp}');
    
    setState(() {
      // Update data terbaru yang berkedip
      _latestTemperatureData = ChartData(
        time: sensor.timestamp,
        value: sensor.suhu,
        label: '${_formatTemperature(sensor.suhu)}°C',
        type: 'Suhu',
        isNew: true,
      );
      
      _latestHumidityData = ChartData(
        time: sensor.timestamp,
        value: sensor.kelembapan,
        label: '${_formatHumidity(sensor.kelembapan)}%',
        type: 'Kelembapan',
        isNew: true,
      );
      
      // Cek dan update/append data sequential
      _updateSequentialChartData(sensor);
      
      _lastUpdateTime = DateTime.now();
      _lastProcessedTimestamp = sensor.timestamp;
      _shouldScrollToEnd = true;
    });
    
    debugPrint('✅ Data processed - Total points: ${_temperatureData.length}');
  }

  // Method untuk update data chart secara sequential
  void _updateSequentialChartData(SensorData newSensor) {
    // Cek apakah data dengan timestamp yang sama sudah ada
    final tempIndex = _temperatureData.indexWhere(
      (data) => data.time == newSensor.timestamp
    );
    final humidityIndex = _humidityData.indexWhere(
      (data) => data.time == newSensor.timestamp
    );
    
    if (tempIndex != -1) {
      // Update existing temperature data
      _temperatureData[tempIndex] = ChartData(
        time: newSensor.timestamp,
        value: newSensor.suhu,
        label: '${_formatTemperature(newSensor.suhu)}°C',
        type: 'Suhu',
        isNew: true,
      );
      debugPrint('🔄 Updated existing temperature data at index $tempIndex');
    } else {
      // Add new temperature data
      _temperatureData.add(ChartData(
        time: newSensor.timestamp,
        value: newSensor.suhu,
        label: '${_formatTemperature(newSensor.suhu)}°C',
        type: 'Suhu',
        isNew: true,
      ));
      debugPrint('📈 Added new temperature data point');
    }
    
    if (humidityIndex != -1) {
      // Update existing humidity data
      _humidityData[humidityIndex] = ChartData(
        time: newSensor.timestamp,
        value: newSensor.kelembapan,
        label: '${_formatHumidity(newSensor.kelembapan)}%',
        type: 'Kelembapan',
        isNew: true,
      );
      debugPrint('🔄 Updated existing humidity data at index $humidityIndex');
    } else {
      // Add new humidity data
      _humidityData.add(ChartData(
        time: newSensor.timestamp,
        value: newSensor.kelembapan,
        label: '${_formatHumidity(newSensor.kelembapan)}%',
        type: 'Kelembapan',
        isNew: true,
      ));
      debugPrint('📈 Added new humidity data point');
    }
    
    // Urutkan data berdasarkan timestamp
    _temperatureData.sort((a, b) => a.time.compareTo(b.time));
    _humidityData.sort((a, b) => a.time.compareTo(b.time));
    
    // Batasi data untuk menghindari memory overflow
    _cleanupChartData();
    
    debugPrint('📈 Chart updated - Total points: ${_temperatureData.length}');
  }

  // Method untuk cleanup data chart lama
  void _cleanupChartData() {
    const maxDataPoints = 1000;
    
    if (_temperatureData.length > maxDataPoints) {
      _temperatureData = _temperatureData.sublist(_temperatureData.length - (maxDataPoints ~/ 2));
      debugPrint('🧹 Cleaned up old temperature data, now: ${_temperatureData.length} points');
    }
    
    if (_humidityData.length > maxDataPoints) {
      _humidityData = _humidityData.sublist(_humidityData.length - (maxDataPoints ~/ 2));
      debugPrint('🧹 Cleaned up old humidity data, now: ${_humidityData.length} points');
    }
  }

  void _toggleAutoUpdate() {
    setState(() {
      _isAutoUpdate = !_isAutoUpdate;
    });
    
    if (_isAutoUpdate) {
      _restartDataStream();
      _refreshData();
    } else {
      _dataSubscription?.cancel();
      _dataSubscription = null;
    }
  }

  // Method untuk toggle detailed view
  void _toggleDetailedView() {
    setState(() {
      _showDetailedView = !_showDetailedView;
      _chartHeight = _showDetailedView ? 600 : 400;
    });
  }

  // Method untuk reset zoom
  void _resetZoom() {
    _zoomPanBehavior.reset();
  }

  // Method untuk export data
  void _exportData() {
    // Implementasi export data bisa ditambahkan di sini
    _showExportDialog();
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Fitur export data akan segera tersedia.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTemperature(double temperature) {
    return temperature % 1 == 0 
        ? temperature.toInt().toString()
        : temperature.toStringAsFixed(1);
  }

  String _formatHumidity(double humidity) {
    return humidity % 1 == 0 
        ? humidity.toInt().toString()
        : humidity.toStringAsFixed(1);
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    
    final provider = Provider.of<SensorProvider>(context, listen: false);
    
    debugPrint('🔄 Refreshing ALL historical data...');
    await provider.refreshHistoricalData();
    
    _updateChartDataFromHistory(provider.dataHistory);
    setState(() {
      _isLoading = false;
      _shouldScrollToEnd = true;
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    
    // Remove listener dari provider
    final provider = Provider.of<SensorProvider>(context, listen: false);
    provider.removeListener(_onProviderUpdate);
    
    // Dispose controller dengan benar
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grafik Monitoring - Real-time'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          // Tombol untuk kontrol grafik
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'detailed':
                  _toggleDetailedView();
                  break;
                case 'reset_zoom':
                  _resetZoom();
                  break;
                case 'export':
                  _exportData();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'detailed',
                child: Row(
                  children: [
                    Icon(_showDetailedView ? Icons.zoom_out_map : Icons.zoom_in),
                    const SizedBox(width: 8),
                    Text(_showDetailedView ? 'Tampilan Normal' : 'Tampilan Detail'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset_zoom',
                child: Row(
                  children: [
                    const Icon(Icons.restore),
                    const SizedBox(width: 8),
                    const Text('Reset Zoom'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    const Icon(Icons.download),
                    const SizedBox(width: 8),
                    const Text('Export Data'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              _isAutoUpdate ? Icons.autorenew : Icons.autorenew_outlined,
              color: _isAutoUpdate ? Colors.amber : Colors.white,
            ),
            onPressed: _toggleAutoUpdate,
            tooltip: _isAutoUpdate ? 'Auto Update: ON' : 'Auto Update: OFF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Semua Data',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _buildMainContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Memuat semua data historis...'),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_temperatureData.isEmpty || _humidityData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Belum ada data untuk ditampilkan',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Data'),
              onPressed: _refreshData,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildHeaderInfo(),
        Expanded(
          child: _buildScrollableChart(),
        ),
        _buildBottomPanel(),
      ],
    );
  }

  Widget _buildScrollableChart() {
    final oldestTime = _temperatureData.first.time;
    final latestTime = _temperatureData.last.time;
    
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildChartControls(),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    padding: const EdgeInsets.only(right: 40.0),
                    child: SizedBox(
                      width: _calculateChartWidth(),
                      child: SizedBox(
                        height: _chartHeight,
                        child: _buildChartWidget(oldestTime, latestTime),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartWidget(DateTime oldestTime, DateTime latestTime) {
    final chartLatestTime = latestTime.add(Duration(minutes: _calculateRightPadding()));
    
    return SfCartesianChart(
      trackballBehavior: _trackballBehavior,
      zoomPanBehavior: _zoomPanBehavior,
      legend: Legend(
        isVisible: true,
        position: LegendPosition.top,
        overflowMode: LegendItemOverflowMode.wrap,
        orientation: LegendItemOrientation.horizontal,
        toggleSeriesVisibility: true,
      ),
      primaryXAxis: DateTimeAxis(
        title: const AxisTitle(text: 'Waktu'),
        dateFormat: _getDateFormatBasedOnRange(oldestTime, latestTime),
        intervalType: _getIntervalTypeBasedOnRange(oldestTime, latestTime),
        majorGridLines: const MajorGridLines(width: 0.5, color: Colors.grey),
        edgeLabelPlacement: EdgeLabelPlacement.shift,
        minimum: oldestTime,
        maximum: chartLatestTime,
      ),
      primaryYAxis: NumericAxis(
        title: const AxisTitle(text: 'Suhu (°C)'),
        minimum: _getMinTemperature() - 2,
        maximum: _getMaxTemperature() + 2,
        numberFormat: NumberFormat('#°C'),
        majorGridLines: const MajorGridLines(width: 0.5, color: Colors.grey),
        name: 'Suhu',
      ),
      axes: <ChartAxis>[
        NumericAxis(
          name: 'Kelembapan',
          opposedPosition: true,
          title: const AxisTitle(text: 'Kelembapan (%)'),
          minimum: _getMinHumidity() - 5,
          maximum: _getMaxHumidity() + 5,
          numberFormat: NumberFormat('#%'),
          majorGridLines: const MajorGridLines(width: 0.5, color: Colors.grey),
        )
      ],
      series: <CartesianSeries>[
        // Line series untuk suhu dengan marker yang lebih visible
        LineSeries<ChartData, DateTime>(
          dataSource: _temperatureData,
          xValueMapper: (ChartData data, _) => data.time,
          yValueMapper: (ChartData data, _) => data.value,
          name: 'Suhu',
          color: Colors.red,
          width: 3,
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            height: 6,
            width: 6,
            color: Colors.red,
            borderWidth: 2,
            borderColor: Colors.white,
          ),
        ),
        // Line series untuk kelembapan dengan marker yang lebih visible
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
            shape: DataMarkerType.circle,
            height: 6,
            width: 6,
            color: Colors.blue,
            borderWidth: 2,
            borderColor: Colors.white,
          ),
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        header: '',
        canShowMarker: true,
        builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
          final chartData = data as ChartData;
          final formattedValue = series.name == 'Suhu'
              ? _formatTemperature(chartData.value)
              : _formatHumidity(chartData.value);
          
          final isLatestData = chartData == _latestTemperatureData || 
                             chartData == _latestHumidityData;
          
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy HH:mm:ss').format(chartData.time),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: series.name == 'Suhu' ? Colors.red : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${series.name}: $formattedValue${series.name == 'Suhu' ? '°C' : '%'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (isLatestData) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TERBARU',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _calculateChartWidth() {
    final baseWidth = 100.0;
    final dataCount = _temperatureData.length;
    final additionalWidth = dataCount * 8.0;
    return baseWidth + additionalWidth.clamp(0, 2000);
  }

  Widget _buildHeaderInfo() {
    final provider = Provider.of<SensorProvider>(context);
    final stats = provider.getDataStatistics();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(bottom: BorderSide(color: Colors.blue[100]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 Grafik Real-time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: provider.isConnected ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider.isConnected ? 'TERHUBUNG' : 'TERPUTUS',
                        style: TextStyle(
                          fontSize: 12,
                          color: provider.isConnected ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isAutoUpdate ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isAutoUpdate ? 'Auto Update: ON' : 'Auto Update: OFF',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isAutoUpdate ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_temperatureData.length} Data',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'TAP GRAFIK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildStatItem('⏱️ Rentang', stats['timeRange']),
              _buildStatItem('📈 Total', '${stats['totalPoints']} data'),
              _buildStatItem('🌡️ Avg Suhu', '${stats['avgTemperature'].toStringAsFixed(1)}°C'),
              _buildStatItem('💧 Avg Kelembapan', '${stats['avgHumidity'].toStringAsFixed(1)}%'),
              _buildStatItem('🔄 Update', _lastUpdateTime != null 
                  ? DateFormat('HH:mm:ss').format(_lastUpdateTime!)
                  : '-'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cara Interaksi dengan Grafik:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildControlHint('👆 TAP', 'Lihat detail data di titik tertentu'),
                    _buildControlHint('📏 PINCH', 'Zoom in/out dengan dua jari'),
                    _buildControlHint('🖱️ DRAG', 'Select area untuk zoom spesifik'),
                    _buildControlHint('↔️ GESER', 'Scroll horizontal lihat lebih data'),
                    _buildControlHint('📊 LEGEND', 'Tap legend untuk sembunyikan garis'),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              ElevatedButton(
                onPressed: _scrollToEndWithPadding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Ke Data Terbaru', style: TextStyle(fontSize: 10)),
              ),
              const SizedBox(height: 4),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: _refreshData,
                tooltip: 'Refresh Data',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlHint(String gesture, String description) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            gesture,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    final oldest = _temperatureData.first.time;
    final latest = _temperatureData.last.time;
    final duration = latest.difference(oldest);
    final stats = Provider.of<SensorProvider>(context).getDataStatistics();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          _buildDataInfo(oldest, latest, duration),
          const SizedBox(height: 8),
          _buildRangeStats(),
          if (_showDetailedView) _buildDetailedStats(stats, duration),
        ],
      ),
    );
  }

  Widget _buildDataInfo(DateTime oldest, DateTime latest, Duration duration) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informasi Grafik:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              _buildInfoRow('Total Data Points', '${_temperatureData.length}'),
              _buildInfoRow('Rentang Waktu', _formatDuration(duration)),
              _buildInfoRow('Data Tertua', DateFormat('dd/MM HH:mm').format(oldest)),
              _buildInfoRow('Data Terbaru', DateFormat('dd/MM HH:mm').format(latest)),
              _buildInfoRow('Update Terakhir', _lastUpdateTime != null 
                  ? DateFormat('HH:mm:ss').format(_lastUpdateTime!)
                  : '-'),
              _buildInfoRow('Mode Tampilan', _showDetailedView ? 'Detail' : 'Normal'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeStats() {
    final minTemp = _getMinTemperature();
    final maxTemp = _getMaxTemperature();
    final minHumidity = _getMinHumidity();
    final maxHumidity = _getMaxHumidity();
    
    return Row(
      children: [
        Expanded(
          child: _buildRangeItem('🌡️ Suhu', '${_formatTemperature(minTemp)}°C - ${_formatTemperature(maxTemp)}°C', Colors.red),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildRangeItem('💧 Kelembapan', '${_formatHumidity(minHumidity)}% - ${_formatHumidity(maxHumidity)}%', Colors.blue),
        ),
      ],
    );
  }

  Widget _buildDetailedStats(Map<String, dynamic> stats, Duration duration) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📈 Statistik Detail:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildDetailStat('Rata-rata Suhu', '${stats['avgTemperature'].toStringAsFixed(1)}°C'),
              _buildDetailStat('Rata-rata Kelembapan', '${stats['avgHumidity'].toStringAsFixed(1)}%'),
              _buildDetailStat('Data per Jam', '${(_temperatureData.length / (duration.inHours + 1)).toStringAsFixed(1)}'),
              _buildDetailStat('Status', _isAutoUpdate ? 'Auto Update' : 'Manual'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeItem(String title, String range, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _colorWithOpacity(color, 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _colorWithOpacity(color, 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            range,
            style: TextStyle(fontSize: 9, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} hari ${duration.inHours.remainder(24)} jam';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} jam ${duration.inMinutes.remainder(60)} menit';
    } else {
      return '${duration.inMinutes} menit';
    }
  }

  DateFormat _getDateFormatBasedOnRange(DateTime oldest, DateTime latest) {
    final difference = latest.difference(oldest);
    if (difference.inDays > 2) {
      return DateFormat('dd/MM HH:mm');
    } else {
      return DateFormat('HH:mm');
    }
  }

  DateTimeIntervalType _getIntervalTypeBasedOnRange(DateTime oldest, DateTime latest) {
    final difference = latest.difference(oldest);
    if (difference.inDays > 7) {
      return DateTimeIntervalType.days;
    } else if (difference.inDays > 2) {
      return DateTimeIntervalType.hours;
    } else {
      return DateTimeIntervalType.minutes;
    }
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
  bool isNew;

  ChartData({
    required this.time,
    required this.value,
    required this.label,
    required this.type,
    this.isNew = false,
  });

  ChartData copyWith({
    DateTime? time,
    double? value,
    String? label,
    String? type,
    bool? isNew,
  }) {
    return ChartData(
      time: time ?? this.time,
      value: value ?? this.value,
      label: label ?? this.label,
      type: type ?? this.type,
      isNew: isNew ?? this.isNew,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartData &&
          runtimeType == other.runtimeType &&
          time == other.time &&
          value == other.value &&
          type == other.type;

  @override
  int get hashCode => time.hashCode ^ value.hashCode ^ type.hashCode;
}