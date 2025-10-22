# Invoice Functions Deployment Guide

**Version:** 1.0
**Date:** 2025-10-22
**Purpose:** Deploy invoice upgrade database functions to Supabase

---

## I. OVERVIEW

Guide này hướng dẫn deploy 3 RPC functions cho invoice & report export system:

1. **`get_invoice_data`** - Transaction invoice data với VAT
2. **`get_po_invoice_data`** - Purchase order invoice data với VAT
3. **`get_transactions_for_export`** - Excel export data với VAT

---

## II. PRE-DEPLOYMENT CHECKLIST

### Required Files

Ensure các files sau tồn tại trong project:

```
supabase/invoice/
├── migrations/
│   └── 20251022_extend_store_business_info_for_vat.sql
└── functions/
    ├── get_invoice_data.sql
    ├── get_po_invoice_data.sql
    └── get_transactions_for_export.sql
```

### Database Migration

**CRITICAL: Phải chạy migration TRƯỚC KHI deploy functions!**

Migration adds 6 columns cần thiết:
- `invoice_symbol`
- `invoice_template_code`
- `bank_branch`
- `default_vat_rate`
- `website`
- `logo_url`

---

## III. DEPLOYMENT METHODS

### Method 1: Supabase Dashboard (Recommended)

**Step 1: Run Migration**

1. Login vào Supabase Dashboard
2. Navigate: **SQL Editor**
3. Click **+ New Query**
4. Copy toàn bộ nội dung file:
   `supabase/invoice/migrations/20251022_extend_store_business_info_for_vat.sql`
5. Paste vào SQL Editor
6. Click **Run** (hoặc Ctrl/Cmd + Enter)
7. Verify success: "Success. No rows returned"

**Step 2: Deploy Function 1 - get_invoice_data**

1. New Query trong SQL Editor
2. Copy toàn bộ nội dung file:
   `supabase/invoice/functions/get_invoice_data.sql`
3. Paste và Run
4. Verify: "Success. No rows returned"

**Step 3: Deploy Function 2 - get_po_invoice_data**

1. New Query
2. Copy file: `get_po_invoice_data.sql`
3. Paste và Run
4. Verify success

**Step 4: Deploy Function 3 - get_transactions_for_export**

1. New Query
2. Copy file: `get_transactions_for_export.sql`
3. Paste và Run
4. Verify success

---

### Method 2: Supabase CLI

**Prerequisites:**
```bash
# Install Supabase CLI nếu chưa có
npm install -g supabase

# Link to remote project
supabase link --project-ref <your-project-ref>
```

**Deploy Commands:**

```bash
# Navigate to project root
cd /path/to/agricultural_pos

# Run migration
supabase db push

# Deploy functions (if using migrations directory structure)
# hoặc run manually via SQL Editor
```

**Note:** Supabase CLI khó deploy individual SQL files trong `functions/` directory. Recommend dùng Dashboard method.

---

## IV. VERIFICATION STEPS

### 1. Verify Migration Success

**Query:**
```sql
SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns
WHERE table_name = 'store_business_info'
AND column_name IN ('invoice_symbol', 'invoice_template_code',
                    'bank_branch', 'default_vat_rate', 'website', 'logo_url')
ORDER BY column_name;
```

**Expected Result:** 6 rows returned với correct types:
```
invoice_symbol          | character varying | 20
invoice_template_code   | character varying | 20
bank_branch             | character varying | 255
default_vat_rate        | numeric           | NULL
website                 | character varying | 255
logo_url                | character varying | 500
```

---

### 2. Verify Function: get_invoice_data

**Query:**
```sql
-- Check function exists
SELECT proname, proargtypes, prosrc
FROM pg_proc
WHERE proname = 'get_invoice_data';
```

**Expected:** 1 row returned

**Test Function:**
```sql
-- Replace <transaction-id> với real transaction UUID
SELECT * FROM get_invoice_data('<transaction-id>');
```

**Expected JSON Structure:**
```json
{
  "store_info": { ... },
  "transaction": { ... },
  "customer": { ... },
  "items": [
    {
      "product_name": "...",
      "quantity": 10,
      "sub_total": 10000000,
      "tax_rate": 5.0,
      "tax_amount": 500000,
      "gross_amount": 10500000
    }
  ],
  "vat_total": 500000
}
```

---

