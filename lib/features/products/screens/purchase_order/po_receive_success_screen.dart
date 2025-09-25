import 'package:flutter/material.dart';
import '../../../../core/routing/route_names.dart';

class POReceiveSuccessScreen extends StatelessWidget {
  final String? poNumber;
  const POReceiveSuccessScreen({super.key, this.poNumber});

  @override
  Widget build(BuildContext context) {
    Future.microtask(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.purchaseOrders,
          (route) => route.isFirst || route.settings.name == RouteNames.home,
        );
      }
    });

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Đã nhận hàng thành công',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (poNumber != null) ...[
                const SizedBox(height: 8),
                Text('PO: $poNumber'),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    RouteNames.purchaseOrders,
                    (route) => route.isFirst || route.settings.name == RouteNames.home,
                  );
                },
                child: const Text('Về danh sách Đơn nhập hàng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
