import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store.dart';

class StoreService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Store> createStore({
    required String storeCode,
    required String storeName,
    required String ownerName,
    String? email,
    String? phone,
    String? address,
    String? businessLicense,
    String? taxCode,
  }) async {
    final row = await _supabase
        .from('stores')
        .insert({
          'store_code': storeCode,
          'store_name': storeName,
          'owner_name': ownerName,
          'email': email,
          'phone': phone,
          'address': address,
          'business_license': businessLicense,
          'tax_code': taxCode,
          'subscription_type': 'free',
          'is_active': true,
        })
        .select()
        .single();
    return Store.fromJson(row);
  }

  Future<Store?> getStoreByCode(String storeCode) async {
    final row = await _supabase
        .from('stores')
        .select()
        .eq('store_code', storeCode)
        .maybeSingle();
    return row != null ? Store.fromJson(row) : null;
  }

  Future<Store?> getStoreById(String id) async {
    final row = await _supabase
        .from('stores')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row != null ? Store.fromJson(row) : null;
  }

  Future<bool> isStoreCodeAvailable(String storeCode) async {
    final row = await _supabase
        .from('stores')
        .select('id')
        .eq('store_code', storeCode)
        .maybeSingle();
    return row == null;
  }

  Future<Store> updateStore(Store store) async {
    final row = await _supabase
        .from('stores')
        .update(store.toJson())
        .eq('id', store.id)
        .select()
        .single();
    return Store.fromJson(row);
  }
}
