# Hướng Dẫn Testing - Invoice & Report Export System Upgrade

**Version:** 1.0
**Date:** 2025-10-22
**Legal Compliance:** Nghị định 123/2020, Nghị định 70/2025, Thông tư 32/2025

---

## I. OVERVIEW

Document này cung cấp comprehensive testing guide cho việc upgrade invoice & report export system của AgriPOS để tuân thủ quy định pháp luật Việt Nam về hóa đơn GTGT.

**Scope của upgrade:**
- Database schema extension với VAT fields
- RPC functions với VAT calculations
- Unicode PDF generation với Roboto fonts
- 2-sheet Excel export (Summary + Detail)
- Auto-share flow after generation
- Invoice fields validation trong store info form

---

## II. PRE-TESTING CHECKLIST

### A. Environment Setup

**1. Database Migration**
- [ ] Chạy migration file: `supabase/invoice/migrations/20251022_extend_store_business_info_for_vat.sql`
- [ ] Verify 6 columns mới trong `store_business_info` table:
  - `invoice_symbol` (VARCHAR 20)
  - `invoice_template_code` (VARCHAR 20)
  - `bank_branch` (VARCHAR 255)
  - `default_vat_rate` (NUMERIC 5,2)
  - `website` (VARCHAR 255)
  - `logo_url` (VARCHAR 500)
- [ ] Verify constraint: `check_vat_rate_range` (0-100%)

**2. RPC Functions**
- [ ] Deploy hoặc replace 3 RPC functions:
  - `get_invoice_data(p_transaction_id UUID)`
  - `get_po_invoice_data(p_po_id UUID)`
  - `get_transactions_for_export(p_start_date TIMESTAMPTZ, p_end_date TIMESTAMPTZ, p_store_id UUID)`

**3. Flutter App**
- [ ] Run `flutter pub get` để ensure dependencies updated
- [ ] Verify Roboto fonts tồn tại trong `assets/fonts/`:
  - `Roboto-Regular.ttf`
  - `Roboto-Bold.ttf`
  - `Roboto-Italic.ttf`
- [ ] Check `pubspec.yaml` có font declarations

**4. Test Data Preparation**
- [ ] Tạo ít nhất 1 store business info record với full invoice fields
- [ ] Tạo 5-10 transactions trong các ngày khác nhau
- [ ] Tạo ít nhất 1 purchase order
- [ ] Set default VAT rate khác nhau (0%, 5%, 10%) để test conditional display

---

## III. TESTING PROCEDURES

### A. Database Layer Testing

#### Test 1: Migration Success
**Objective:** Verify database schema được extend đúng

**Steps:**
1. Connect đến Supabase SQL Editor
2. Run query:
   ```sql
   SELECT column_name, data_type, character_maximum_length
   FROM information_schema.columns
   WHERE table_name = 'store_business_info'
   AND column_name IN ('invoice_symbol', 'invoice_template_code',
                       'bank_branch', 'default_vat_rate', 'website', 'logo_url');
   ```
3. Verify 6 columns returned với correct data types
4. Run query:
   ```sql
   SELECT constraint_name, check_clause
   FROM information_schema.check_constraints
   WHERE constraint_name = 'check_vat_rate_range';
   ```
5. Verify constraint exists với correct range (0-100)

**Expected Result:**
- All 6 columns exist với correct types và lengths
- Constraint enforces 0 ≤ default_vat_rate ≤ 100

---

#### Test 2: RPC Function - get_invoice_data
**Objective:** Verify invoice data được fetch đúng với VAT calculations

**Steps:**
1. Trong SQL Editor, lấy 1 transaction_id từ transactions table
2. Run RPC call:
   ```sql
   SELECT * FROM get_invoice_data('<transaction_id>');
   ```
3. Verify JSON response có structure:
   ```json
   {
     "store_info": {
       "invoice_symbol": "...",
       "invoice_template_code": "...",
       "default_vat_rate": 5.0,
       ...
     },
     "customer": {...},
     "items": [
       {
         "tax_rate": 5.0,
         "tax_amount": 500000,
         "gross_amount": 10500000
       }
     ],
     "vat_total": 500000,
     "total_with_vat": 10500000
   }
   ```
