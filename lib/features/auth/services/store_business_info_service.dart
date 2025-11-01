import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/base_service.dart';
import '../../../shared/utils/tax_code_validator.dart';
import '../../../shared/services/tax_code_api_client.dart';
import '../../../shared/models/tax_code_lookup_result.dart';
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
        'bank_branch': info.bankBranch,
        'legal_representative': info.legalRepresentative,
        'validated_at': info.validatedAt?.toIso8601String(),
        'validation_source': info.validationSource,
        'invoice_symbol': info.invoiceSymbol,
        'invoice_template_code': info.invoiceTemplateCode,
        'default_vat_rate': info.defaultVatRate,
        'revenue_tax_rate': info.revenueTaxRate,
        'website': info.website,
        'logo_url': info.logoUrl,
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

  /// Fetch tax code info from public APIs (VietQR → masothue)
  ///
  /// Returns TaxCodeLookupResult with source information if found
  /// Returns null if not found in any source
  Future<TaxCodeLookupResult?> fetchTaxCodeInfo(String taxCode) async {
    try {
      // Validate format first
      if (!TaxCodeValidator.isValidFormat(taxCode)) {
        throw Exception('Mã số thuế không đúng định dạng');
      }

      final cleanedTaxCode = TaxCodeValidator.clean(taxCode);

      // Call API with cascade fallback (VietQR → masothue)
      final result = await TaxCodeApiClient.lookup(cleanedTaxCode);

      return result; // May be null if not found in any source
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
