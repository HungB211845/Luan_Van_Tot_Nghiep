import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isConnected = false;
  String _status = 'Đang kiểm tra kết nối...';

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final isConnected = await ConnectivityService.checkSupabaseConnection();
    setState(() {
      _isConnected = isConnected;
      _status = isConnected 
          ? 'Kết nối Supabase thành công! ✅'
          : 'Lỗi kết nối với database';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            _isConnected ? Icons.check_circle : Icons.error,
            size: 60,
            color: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 10),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _isConnected ? Colors.green : Colors.red,
            ),
          ),
          if (!_isConnected) ...[
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _checkConnection,
              child: const Text('Thử Lại'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ],
      ),
    );
  }
}