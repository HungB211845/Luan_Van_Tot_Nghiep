import 'package:flutter/material.dart';

class StoreSetupScreen extends StatelessWidget {
  const StoreSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết lập cửa hàng')),
      body: const Center(child: Text('Khai báo thông tin cửa hàng lần đầu')),
    );
  }
}
