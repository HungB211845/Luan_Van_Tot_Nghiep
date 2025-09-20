import 'package:flutter/material.dart';

class AddSeasonalPriceScreen extends StatefulWidget {
  const AddSeasonalPriceScreen({Key? key}) : super(key: key);

  @override
  State<AddSeasonalPriceScreen> createState() => _AddSeasonalPriceScreenState();
}

class _AddSeasonalPriceScreenState extends State<AddSeasonalPriceScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm Giá Theo Mùa'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Đang phát triển',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Tính năng thêm giá theo mùa sẽ được bổ sung sau',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}