import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/base_service.dart';
import '../../../shared/utils/tax_code_validator.dart';
import '../../../shared/services/tax_code_api_client.dart';
import '../models/store_business_info.dart';

class StoreBusinessInfoService extends BaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get store business info for current user's store
  Future<StoreBusinessInfo?> getStoreBusinessInfo() async {
    try {
      ensureAuthenticated();
      final storeId = getValidStoreId();

      final response = await _supabase
          .from('store_business_info')
          .select()
          .eq('store_id', storeId)
          .maybeSingle();

      if (response == null) return null;

      return StoreBusinessInfo.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi lấy thông tin hộ kinh doanh: $e');
    }
  }

  /// Create or update store business info
  ///
  /// If record exists for store_id, update it. Otherwise, create new.
  Future<StoreBusinessInfo> createOrUpdateStoreBusinessInfo(
    StoreBusinessInfo info,
  ) async {
    try {
      ensureAuthenticated();
      final storeId = getValidStoreId();

      // Validate tax code format
      if (!TaxCodeValidator.isValidFormat(info.taxCode)) {
        throw Exception('Mã số thuế không đúng định dạng (phải có 10 hoặc 13 chữ số)');
      }

      // Clean tax code
      final cleanedTaxCode = TaxCodeValidator.clean(info.taxCode);

      // Check if record exists
      final existing = await _supabase
          .from('store_business_info')
          .select('id')
          .eq('store_id', storeId)
          .maybeSingle();

      final data = {
        'store_id': storeId,
        'tax_code': cleanedTaxCode,
        'business_name': info.businessName,
        'tax_authority': info.taxAuthority,
        'business_address': info.businessAddress,
        'phone_number': info.phoneNumber,
        'email': info.email,
        'bank_account': info.bankAccount,
        'bank_name': info.bankName,
        'legal_representative': info.legalRepresentative,
        'validated_at': info.validatedAt?.toIso8601String(),
        'validation_source': info.validationSource,
      };

      final Map<String, dynamic> response;

      if (existing != null) {
        // Update existing record
        response = await _supabase
            .from('store_business_info')
            .update(data)
            .eq('id', existing['id'])
            .select()
            .single();
      } else {
        // Insert new record
        response = await _supabase
            .from('store_business_info')
            .insert(data)
            .select()
            .single();
      }

      return StoreBusinessInfo.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi lưu thông tin hộ kinh doanh: $e');
    }
  }

  /// Validate tax code format (client-side validation)
  bool validateTaxCodeFormat(String taxCode) {
    return TaxCodeValidator.isValidFormat(taxCode);
  }

  /// Fetch tax code info from public API
  ///
  /// Returns Map with auto-filled data if found:
  /// - business_name
  /// - tax_authority
  /// - address
  /// - legal_representative
  ///
  /// Returns null if not found or API unavailable
  Future<Map<String, String>?> fetchTaxCodeInfo(String taxCode) async {
    try {
      // Validate format first
      if (!TaxCodeValidator.isValidFormat(taxCode)) {
        throw Exception('Mã số thuế không đúng định dạng');
      }

      final cleanedTaxCode = TaxCodeValidator.clean(taxCode);

      // Call API
      final taxCodeInfo = await TaxCodeApiClient.lookup(cleanedTaxCode);

      if (taxCodeInfo == null) {
        return null; // Not found
      }

      // Return auto-fill data
      return {
        'business_name': taxCodeInfo.businessName,
        if (taxCodeInfo.taxAuthority != null)
          'tax_authority': taxCodeInfo.taxAuthority!,
        if (taxCodeInfo.address != null) 'address': taxCodeInfo.address!,
        if (taxCodeInfo.legalRepresentative != null)
          'legal_representative': taxCodeInfo.legalRepresentative!,
      };
    } catch (e) {
      throw Exception('Lỗi tra cứu mã số thuế: $e');
    }
  }

  /// Delete store business info (for current user's store)
  Future<void> deleteStoreBusinessInfo() async {
    try {
      ensureAuthenticated();
      final storeId = getValidStoreId();

      await _supabase
          .from('store_business_info')
          .delete()
          .eq('store_id', storeId);
    } catch (e) {
      throw Exception('Lỗi xóa thông tin hộ kinh doanh: $e');
    }
  }

  /// Check if store has business info configured
  Future<bool> hasBusinessInfo() async {
    try {
      final info = await getStoreBusinessInfo();
      return info != null && info.isComplete;
    } catch (e) {
      return false;
    }
  }
}