4. Manually verify VAT calculations:
   - `tax_amount = sub_total * tax_rate / 100`
   - `gross_amount = sub_total + tax_amount`
   - `vat_total = SUM of all tax_amounts`

**Expected Result:**
- RPC returns valid JSON
- VAT fields present và correctly calculated
- Store invoice info fields included (invoice_symbol, invoice_template_code, etc.)

---

#### Test 3: RPC Function - get_po_invoice_data
**Objective:** Verify PO invoice data với full supplier info

**Steps:**
1. Lấy 1 purchase_order id
2. Run RPC:
   ```sql
   SELECT * FROM get_po_invoice_data('<po_id>');
   ```
3. Verify response có:
   - `supplier` object với đầy đủ fields (tax_code, address, phone, email, website)
   - `payment_method` field
   - VAT calculations cho items
   - `vat_total` và `total_with_vat`

**Expected Result:**
- Full supplier info returned (không bị NULL)
- VAT calculations chính xác
- Payment method included

---

#### Test 4: RPC Function - get_transactions_for_export
**Objective:** Verify transaction export data với metadata và VAT

**Steps:**
1. Chọn date range có transactions
2. Run RPC:
   ```sql
   SELECT * FROM get_transactions_for_export(
     '2025-10-01'::timestamptz,
     '2025-10-31'::timestamptz,
     '<store_id>'::uuid
   );
   ```
3. Verify mỗi record có:
   - `transaction` object với invoice_number, payment_method, total_amount
   - `items` array với tax_rate, tax_amount, gross_amount cho mỗi item
4. Check transaction metadata được flatten correctly

**Expected Result:**
- All transactions trong range returned
- Items array populated với VAT fields
- Transaction metadata accessible

---

### B. Model Layer Testing

#### Test 5: StoreBusinessInfo Model
**Objective:** Verify model serialization/deserialization với invoice fields

**Test Code:**
```dart
void testStoreBusinessInfoModel() {
  final json = {
    'id': 'test-id',
    'store_id': 'store-id',
    'tax_code': '1234567890',
    'business_name': 'Test Business',
    'invoice_symbol': '1C25TYY',
    'invoice_template_code': '01GTKT3/001',
    'bank_branch': 'Hà Nội Branch',
    'default_vat_rate': 5.0,
    'website': 'https://example.com',
    'logo_url': null,
    // ... other fields
  };

  final model = StoreBusinessInfo.fromJson(json);

  assert(model.invoiceSymbol == '1C25TYY');
  assert(model.invoiceTemplateCode == '01GTKT3/001');
  assert(model.defaultVatRate == 5.0);
  assert(model.bankBranch == 'Hà Nội Branch');
  assert(model.website == 'https://example.com');
  assert(model.isInvoiceReady == true); // Has symbol & template code

  final backToJson = model.toJson();
  assert(backToJson['invoice_symbol'] == '1C25TYY');
}
```

**Expected Result:**
- fromJson() correctly deserializes invoice fields
- toJson() correctly serializes invoice fields
- isInvoiceReady getter returns true when invoice_symbol && invoice_template_code present

---

#### Test 6: InvoiceData Model
**Objective:** Verify invoice data model với VAT totals

**Test Code:**
```dart
void testInvoiceDataModel() {
  final data = InvoiceData(
    // ... basic fields
    totalAmount: 10000000,
    vatTotal: 500000,
    items: [
      InvoiceItemData(
        productName: 'Product 1',
        quantity: 10,
        pricePerDisplayUnit: 1000000,
        subTotal: 10000000,
        taxRate: 5.0,
        taxAmount: 500000,
        grossAmount: 10500000,
      ),
    ],
  );

  assert(data.totalWithVat == 10500000);
  assert(data.items.first.hasTax == true);
  assert(data.items.first.grossAmount == 10500000);
}
```

**Expected Result:**
- totalWithVat computed correctly
- hasTax returns true khi taxRate > 0
- grossAmount = subTotal + taxAmount

---

### C. PDF Generation Testing

#### Test 7: Unicode Font Rendering
**Objective:** Verify Vietnamese characters render correctly trong PDF

