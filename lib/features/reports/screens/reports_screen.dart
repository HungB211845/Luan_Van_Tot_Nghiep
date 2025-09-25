import 'package:flutter/material.dart';
import 'package:agricultural_pos/features/products/screens/reports/expiry_report_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Báo cáo hàng sắp hết hạn'),
            leading: const Icon(Icons.warning),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExpiryReportScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
