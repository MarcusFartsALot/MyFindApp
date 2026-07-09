import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VisaReportScreen extends StatelessWidget {
  final String applicationId;
  const VisaReportScreen({Key? key, required this.applicationId}) : super(key: key);

  Future<Map<String, dynamic>> _fetchReport() async {
    final supabase = Supabase.instance.client;
    final prediction = await supabase.from('risk_predictions').select().eq('application_id', applicationId).single();
    return prediction;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ASSESSMENT REPORT')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchReport(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Error loading report.'));
          }

          final data = snapshot.data!;
          final double riskScore = double.tryParse(data['risk_score'].toString()) ?? 0.0;
          final double successRate = 100 - riskScore;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("AI SUCCESS EVALUATION RATE", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 8),
                Text("${successRate.toStringAsFixed(1)}%", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: successRate > 50 ? Colors.green : Colors.red)),
                const SizedBox(height: 24),

                Text("Recommendation: ${data['recommendation']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text(data['prediction_reason'] ?? ''),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    onPressed: () {
                      // Logic to download PDF can go here
                    },
                    child: const Text("DOWNLOAD REPORT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}