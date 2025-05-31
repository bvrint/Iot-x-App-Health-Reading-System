import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final DatabaseReference _historyRef = FirebaseDatabase.instance.ref().child('history');

  Map<String, dynamic> _historyData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchHistoryData();
  }

  void fetchHistoryData() async {
    final snapshot = await _historyRef.get();

    if (snapshot.exists) {
      final rawData = snapshot.value as Map;
      setState(() {
        _historyData = rawData.map((key, value) =>
            MapEntry(key.toString(), Map<String, dynamic>.from(value)));
        _isLoading = false;
      });
    } else {
      setState(() {
        _historyData = {};
        _isLoading = false;
      });
    }
  }

  String formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('MMM d, yyyy – HH:mm').format(dt);
    } catch (_) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white,)),
        backgroundColor: Colors.blueGrey,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyData.isEmpty
              ? const Center(child: Text("No data available"))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _historyData.entries.map((entry) {
                    final data = entry.value;

                    final heartRate = data['HeartRate'] ?? 0;
                    final spo2 = data['SPO2'] ?? 0;
                    final timestampRaw = data['timestamp'] ?? entry.key;
                    final formattedTime = formatTimestamp(timestampRaw);

                    // Safely extract ECGData
                    final ecgRaw = data['ECGData'];
                    String ecgSample = 'N/A';

                    if (ecgRaw is Map) {
                      final ecgMap = Map<String, dynamic>.from(ecgRaw);
                      ecgSample = ecgMap.values.isNotEmpty
                          ? ecgMap.values.first.toString()
                          : 'N/A';
                    } else if (ecgRaw is List) {
                      ecgSample = ecgRaw.isNotEmpty
                          ? ecgRaw.first.toString()
                          : 'N/A';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          formattedTime,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Heart Rate: $heartRate BPM'),
                              Text('SpO₂: ${spo2.toStringAsFixed(1)}%'),
                              Text('Sample ECG Value: $ecgSample'),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}
