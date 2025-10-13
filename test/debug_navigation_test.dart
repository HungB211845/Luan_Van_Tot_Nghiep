// Kiểm tra debug navigation for adding products
// Chạy file này để test nút + thêm sản phẩm

import 'package:flutter/material.dart';

class NavigationTestWidget extends StatelessWidget {
  const NavigationTestWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Navigation'),
        actions: [
          // Test button giống như trong product_list_screen.dart
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              print('DEBUG: Nút + được nhấn');
              print('DEBUG: Đang điều hướng đến /add-product-step1');
              Navigator.pushNamed(context, '/add-product-step1')
                  .then((result) {
                    print('DEBUG: Kết quả navigation: $result');
                  })
                  .catchError((error) {
                    print('DEBUG: Lỗi navigation: $error');
                  });
            },
            tooltip: 'Thêm sản phẩm',
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Test Navigation'),
            SizedBox(height: 20),
            Text('Nhấn nút + ở trên để test điều hướng'),
          ],
        ),
      ),
    );
  }
}
