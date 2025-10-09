import 'package:supabase_flutter/supabase_flutter.dart';

// Test script to verify local database view fix
void main() async {
  print('🧪 Testing local Supabase database fix...');

  try {
    // Initialize Supabase with local config
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      anonKey: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
    );

    final client = Supabase.instance.client;
    
    print('✅ Connected to local Supabase');

    // Test 1: Check if products_with_details view exists
    print('\n📊 Testing view structure...');
    
    final viewTest = await client
        .from('products_with_details')
        .select('id, name, current_selling_price')
        .limit(1);
    
    print('✅ View query successful: ${viewTest.length} rows');

    // Test 2: Test the actual ProductService query that was failing
    print('\n🔍 Testing ProductService-style query...');
    
    final productServiceQuery = await client
        .from('products_with_details')
        .select('''
          id, sku, name, category, company_id, attributes, is_active, is_banned,
          image_url, description, created_at, updated_at, min_stock_level, npk_ratio,
          active_ingredient, seed_strain, current_selling_price, available_stock,
          company_name, store_id
        ''')
        .eq('is_active', true)
        .limit(3);

    print('✅ ProductService query successful!');
    print('📦 Found ${productServiceQuery.length} products:');
    
    for (var product in productServiceQuery) {
      print('  - ${product['name']}: ${product['current_selling_price']}đ (stock: ${product['available_stock']})');
    }

    // Test 3: Test search query (the one that was causing the error)
    print('\n🔍 Testing search query...');
    
    final searchQuery = await client
        .from('products_with_details')
        .select('*')
        .or('name.ilike.%ADC%,sku.ilike.%ADC%')
        .eq('is_active', true)
        .gt('available_stock', 0)
        .order('name', ascending: true)
        .limit(10);

    print('✅ Search query successful!');
    print('📦 Search found ${searchQuery.length} products:');
    
    for (var product in searchQuery) {
      print('  - ${product['name']} (${product['sku']}): ${product['current_selling_price']}đ');
    }

    print('\n🎉 All tests passed! The fix is working correctly.');
    print('💡 The view now uses "current_selling_price" column name as expected by Product model.');

  } catch (e) {
    print('❌ Test failed: $e');
    print('💡 This likely means the column naming issue is not fully resolved.');
  }
}