**Steps:**
1. Generate PDF invoice với transaction có Vietnamese product names:
   - "Phân bón NPK Việt Nam"
   - "Thuốc trừ sâu Đặc biệt"
   - "Hạt giống lúa ST25"
2. Open generated PDF
3. Verify Vietnamese characters hiển thị đúng (không bị tofu boxes ▯)
4. Check font consistency across title, headers, content

**Expected Result:**
- All Vietnamese characters render correctly
- Dấu thanh (tones) hiển thị chính xác
- Không có missing glyph symbols

---

#### Test 8: VAT Invoice Template Structure
**Objective:** Verify PDF structure tuân thủ NĐ 123/2020

**Steps:**
1. Generate PDF invoice (PDF format)
2. Verify PDF có các phần sau (theo thứ tự):
   - **Header:** Store info (name, address, phone, MST, invoice symbol)
   - **Title:** "HÓA ĐƠN GIÁ TRỊ GIA TĂNG" (bold, centered)
   - **Invoice Metadata:**
     - Ký hiệu: [invoice_symbol]
     - Số: [invoice_number]
     - Ngày: [date]
   - **Two-Column Section:**
     - Left: Buyer info (Đơn vị mua hàng)
     - Right: Seller info (Đơn vị bán hàng)
   - **Items Table (9 columns):**
     - STT | Tên HH-DV | ĐVT | SL | Đơn giá | Thành tiền | Thuế suất (%) | Tiền thuế GTGT | Tổng cộng
   - **Summary Section:**
     - Tổng tiền hàng: [amount]
     - Thuế GTGT: [vat_total]
     - Tổng thanh toán: [total_with_vat]
     - Số tiền bằng chữ: [Vietnamese words]
   - **Signature Blocks:**
     - Người mua hàng | Người bán hàng | Thủ trưởng đơn vị

**Expected Result:**
- All sections present và correctly positioned
- 9-column table với correct headers
- Vietnamese amount words correct

---

#### Test 9: Conditional VAT Display
**Objective:** Verify VAT rows hidden khi VAT = 0%

**Steps:**
1. Set store default_vat_rate = 0
2. Generate PDF invoice
3. Verify:
   - Items table CHỈ có 6 columns (không có Thuế suất, Tiền thuế, Tổng cộng)
   - Summary section KHÔNG có dòng "Thuế GTGT"
   - Vietnamese words for tổng tiền (không mention VAT)

**Expected Result:**
- VAT-related columns/rows ẩn hoàn toàn
- Table structure adjust correctly (không có empty columns)
- Amount words không mention thuế

---

### D. Excel Export Testing

#### Test 10: 2-Sheet Excel Structure
**Objective:** Verify Excel export có 2 sheets với correct structure

**Steps:**
1. Export transactions report (Excel format) với date range có 10+ transactions
2. Open Excel file
3. Verify có 2 sheets:
   - **Sheet 1: "Tổng hợp theo ngày"**
   - **Sheet 2: "Chi tiết hóa đơn"**

**Sheet 1 Verification:**
- Headers (row 1-4):
  - Title: "BÁO CÁO TỔNG HỢP GIAO DỊCH THEO NGÀY VÀ SẢN PHẨM"
  - Store name, MST, period
- Column headers (row 6):
  - Ngày | Tên sản phẩm | Tổng SL | Đơn vị | Tổng tiền hàng | Thuế GTGT | Tổng thanh toán | Số HĐ
- Data rows grouped by (date, product):
  - Multiple transactions cùng ngày + cùng sản phẩm → 1 row với aggregated totals
  - "Số HĐ" column contains semicolon-separated invoice numbers (VD: "INV001; INV002")
- Total row at bottom:
  - Sum of all money columns

**Sheet 2 Verification:**
- Headers (row 1-4): Similar to Sheet 1
- Column headers (row 6):
  - STT | Ngày | Số HĐ | Tên KH | PTTT | Tên SP | SL | ĐVT | Đơn giá | Tiền hàng | Thuế (%) | Tiền thuế | Tổng TT
- Data rows:
  - Each transaction item = 1 row
  - All transaction details visible (không group)
