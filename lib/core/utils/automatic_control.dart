class AutomaticControl {
  static Map<String, int> kontrolOtomatis(double suhu, double kelembapan) {
    int lampu = 0;
    int mist = 0;

    if (kelembapan < 50) {
      if (suhu < 35) {
        lampu = 2;
        mist = 1;
      } else if (suhu <= 40) {
        lampu = 1;
        mist = 1;
      } else {
        lampu = 0;
        mist = 1;
      }
    } else if (kelembapan <= 65) {
      if (suhu < 35) {
        lampu = 2;
        mist = 0;
      } else if (suhu <= 40) {
        lampu = 1;
        mist = 0;
      } else {
        lampu = 0;
        mist = 0;
      }
    } else {
      if (suhu < 35) {
        lampu = 3;
        mist = 0;
      } else if (suhu <= 40) {
        lampu = 2;
        mist = 0;
      } else {
        lampu = 0;
        mist = 0;
      }
    }

    return {'lampu': lampu, 'mist': mist};
  }

  // Konversi nilai lampu (0-3) ke status boolean untuk database
  static bool convertLampuToBoolean(int lampuValue) {
    // Nilai 0 = mati, 1-3 = menyala dengan intensitas berbeda
    return lampuValue > 0;
  }

  // Konversi nilai mist (0-1) ke status boolean untuk database
  static bool convertMistToBoolean(int mistValue) {
    return mistValue == 1;
  }

  // Method untuk mendapatkan jumlah lampu yang menyala
  static int getJumlahLampu(int lampuValue) {
    return lampuValue; // Nilai langsung 0, 1, 2, atau 3
  }

  // Method untuk mendapatkan deskripsi status
  static Map<String, String> getStatusDescription(int lampu, int mist) {
    final lampuDescriptions = {
      0: 'Mati (0 lampu)',
      1: '1 Lampu Menyala (Intensitas Rendah)',
      2: '2 Lampu Menyala (Intensitas Sedang)',
      3: '3 Lampu Menyala (Intensitas Tinggi)'
    };

    final mistDescriptions = {
      0: 'Mati',
      1: 'Menyala'
    };

    return {
      'lampu': lampuDescriptions[lampu] ?? 'Tidak Diketahui',
      'mist': mistDescriptions[mist] ?? 'Tidak Diketahui',
    };
  }

  // Method untuk mendapatkan rekomendasi berdasarkan kondisi
  static String getRecommendation(double suhu, double kelembapan) {
    final control = kontrolOtomatis(suhu, kelembapan);
    final lampu = control['lampu']!;
    final mist = control['mist']!;

    if (lampu == 0 && mist == 0) {
      return 'Kondisi optimal, tidak perlu penyesuaian';
    } else if (lampu > 0 && mist == 0) {
      return 'Perlu pemanasan tambahan ($lampu lampu)';
    } else if (lampu == 0 && mist > 0) {
      return 'Perlu pelembapan tambahan';
    } else {
      return 'Perlu pemanasan ($lampu lampu) dan pelembapan';
    }
  }
}