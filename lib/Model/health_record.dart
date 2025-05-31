class HealthRecord {
  final int ecg;
  final double bpm;
  final double spo2;
  final String timestamp;

  HealthRecord({
    required this.ecg,
    required this.bpm,
    required this.spo2,
    required this.timestamp,
  });

  // For converting Firebase data (Map) to HealthRecord
  factory HealthRecord.fromMap(Map<dynamic, dynamic> data) {
    return HealthRecord(
      ecg: data['ecg'] ?? 0,
      bpm: (data['bpm'] ?? 0).toDouble(),
      spo2: (data['spo2'] ?? 0).toDouble(),
      timestamp: data['timestamp'] ?? '',
    );
  }

  // For converting HealthRecord to Map (for saving to Firebase)
  Map<String, dynamic> toMap() {
    return {
      'ecg': ecg,
      'bpm': bpm,
      'spo2': spo2,
      'timestamp': timestamp,
    };
  }
}