- Total row at bottom

**Expected Result:**
- 2 sheets present với correct names
- Sheet 1: Grouped data với aggregated totals
- Sheet 2: Detailed line-by-line data
- Headers, footers, totals correct
- Money columns formatted với thousand separators
- Date columns formatted dd/MM/yyyy

---

#### Test 11: Excel VAT Calculations
**Objective:** Verify VAT calculations trong Excel correct

**Steps:**
1. Export report với mixed VAT rates (0%, 5%, 10%)
2. Open Excel
3. Manually verify calculations:
   - Sheet 1: Tổng tiền thuế = SUM(tax_amount) cho grouped rows
   - Sheet 2: Tiền thuế = Tiền hàng × Thuế% / 100
   - Both sheets: Tổng TT = Tiền hàng + Tiền thuế
4. Verify total rows match sum of data rows

**Expected Result:**
- All money calculations accurate đến đơn vị đồng
- VAT% displayed correctly (0.0%, 5.0%, 10.0%)
- Totals match manual calculations

---

#### Test 12: Excel Conditional VAT Columns
**Objective:** Verify VAT columns hidden khi không có VAT

**Steps:**
1. Set store default_vat_rate = 0
2. Create transactions (will inherit 0% VAT)
3. Export Excel report
4. Verify cả 2 sheets:
   - KHÔNG có columns "Thuế (%)", "Tiền thuế"
   - Columns adjust accordingly (no empty columns)
   - "Tổng TT" column = "Tiền hàng" (no VAT added)

**Expected Result:**
- VAT columns completely removed khi all transactions have 0% VAT
- Column layout clean (không có gaps)
- Calculations still correct

---

### E. Auto-Share Flow Testing

#### Test 13: Transaction Invoice Auto-Share
**Objective:** Verify auto-share triggers after PDF/Excel generation

**Steps:**
1. Trong transaction detail screen, tap "In hóa đơn"
2. Choose PDF format
3. Wait for generation
4. Verify system share sheet appears AUTOMATICALLY (không cần tap "Chia sẻ")
5. Verify NO success snackbar appears (chỉ có error snackbar nếu fail)
6. Choose share destination (Files, Drive, etc.)
7. Verify file được save correctly
8. Repeat với Excel format

**Expected Result:**
- Share sheet appears ngay sau generation success (không có extra tap)
- No green success snackbar (only red error snackbar on failure)
- File sharing works correctly đến destination

---

#### Test 14: Report Export Auto-Share
**Objective:** Verify auto-share cho transaction reports

**Steps:**
1. Trong invoice settings screen, select date range
2. Tap "Xuất Excel"
3. Wait for export
4. Verify system share sheet appears AUTOMATICALLY
5. Verify NO success snackbar
6. Share file
7. Verify Excel file saved correctly

**Expected Result:**
- Auto-share triggers after export success
- No manual "Chia sẻ" button needed
- No success snackbar (silent success)

---

#### Test 15: Print Flow (PDF Only)
**Objective:** Verify print dialog appears after PDF share

**Steps:**
1. Generate transaction PDF invoice
2. After share sheet appears, complete sharing
3. Verify print dialog appears: "Bạn có muốn in hóa đơn này không?"
4. Tap "In"
5. Verify system print dialog appears
6. Verify PDF preview trong print dialog correct

**Expected Result:**
- Print dialog appears ONLY for PDF (not Excel)
- Print dialog appears AFTER share completes (not during)
- System print dialog shows correct PDF preview

---

### F. Form Validation Testing

#### Test 16: Invoice Symbol Validation
**Objective:** Verify invoice symbol format validation theo TT 32/2025

**Steps:**
1. Trong edit store info screen, scroll đến "THÔNG TIN HÓA ĐƠN ĐIỆN TỬ"
2. Test invalid formats:
   - "123TYY" → Should show error (missing C/K)
   - "C5TYY" → Should show error (year must be 2 digits)
   - "C25XYY" → Should show error (X not valid, must be T/D/L/M)
   - "C25T1" → Should show error (code must be 2-3 chars)
   - "c25tyy" → Should auto-capitalize to "C25TYY"
