import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../lib/core/config/supabase_config.dart';
import '../../lib/features/auth/services/auth_service.dart';
import '../../lib/features/products/services/company_service.dart';
import '../../lib/features/products/services/product_service.dart';
import '../../lib/features/customers/services/customer_service.dart';
import '../../lib/features/pos/services/transaction_service.dart';
import '../../lib/shared/services/base_service.dart';
import '../../lib/features/products/models/company.dart';
import '../../lib/features/products/models/product.dart';
import '../../lib/features/customers/models/customer.dart';

/// Integration test để verify multi-tenant system hoạt động đúng
/// Test data isolation giữa các stores
void main() {
  group('Multi-Tenant System Integration Tests', () {
    late AuthService authService;
    late CompanyService companyService;
    late ProductService productService;
    late CustomerService customerService;
    late TransactionService transactionService;

    setUpAll(() async {
      // Initialize Supabase
      await SupabaseConfig.initialize();
      
      // Initialize services
      authService = AuthService();
      companyService = CompanyService();
      productService = ProductService();
      customerService = CustomerService();
      transactionService = TransactionService();
    });

    group('🔐 Authentication & JWT Claims', () {
      test('should set store_id in JWT app_metadata after login', () async {
        // Test với user thật từ database
        final result = await authService.signInWithEmail(
          'test@example.com', 
          'password123'
        );
        
        expect(result.isSuccess, true);
        expect(result.profile?.storeId, isNotNull);
        
        // Verify JWT contains store_id
        final user = Supabase.instance.client.auth.currentUser;
        expect(user, isNotNull);
        expect(user!.appMetadata?['store_id'], equals(result.profile!.storeId));
        
        print('✅ JWT app_metadata contains store_id: ${user.appMetadata?['store_id']}');
      });

      test('should read store_id from BaseService correctly', () async {
        // Đảm bảo đã login
        final user = Supabase.instance.client.auth.currentUser;
        expect(user, isNotNull);
        
        // Test BaseService đọc store_id từ JWT
        final baseService = companyService; // CompanyService extends BaseService
        final storeId = baseService.currentStoreId;
        
        expect(storeId, isNotNull);
        expect(storeId, isNotEmpty);
        
        print('✅ BaseService.currentStoreId: $storeId');
      });
    });

    group('🏗️ RLS Policies Verification', () {
      test('should only return data for current store', () async {
        // Test Companies
        final companies = await companyService.getCompanies();
        print('✅ Companies returned: ${companies.length}');
        
        // Verify all companies belong to current store
        final currentStoreId = companyService.currentStoreId;
        for (final company in companies) {
          expect(company.storeId, equals(currentStoreId));
        }
        
        // Test Products
        final products = await productService.getProductsPaginated();
        print('✅ Products returned: ${products.items.length}');
        
        // Verify all products belong to current store
        for (final product in products.items) {
          expect(product.storeId, equals(currentStoreId));
        }
        
        // Test Customers
        final customers = await customerService.getCustomers();
        print('✅ Customers returned: ${customers.length}');
        
        // Verify all customers belong to current store
        for (final customer in customers) {
          expect(customer.storeId, equals(currentStoreId));
        }
      });

      test('should prevent creating data without store_id', () async {
        // Test tạo Company without store context
        BaseService.setCurrentUserStoreId(null);
        
        final company = Company(
          id: '',
          name: 'Test Company',
          storeId: '', // Empty store ID
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        expect(
          () async => await companyService.createCompany(company),
          throwsA(isA<Exception>()),
        );
        
        print('✅ Correctly prevented creation without store context');
      });
    });

    group('🔒 Data Isolation Tests', () {
      test('should isolate data between different stores', () async {
        // Giả lập 2 stores khác nhau
        const store1Id = 'store-1-uuid';
        const store2Id = 'store-2-uuid';
        
        // Test với Store 1
        BaseService.setCurrentUserStoreId(store1Id);
        final store1Companies = await companyService.getCompanies();
        
        // Test với Store 2  
        BaseService.setCurrentUserStoreId(store2Id);
        final store2Companies = await companyService.getCompanies();
        
        // Verify data isolation
        final store1Ids = store1Companies.map((c) => c.id).toSet();
        final store2Ids = store2Companies.map((c) => c.id).toSet();
        
        // Should have no overlap
        expect(store1Ids.intersection(store2Ids).isEmpty, true);
        
        print('✅ Store 1 companies: ${store1Companies.length}');
        print('✅ Store 2 companies: ${store2Companies.length}');
        print('✅ No data overlap between stores');
      });
    });

    group('🛡️ Provider Guards', () {
      test('should block operations when store_id is missing', () async {
        // Clear store context
        BaseService.setCurrentUserStoreId(null);
        
        final company = Company(
          id: '',
          name: 'Test Company',
          storeId: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // CompanyProvider should block this
        expect(
          () async => await companyService.createCompany(company),
          throwsA(isA<Exception>()),
        );
        
        print('✅ Provider correctly blocked operation without store context');
      });
    });

    group('📊 Database Function Tests', () {
      test('should verify get_current_user_store_id() function works', () async {
        // Test RPC call to verify function exists and works
        try {
          final result = await Supabase.instance.client
              .rpc('get_current_user_store_id');
          
          expect(result, isNotNull);
          print('✅ get_current_user_store_id() function works: $result');
        } catch (e) {
          fail('get_current_user_store_id() function failed: $e');
        }
      });
    });

    tearDownAll(() async {
      // Cleanup: sign out
      await authService.signOut();
    });
  });
}

/// Helper để tạo test data
class TestDataHelper {
  static Company createTestCompany({required String storeId}) {
    return Company(
      id: '',
      name: 'Test Company ${DateTime.now().millisecondsSinceEpoch}',
      storeId: storeId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Customer createTestCustomer({required String storeId}) {
    return Customer(
      id: '',
      storeId: storeId,
      name: 'Test Customer ${DateTime.now().millisecondsSinceEpoch}',
      debtLimit: 1000000,
      interestRate: 0.5,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
