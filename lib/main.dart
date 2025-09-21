import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/customer_provider.dart';
import 'providers/product_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/customers/customer_list_screen.dart';
import 'screens/products/product_list_screen.dart';
import 'screens/pos/pos_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://paidjvxqwhrlhlfetjqv.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhaWRqdnhxd2hybGhsZmV0anF2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgyMDA3NzQsImV4cCI6MjA3Mzc3Njc3NH0.T2tmN-D-Y1kJre4Ys-McsKW46615mqEcTgIIz-_yaDA',
  );

  runApp(MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: MaterialApp(
        title: 'Agricultural POS',
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),

        // === BẮT ĐẦU PHẦN THÊM MỚI ===
        locale: const Locale('vi', 'VN'), // Đặt ngôn ngữ mặc định là tiếng Việt
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('vi', 'VN'), // Hỗ trợ tiếng Việt
          Locale('en', 'US'), // Hỗ trợ tiếng Anh (dự phòng)
        ],
        // === KẾT THÚC PHẦN THÊM MỚI ===

        home: HomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isConnected = false;
  String _status = 'Đang kiểm tra kết nối...';

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    try {
      // Test connection bằng cách ping Supabase
      final response = await supabase
          .from('_test_connection')
          .select('*')
          .limit(1);

      setState(() {
        _isConnected = true;
        _status = 'Kết nối Supabase thành công! ✅';
      });
    } catch (error) {
      setState(() {
        _isConnected = false;
        _status = 'Lỗi kết nối: ${error.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agricultural POS'),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isConnected ? Icons.check_circle : Icons.error,
              size: 100,
              color: _isConnected ? Colors.green : Colors.red,
            ),
            SizedBox(height: 20),
            Text(
              'Cửa Hàng Nông Nghiệp',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _isConnected ? Colors.green : Colors.red,
              ),
            ),
            SizedBox(height: 30),
            if (_isConnected) ...[
              // === NÚT BÁN HÀNG POS ===
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const POSScreen()),
                  );
                },
                icon: const Icon(Icons.point_of_sale, size: 28),
                label: const Text('Bán Hàng (POS)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor, // Màu xanh lá chủ đạo
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20), // Thêm khoảng cách
              // === KẾT THÚC PHẦN THÊM ===

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomerListScreen(),
                    ),
                  );
                },
                child: Text('Quản Lý Khách Hàng'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Đổi màu để phân biệt
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductListScreen(),
                    ),
                  );
                },
                child: Text('Quản Lý Sản Phẩm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange, // Đổi màu để phân biệt
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _checkConnection,
                child: Text('Thử Lại Kết Nối'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
