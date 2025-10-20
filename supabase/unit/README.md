# Unit System Fixes & Rollbacks

This folder contains database migrations and rollback scripts specifically for fixing unit system issues in AgriPOS.

## 📂 Folder Purpose

- **Main migrations:** Located in `/supabase/migrations/` (applied automatically)
- **Rollback scripts:** Located here in `/supabase/unit/` (manual execution only)

## 🐛 Current Fixes

### Fix: create_batches_from_po Price Override Bug (2025-10-20)

**Issue:**
- `create_batches_from_po` RPC was overriding correct default unit prices with base unit prices
- Example: Product set to 750,000 VND/Bao would be overridden to 15,000 VND/kg during PO receipt
- Caused incorrect price display on POS Screen and Product Detail Screen

**Root Cause:**
- `purchase_order_items.selling_price` stores **BASE UNIT price** (e.g., 15k/kg)
- `products.current_selling_price` should store **DEFAULT UNIT price** (e.g., 750k/Bao)
- Function incorrectly copied base unit price directly to products table

**Solution:**
- Removed redundant price update logic from `create_batches_from_po`
- Price is already set correctly during PO creation via `updateCurrentSellingPrice()` RPC
- Function now only creates batches (single responsibility principle)

**Files:**
- **Migration:** `/supabase/migrations/20251020_fix_create_batches_price_override.sql`
- **Rollback:** `/supabase/unit/20251020_rollback_fix_create_batches_price_override.sql`

## 🔄 How to Apply Rollback

If the fix causes issues, restore the original function:

### Using Supabase CLI:
```bash
cd /Users/p/Desktop/LVTN/agricultural_pos
supabase db reset
```

### Using psql:
```bash
psql -d your_database -f supabase/unit/20251020_rollback_fix_create_batches_price_override.sql
```

### Using Supabase Dashboard:
1. Go to SQL Editor
2. Copy contents of rollback file
3. Execute the SQL

## ✅ Verification After Fix

### Test Complete Flow:

1. **Create PO:**
   ```dart
   // Set selling price: 750,000 VND/Bao
   ```

2. **Check Database (after PO creation):**
   ```sql
   SELECT current_selling_price FROM products WHERE name = 'Your Product';
   -- Should be: 750000 ✅
   ```

3. **Receive PO:**
   ```dart
   // Call receivePurchaseOrder() or create_batches_from_po RPC
   ```

4. **Check Database (after PO receipt):**
   ```sql
   SELECT current_selling_price FROM products WHERE name = 'Your Product';
   -- Should STILL be: 750000 ✅ (not overridden to 15000)
   ```

5. **Check UI:**
   - POS Screen: Should show 750,000 VND ✅
   - Product Detail Screen: Should show 750K ✅
   - Unit Selection Sheet: Should show "Bao: 700.000 VND" ✅

### Check Price History:

```sql
SELECT new_price, old_price, reason, changed_at
FROM price_history
WHERE product_id = (SELECT id FROM products WHERE name = 'Your Product' LIMIT 1)
ORDER BY changed_at DESC
LIMIT 5;
```

**Expected result:**
- Only ONE entry from "Updated via Purchase Order creation"
- NO entry from "Updated from PO: PO20251020-XXX" after fix ✅

## 📊 Migration Timeline

| Date | File | Action | Status |
|------|------|--------|--------|
| 2025-10-20 | `20251020_fix_create_batches_price_override.sql` | Remove price update from create_batches_from_po | ✅ Active |
| 2025-10-20 | `20251020_rollback_fix_create_batches_price_override.sql` | Rollback to original function | 📦 Available |

## 🚨 When to Use Rollback

Use rollback ONLY if:
- Batch creation fails after applying fix
- Critical business process breaks
- You need to investigate the fix further

**Note:** The rollback restores the buggy behavior (price override), so use it temporarily while investigating.

## 📝 Best Practices

1. **Always test in staging first**
2. **Keep rollback scripts available**
3. **Document all changes in this README**
4. **Monitor price_history table after migrations**
5. **Verify UI displays correct prices**

## 🔗 Related Files

- Flutter price update: `/lib/features/products/services/product_service.dart:887` (`updateCurrentSellingPrice`)
- Database RPC: `/supabase/migrations/20251011120000_upgrade_update_price_rpc.sql` (`update_product_selling_price`)
- PO creation: `/lib/features/products/providers/purchase_order_provider.dart:1240` (`createPOFromCart`)
- PO receipt: `/lib/features/products/services/purchase_order_service.dart:169` (`receivePurchaseOrder`)

## 💡 Architecture Notes

**Price Update Flow (Correct):**
```
User creates PO with selling price
    ↓
PurchaseOrderProvider.createPOFromCart()
    ↓
ProductService.updateCurrentSellingPrice(defaultUnitPrice)
    ↓
Database RPC: update_product_selling_price(750k)
    ↓
products.current_selling_price = 750k ✅
product_units synced with correct unit prices ✅
```

**Batch Creation Flow (After Fix):**
```
User receives PO
    ↓
PurchaseOrderService.receivePurchaseOrder()
    ↓
Database RPC: create_batches_from_po(po_id)
    ↓
Creates product_batches ✅
Updates received_quantity ✅
Does NOT touch products.current_selling_price ✅
```

## 📚 Additional Resources

- Multi-UOM System Documentation: `/docs/multi-uom-system.md`
- Database Schema: `/supabase/migrations/20250111_multi_unit_system.sql`
- Unit Provider: `/lib/features/products/providers/product_unit_provider.dart`

---

**Last Updated:** 2025-10-20
**Maintained By:** Development Team
**Contact:** For questions about these fixes, consult the CLAUDE.md project instructions.
