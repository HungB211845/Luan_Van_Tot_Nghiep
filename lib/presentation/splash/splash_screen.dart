import 'package:flutter/material.dart';
import '../../core/config/supabase_config.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/route_names.dart';
import '../../shared/services/connectivity_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Đang khởi tạo ứng dụng...';

  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    setState(() {
      _statusMessage = 'Đang kiểm tra kết nối database...';
    });
    final isConnected = await ConnectivityService.checkSupabaseConnection();

    if (mounted) {
      if (isConnected) {
        setState(() {
          _statusMessage = 'Kết nối thành công. Đang tải dữ liệu...';
        });
        // Simulate data loading or other async tasks
        await Future.delayed(const Duration(seconds: 2)); 
        
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(RouteNames.home);
        }
      } else {
        setState(() {
          _statusMessage = 'Lỗi kết nối database. Vui lòng kiểm tra mạng.';
        });
        // Optionally, show a retry button or stay on splash with error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_statusMessage.contains('Lỗi'))
              ElevatedButton(
                onPressed: _initializeAndNavigate,
                child: const Text('Thử Lại'),
              ),
          ],
        ),
      ),
    );
  }
}