3. Test valid formats:
   - "1C25TYY" → Should accept (prefix 1 is optional)
   - "C25TAB" → Should accept
   - "K24D123" → Should accept
   - "C25M99" → Should accept

**Expected Result:**
- Validator rejects invalid formats với clear error messages
- Auto-capitalization works
- Valid formats accepted
- Tooltip shows correct format guide

---

#### Test 17: Website URL Validation
**Objective:** Verify website URL format validation

**Steps:**
1. Test invalid URLs:
   - "example.com" → Should show error (missing http://)
   - "ftp://example.com" → Should show error (must be http/https)
   - "http://example com" → Should show error (contains space)
2. Test valid URLs:
   - "http://example.com" → Should accept
   - "https://example.com" → Should accept
   - "https://example.com/page" → Should accept
3. Test empty field → Should accept (optional field)

**Expected Result:**
- Invalid URLs rejected với error message
- Valid http/https URLs accepted
- Empty field accepted (optional)

---

#### Test 18: VAT Rate Slider
**Objective:** Verify VAT rate slider works correctly

**Steps:**
1. Drag slider từ 0% → 10%
2. Verify badge updates in real-time
3. Verify color changes:
   - 0%: Grey badge
   - > 0%: Green badge
4. Tap common values: 0%, 5%, 8%, 10%
5. Verify slider snaps to exact values
6. Save form
7. Reload screen
8. Verify VAT rate persisted correctly

**Expected Result:**
- Slider moves smoothly với 0.5% increments
- Badge shows current value với 1 decimal place
- Color changes based on value
- Value persists after save/reload

---

### G. Edge Cases & Error Handling

#### Test 19: Empty Transaction (No Items)
**Objective:** Verify graceful handling khi transaction không có items

**Steps:**
1. Manually tạo transaction trong DB với no items (or delete items)
2. Attempt to generate PDF invoice
3. Verify error handling

**Expected Result:**
- Error snackbar appears: "Giao dịch không có sản phẩm"
- No crash or infinite loading
- User can dismiss error và retry

---

#### Test 20: Missing Store Business Info
**Objective:** Verify error khi store chưa setup business info

**Steps:**
1. Delete store_business_info record
2. Attempt to generate invoice
3. Verify error message

**Expected Result:**
- Error snackbar: "Chưa cấu hình thông tin hộ kinh doanh"
- User redirected to edit store info screen (hoặc prompt to setup)

---

#### Test 21: Network Timeout During Export
**Objective:** Verify timeout handling cho large exports

**Steps:**
1. Export report với very large date range (100+ transactions)
2. Simulate slow network
3. Verify loading indicator shows progress
4. Verify timeout error handled gracefully

**Expected Result:**
- Loading indicator shows progress percentage
- Timeout error shows clear message
- User can cancel và retry
- No partial files generated

---

#### Test 22: Special Characters trong Product Names
**Objective:** Verify special chars không break PDF/Excel

**Steps:**
1. Create products với special chars:
   - "Sản phẩm & Dịch vụ"
   - "Giá 10,000đ/kg"
   - "Mô tả: "Chất lượng cao""
2. Generate PDF and Excel
3. Verify rendering correct

**Expected Result:**
- Special chars render correctly trong PDF
- Excel cells không bị break
- No encoding issues

---

#### Test 23: Very Long Product Names
**Objective:** Verify text wrapping trong PDF table

**Steps:**
1. Create product với very long name (100+ chars)
2. Generate PDF invoice
3. Verify table cell wraps text correctly
4. Verify không bị overflow ra ngoài page

**Expected Result:**
- Text wraps within cell boundaries
- Row height adjusts automatically
- No text cutoff

---

#### Test 24: Large Money Amounts
**Objective:** Verify number formatting với large amounts

**Steps:**
1. Create transaction với amount > 1 tỷ
2. Generate PDF and Excel
3. Verify formatting:
   - PDF: Thousand separators correct
   - Excel: Cell format correct
   - Vietnamese words: "Một tỷ..."

**Expected Result:**
- Large numbers formatted correctly
- Vietnamese words conversion accurate for billions
- No overflow or truncation

---

## IV. REGRESSION TESTING

### Test 25: Existing Features Still Work
**Objective:** Verify upgrade không break existing functionality

**Checklist:**
- [ ] Transaction creation still works
- [ ] Product CRUD operations still work
- [ ] Customer management still works
- [ ] POS checkout flow still works
- [ ] Old transactions (before upgrade) still viewable
- [ ] Search/filter transactions still works
- [ ] Navigation between screens still works

**Expected Result:**
- All existing features function normally
- No breaking changes introduced

---

## V. PERFORMANCE TESTING

### Test 26: PDF Generation Performance
**Objective:** Verify PDF generation không quá chậm

**Steps:**
1. Generate PDF cho transaction với 50 items
2. Measure time từ tap "In" → share sheet appears
3. Verify < 5 seconds

**Expected Result:**
- Generation completes trong < 5 seconds cho normal-sized invoices
- No UI freeze during generation
- Loading indicator shows smooth animation

---

### Test 27: Excel Export Performance
**Objective:** Verify Excel export với large dataset

**Steps:**
1. Export report với 500+ transactions
2. Measure generation time
3. Verify < 15 seconds

**Expected Result:**
- Export completes trong < 15 seconds
- Progress indicator updates during generation
- File opens correctly trong Excel app

---

## VI. FINAL SIGN-OFF CHECKLIST

Before declaring feature complete, verify ALL of the following:

### Database
- [ ] Migration applied successfully
- [ ] All 3 RPC functions deployed và returning correct data
- [ ] VAT calculations verified manually
- [ ] RLS policies still enforcing store isolation

### Models
- [ ] StoreBusinessInfo fromJson/toJson works
- [ ] InvoiceData model correctly calculates totalWithVat
- [ ] InvoiceItemData hasTax getter works

### PDF
- [ ] Unicode fonts render Vietnamese correctly
- [ ] 9-column VAT invoice structure correct
- [ ] Conditional VAT display works (hidden when 0%)
- [ ] Vietnamese number to words accurate
- [ ] All required sections present

### Excel
- [ ] 2 sheets generated với correct names
- [ ] Sheet 1 groups by (date, product) correctly
- [ ] Sheet 2 shows all details
- [ ] VAT calculations accurate
- [ ] Conditional VAT columns works
- [ ] Totals match sum of data

### Auto-Share Flow
- [ ] PDF auto-share works
- [ ] Excel auto-share works
- [ ] Print dialog appears after PDF share
- [ ] No success snackbars (only error snackbars)

### Form Validation
- [ ] Invoice symbol validation works (TT 32/2025 format)
- [ ] Website URL validation works
- [ ] VAT slider works với real-time updates
- [ ] Form save/load works correctly

### Edge Cases
- [ ] Empty transactions handled
- [ ] Missing store info handled
- [ ] Network timeouts handled
- [ ] Special chars render correctly
- [ ] Large amounts formatted correctly

### Regression
- [ ] All existing features still work
- [ ] No breaking changes
- [ ] Performance acceptable

---

## VII. KNOWN LIMITATIONS

**Current Phase Exclusions:**
1. **Logo Upload:** Logo field exists trong DB but upload UI not implemented. Logo will be NULL for now.
2. **Sequential Invoice Numbering:** Still using timestamp-based invoice numbers (INV20251022...). Sequential numbering not implemented yet.
3. **Multi-Currency:** All amounts in VND. No multi-currency support.
4. **QR Code:** No QR code generation for digital invoices yet.

**Future Enhancements:**
- Logo upload functionality
- Sequential invoice number generation với reset yearly
- Email sending of invoices
- Digital signature for invoices
- QR code generation for invoice verification

---

## VIII. CONTACT & SUPPORT

**For bugs or issues during testing:**
- Create issue trong project repository
- Tag với label: `invoice-upgrade`, `bug`
- Attach screenshots/logs/error messages

**For questions:**
- Refer to specification document: `docs/INVOICE_UPGRADE_SPEC.md`
- Review legal documents: NĐ 123/2020, NĐ 70/2025, TT 32/2025

---

**Testing Document Version:** 1.0
**Last Updated:** 2025-10-22
**Approved By:** Development Team