### 3. Verify Function: get_po_invoice_data

**Query:**
```sql
-- Check function exists
SELECT proname FROM pg_proc WHERE proname = 'get_po_invoice_data';
```

**Test Function:**
```sql
SELECT * FROM get_po_invoice_data('<po-id>');
```

**Expected JSON Structure:**
```json
{
  "store_info": { ... },
  "purchase_order": {
    "po_number": "...",
    "payment_method": "TM/CK",
    ...
  },
  "supplier": {
    "name": "...",
    "tax_code": "...",
    "address": "...",
    ...
  },
  "items": [
    {
      "product_name": "...",
      "quantity": 100,
      "price_at_sale": 50000,
      "sub_total": 5000000,
      "tax_rate": 5.0,
      "tax_amount": 250000,
      "gross_amount": 5250000
    }
  ],
  "vat_total": 250000
}
```

**IMPORTANT:** Items array MUST be present! Đây là fix cho bug cũ.

---

### 4. Verify Function: get_transactions_for_export

**Query:**
```sql
SELECT proname FROM pg_proc WHERE proname = 'get_transactions_for_export';
```

**Test Function:**
```sql
SELECT * FROM get_transactions_for_export(
  '2025-10-01'::DATE,
  '2025-10-31'::DATE
);
```

**Expected:** JSON array của transactions:
```json
[
  {
    "transaction": {
      "id": "...",
      "invoice_number": "INV20251022...",
      "payment_method": "cash",
      "total_amount": 10000000
    },
    "customer_name": "Nguyễn Văn A",
    "items": [
      {
        "product_name": "...",
        "tax_rate": 5.0,
        "tax_amount": 500000,
        "gross_amount": 10500000
      }
    ]
  }
]
```

---

### 5. Verify VAT Calculations

**Manual Calculation Test:**

Chọn 1 transaction, manually verify:
```sql
SELECT
  ti.sub_total,
  sbi.default_vat_rate,
  -- Manual calculation
  ROUND((ti.sub_total * sbi.default_vat_rate / 100)::numeric, 0) AS expected_tax,
  -- RPC result
  (SELECT (items->0->>'tax_amount')::numeric
   FROM get_invoice_data(t.id)) AS actual_tax
FROM transaction_items ti
JOIN transactions t ON ti.transaction_id = t.id
JOIN store_business_info sbi ON sbi.store_id = t.store_id
LIMIT 1;
```

**Expected:** `expected_tax` = `actual_tax`

---

## V. TROUBLESHOOTING

### Error: "function does not exist"

**Cause:** Function chưa được deploy hoặc deploy failed

**Fix:**
1. Re-run SQL script trong Dashboard
2. Check for syntax errors trong error message
3. Verify correct `$$` delimiters (NOT single `$`)

---

### Error: "column does not exist: default_vat_rate"

**Cause:** Migration chưa được run

**Fix:**
1. Run migration file TRƯỚC functions
2. Verify migration với query trong section IV.1

---

### Error: "relation purchase_order_items does not exist"

**Cause:** Database schema khác tên table

**Fix:**
Check actual table name:
```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name LIKE '%order%item%';
```

Update function code nếu tên khác.

---

### VAT Calculations Wrong

**Debug Steps:**

1. Check store's default_vat_rate:
```sql
SELECT default_vat_rate
FROM store_business_info
WHERE store_id = '<your-store-id>';
```

2. Check function logic:
```sql
-- Should be: tax_amount = sub_total * tax_rate / 100
-- NOT: tax_amount = sub_total * tax_rate
```

3. Verify ROUND() function:
```sql
-- Should round to integer VND
ROUND((sub_total * rate / 100)::numeric, 0)
```

---

### Function Returns NULL

**Possible Causes:**

1. **Wrong store_id:** User không thuộc store
   ```sql
   SELECT store_id FROM user_profiles WHERE id = auth.uid();
   ```

2. **RLS Policies:** Functions use `SECURITY DEFINER` nên should bypass RLS, nhưng verify:
   ```sql
   SELECT * FROM purchase_orders WHERE id = '<po-id>';
   -- Nếu empty → RLS issue
   ```

3. **Missing Data:** Transaction/PO không tồn tại
   ```sql
   SELECT COUNT(*) FROM transactions WHERE id = '<transaction-id>';
   ```

---

## VI. ROLLBACK PROCEDURE

