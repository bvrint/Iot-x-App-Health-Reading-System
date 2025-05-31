import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final databaseRef = FirebaseDatabase.instance.ref().child('patient');

  double bpm = 0;
  double spo2 = 0;
  List<int> ecgData = List.generate(50, (_) => 512); // baseline ECG

  bool isReading = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    // Don't start listening automatically
  }

  void listenToRealtimeData() {
    _subscription = databaseRef.onValue.listen((event) {
      if (!isReading) return; // ignore if not reading

      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          bpm = (data['HeartRate'] ?? 0).toDouble();
          spo2 = (data['SPO2'] ?? 0).toDouble();

          int ecgVal = (data['ECG'] ?? 512).toInt().clamp(400, 700);

          ecgData.add(ecgVal);
          if (ecgData.length > 100) {
            ecgData.removeAt(0);
          }
        });
      }
    });
  }

  void stopReadingAndSaveToHistory() {
    _subscription?.cancel();

    final historyRef = FirebaseDatabase.instance.ref().child('history').push();
    historyRef.set({
      'timestamp': DateTime.now().toIso8601String(),
      'HeartRate': bpm,
      'SPO2': spo2,
      'ECGData': ecgData,
    });

    setState(() {
      isReading = false;
      bpm = 0;
      spo2 = 0;
      ecgData = List.generate(50, (_) => 512); // reset waveform
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Widget buildECGChart() {
    // ✅ MODIFIED: Calculate dynamic min/max Y with buffer
    final minVal = ecgData.reduce((a, b) => a < b ? a : b).toDouble();
    final maxVal = ecgData.reduce((a, b) => a > b ? a : b).toDouble();
    const yMargin = 20;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LineChart(
        LineChartData(
          minY: minVal - yMargin, // ✅ MODIFIED
          maxY: maxVal + yMargin, // ✅ MODIFIED
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: ecgData
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                  .toList(),
              isCurved: true,
              color: Colors.green,
              barWidth: 2,
              dotData: FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMetricCard({
    required String label,
    required String value,
    required double normalizedValue,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        height: 190,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: normalizedValue.clamp(0.0, 1.0),
                    strokeWidth: 20,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    backgroundColor: color.withOpacity(0.2),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Health Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blueGrey,
      ),
      body: SingleChildScrollView(
  padding: const EdgeInsets.all(16.0),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // ECG Card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ECG Waveform', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: buildECGChart(),
            ),
          ],
        ),
      ),

      const SizedBox(height: 16),

      // Heart Rate and SpO2 Cards
      Row(
        children: [
          buildMetricCard(
          label: 'Heart Rate (BPM)',
          value: '${bpm.toStringAsFixed(0)} BPM',
          normalizedValue: (bpm / 100).clamp(0.0, 1.0), // ✅ FIXED
          color: Colors.redAccent,
          ),
          buildMetricCard(
          label: 'SpO₂ Level',
          value: '${spo2.toStringAsFixed(0)}%',
          normalizedValue: (spo2 / 100).clamp(0.0, 1.0), // ✅ FIXED
          color: Colors.blueAccent,
          ),
        ],
      ),

      const SizedBox(height: 16),

      // Buttons
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text('History'),
              onPressed: () => Navigator.pushNamed(context, '/history'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.analytics),
              label: const Text('Statistics'),
              onPressed: () => Navigator.pushNamed(context, '/stats'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),

      const SizedBox(height: 16),

      // Start/Stop Reading Button
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(isReading ? Icons.stop : Icons.play_arrow),
          label: Text(isReading ? 'Stop & Save' : 'Start Reading'),
          onPressed: () {
            if (isReading) {
              stopReadingAndSaveToHistory();
            } else {
              setState(() {
                isReading = true;
              });
              listenToRealtimeData();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isReading ? Colors.redAccent : Colors.blueGrey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      const SizedBox(height: 40), // padding at bottom
    ],
  ),
),
    );
  }
}

