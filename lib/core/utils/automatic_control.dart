class AutomaticControl {
  static Map<String, int> kontrolOtomatis(double suhu, double kelembapan) {
    int lampu = 0;
    int mist = 0;

    if (kelembapan < 50) {
      if (suhu < 35) {
        lampu = 2; // 2 lampu menyala (intensitas tinggi)
        mist = 1;
      } else if (suhu <= 40) {
        lampu = 1; // 1 lampu menyala (intensitas rendah)
        mist = 1;
      } else {
        lampu = 0; // mati
        mist = 1;
      }
    } else if (kelembapan <= 65) {
      if (suhu < 35) {
        lampu = 2; // 2 lampu menyala
        mist = 0;
      } else if (suhu <= 40) {
        lampu = 1; // 1 lampu menyala
        mist = 0;
      } else {
        lampu = 0; // mati
        mist = 0;
      }
    } else {
      if (suhu < 35) {
        lampu = 2; // 2 lampu menyala (maksimal)
        mist = 0;
      } else if (suhu <= 40) {
        lampu = 1; // 1 lampu menyala
        mist = 0;
      } else {
        lampu = 0; // mati
        mist = 0;
      }
    }

    return {'lampu': lampu, 'mist': mist};
  }

  // Konversi nilai lampu (0-2) ke status boolean untuk database
  static bool convertLampuToBoolean(int lampuValue) {
    return lampuValue > 0;
  }

  // Konversi nilai mist (0-1) ke status boolean untuk database
  static bool convertMistToBoolean(int mistValue) {
    return mistValue == 1;
  }

  // Method untuk mendapatkan jumlah lampu yang menyala (0, 1, atau 2)
  static int getJumlahLampu(int lampuValue) {
    return lampuValue.clamp(0, 2); // Pastikan tidak lebih dari 2
  }

  // Method untuk mendapatkan deskripsi status - DIUBAH untuk 2 lampu
  static Map<String, String> getStatusDescription(int lampu, int mist) {
    final lampuDescriptions = {
      0: 'Mati (0 lampu)',
      1: '1 Lampu Menyala (Intensitas Rendah)',
      2: '2 Lampu Menyala (Intensitas Tinggi)' // Hanya sampai 2
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

  // Method untuk mendapatkan rekomendasi berdasarkan kondisi - DIUBAH
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

  // Method baru untuk validasi jumlah lampu
  static int validateJumlahLampu(int jumlahLampu) {
    return jumlahLampu.clamp(0, 2);
  }
}