Nếu cần rollback (undo deployment):

### Rollback Functions Only

```sql
-- Drop functions (keeps data intact)
DROP FUNCTION IF EXISTS public.get_invoice_data(UUID);
DROP FUNCTION IF EXISTS public.get_po_invoice_data(UUID);
DROP FUNCTION IF EXISTS public.get_transactions_for_export(DATE, DATE);
```

### Rollback Migration (DANGEROUS)

**⚠️ WARNING: Sẽ xóa data trong 6 columns mới!**

```sql
-- Remove columns
ALTER TABLE public.store_business_info
  DROP COLUMN IF EXISTS invoice_symbol,
  DROP COLUMN IF EXISTS invoice_template_code,
  DROP COLUMN IF EXISTS bank_branch,
  DROP COLUMN IF EXISTS default_vat_rate,
  DROP COLUMN IF EXISTS website,
  DROP COLUMN IF EXISTS logo_url;
```

**Only do this nếu:**
- Chưa có data trong columns
- Muốn start over hoàn toàn

---

## VII. POST-DEPLOYMENT TESTING

### Flutter App Testing

**1. Test Transaction Invoice Generation:**
```dart
// Trong transaction_detail_screen.dart
// Tap "In hóa đơn" → Choose PDF
// Verify:
// - PDF generates without errors
// - VAT calculations correct
// - Vietnamese characters render correctly
```

**2. Test PO Invoice Generation:**
```dart
// Trong PO detail screen
// Generate PDF/Excel
// Verify items array present và correct
```

**3. Test Excel Export:**
```dart
// Trong invoice_settings_screen.dart
// Export transaction report
// Verify:
// - 2 sheets present (Tổng hợp + Chi tiết)
// - VAT columns correct
// - Calculations accurate
```

---

## VIII. PERFORMANCE NOTES

**Expected Query Times:**

- `get_invoice_data`: < 200ms cho transaction với 10 items
- `get_po_invoice_data`: < 200ms cho PO với 20 items
- `get_transactions_for_export`: < 1s cho 100 transactions

**Nếu slower:**

1. Check database indexes:
```sql
-- Ensure indexes exist
CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction_id
  ON transaction_items(transaction_id);

CREATE INDEX IF NOT EXISTS idx_purchase_order_items_po_id
  ON purchase_order_items(purchase_order_id);
```

2. Check Supabase plan limits (free tier có rate limiting)

---

## IX. SECURITY CONSIDERATIONS

**Functions use `SECURITY DEFINER`:**
- Bypass RLS policies
- Run với permissions của function owner (postgres)
- **CRITICAL:** Must validate `store_id` internally!

**Current Security Measures:**

```sql
-- Every function checks:
SELECT store_id INTO v_store_id
FROM public.user_profiles
WHERE id = auth.uid();

IF v_store_id IS NULL THEN
  RAISE EXCEPTION 'User not associated with any store';
END IF;

-- Then filters all queries by v_store_id
WHERE store_id = v_store_id
```

**DO NOT:**
- Remove `store_id` checks
- Expose functions to `anon` role (only `authenticated`)
- Return data across stores

---

## X. SUCCESS CHECKLIST

Trước khi declare deployment successful:

- [ ] Migration applied successfully
- [ ] 6 new columns exist trong `store_business_info`
- [ ] All 3 functions deployed without errors
- [ ] Functions return data (not NULL)
- [ ] VAT calculations verified manually
- [ ] Items array present trong PO function (critical fix)
- [ ] Flutter app can generate PDF invoices
- [ ] Excel export works với 2 sheets
- [ ] No breaking changes to existing features
- [ ] Network connectivity stable (separate issue)

---

## XI. SUPPORT

**Common Issues:**

- **Network Timeout:** Không phải function issue → See `NETWORK_TROUBLESHOOTING.md`
- **Syntax Errors:** Check `$$` delimiters
- **Missing Data:** Verify migration ran first
- **Wrong Calculations:** Check `default_vat_rate` value

**For Help:**
- Review testing guide: `TESTING_INVOICE_UPGRADE.md`
- Check function source code trong `supabase/invoice/functions/`
- Verify against legal requirements: NĐ 123/2020, TT 32/2025

---

**Deployment Guide Version:** 1.0
**Last Updated:** 2025-10-22
**Maintained By:** Development Team
