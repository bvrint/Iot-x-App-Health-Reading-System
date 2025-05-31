import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';


class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  StatisticsScreenState createState() => StatisticsScreenState();
}

class StatisticsScreenState extends State<StatisticsScreen> {
  final DatabaseReference _historyRef =
      FirebaseDatabase.instance.ref().child('history');

  double avgBpm = 0;
  double avgSpo2 = 0;
  int minBpm = 999, maxBpm = 0;
  double minSpo2 = 999, maxSpo2 = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAndCalculateStats();
  }

  Future<void> fetchAndCalculateStats() async {
  final snapshot = await _historyRef.get();

  if (snapshot.exists) {
    final rawData = snapshot.value as Map;
    final entries = rawData.entries;

    int totalBpm = 0;
    double totalSpo2 = 0;
    int count = 0;

    int loopMinBpm = 999, loopMaxBpm = 0;
    double loopMinSpo2 = 999, loopMaxSpo2 = 0;

    for (final entry in entries) {
      final data = Map<String, dynamic>.from(entry.value);

      // Extract values safely
      final dynamic rawBpm = data['bpm'];
      final dynamic rawSpo2 = data['spo2'];

      if (rawBpm == null || rawSpo2 == null) continue;

      final int bpm = rawBpm;
      final double spo2 = rawSpo2.toDouble();

      // ✅ Skip clearly invalid or zero values
      if (bpm == 0 || spo2 == 0) continue;

      totalBpm += bpm;
      totalSpo2 += spo2;
      count++;

      if (bpm < loopMinBpm) loopMinBpm = bpm;
      if (bpm > loopMaxBpm) loopMaxBpm = bpm;

      if (spo2 < loopMinSpo2) loopMinSpo2 = spo2;
      if (spo2 > loopMaxSpo2) loopMaxSpo2 = spo2;
    }

    setState(() {
      if (count > 0) {
        avgBpm = totalBpm / count;
        avgSpo2 = totalSpo2 / count;
        minBpm = loopMinBpm;
        maxBpm = loopMaxBpm;
        minSpo2 = loopMinSpo2;
        maxSpo2 = loopMaxSpo2;
      } else {
        avgBpm = avgSpo2 = 0;
        minBpm = maxBpm = 0;
        minSpo2 = maxSpo2 = 0;
      }
      _isLoading = false;
    });
  } else {
    setState(() => _isLoading = false);
  }
}


  Widget statCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Statistics', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blueGrey,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  statCard("Average Heart Rate", "${avgBpm.toStringAsFixed(1)} BPM", Colors.red),
                  SizedBox(height: 12),
                  statCard("Average SpO₂", "${avgSpo2.toStringAsFixed(1)}%", Colors.blue),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: statCard("Min HR", "$minBpm BPM", Colors.orange),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: statCard("Max HR", "$maxBpm BPM", Colors.green),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: statCard("Min SpO₂", "${minSpo2.toStringAsFixed(1)}%", Colors.orange),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: statCard("Max SpO₂", "${maxSpo2.toStringAsFixed(1)}%", Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
