abstract class SensorRepository {
  // Stream untuk mendapatkan data real-time
  Stream<Map<String, dynamic>> getDataStream();
  
  // Stream dengan polling interval tertentu
  Stream<Map<String, dynamic>> getDataPolling({int intervalSeconds});
  
  // Method untuk mengambil data awal
  Future<Map<String, dynamic>> fetchInitialData();
  
  // Method untuk mengambil data historis
  Future<List<Map<String, dynamic>>> fetchHistoricalData({int limit});
  
  // Method untuk mengirim kontrol otomatis berdasarkan sensor data
  Future<bool> sendAutomaticControl(double suhu, double kelembapan);
  
  // Method untuk mengirim kontrol manual
  Future<bool> sendManualControl({
    bool? statusLampu,
    bool? statusHumidifier,
    double? targetKelembapan,
  });
  
  // Method untuk mengecek koneksi
  Future<bool> checkConnection();
  
  // Status stream
  bool get isStreamActive;
  bool get isUsingPolling;
  
  // Cleanup
  Future<void> dispose();
}