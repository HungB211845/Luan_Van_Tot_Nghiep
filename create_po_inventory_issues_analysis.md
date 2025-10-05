# Create PO Inventory & Pricing Issues Analysis

## 🔍 IDENTIFIED ISSUES:

### **1. INVENTORY UPDATE PROBLEM:**

#### **Root Cause:**
Create PO chỉ tạo batches khi PO status = 'DELIVERED', nhưng không update selling price cho products.

#### **Current Flow:**
```
Create PO → Status = DRAFT/SENT → No batches created
Receive PO → Status = DELIVERED → create_batches_from_po() → Only creates batches
```

#### **RPC Function `create_batches_from_po`:**
```sql
-- Current RPC only creates batches, NOT updating selling prices
INSERT INTO product_batches (
  product_id,
  batch_number, 
  quantity,
  cost_price,          -- ← Only cost price
  received_date,
  purchase_order_id,
  supplier_id,
  store_id
) VALUES (...);

-- MISSING: Update products.current_selling_price
```

### **2. MISSING SELLING PRICE IN POCartItem:**

#### **POCartItem Structure (Current):**
```dart
class POCartItem {
  final Product product;
  int quantity;
  double unitCost;                    // ← Only cost price
  String? unit;
  
  // MISSING: selling price fields
  // double sellingPrice;             // ← Need this
  // TextEditingController sellingPriceController;  // ← Need this
}
```

#### **Create PO Screen Missing:**
- No selling price input field
- No selling price controller  
- No selling price in form data
- No selling price passed to RPC function

### **3. COMPARISON WITH Quick Add Batch:**

#### **Quick Add Batch (WORKING):**
```dart
// Has both cost and selling price
final _costPriceController = TextEditingController();
final _newSellingPriceController = TextEditingController();

// Updates both inventory and price
await provider.quickAddBatch(
  productId: widget.product.id,
  quantity: quantity,
  costPrice: costPrice,           // ← Updates batch
  newSellingPrice: newSellingPrice, // ← Updates product.current_selling_price
);
```

#### **Create PO (BROKEN):**
```dart
// Only has cost price
final TextEditingController unitCostController;  // Cost only

// Only creates PO items with cost
PurchaseOrderItem(
  unitCost: cartItem.unitCost,  // ← Only cost price
  // MISSING: selling price
);

// RPC only creates batches, doesn't update selling price
await _supabase.rpc('create_batches_from_po', params: {'po_id': poId});
```

## 🛠️ REQUIRED FIXES:

### **Fix 1: Add Selling Price to POCartItem**

#### **Updated POCartItem Class:**
```dart
class POCartItem {
  final Product product;
  int quantity;
  double unitCost;                    // Cost price
  double sellingPrice;                // ← ADD THIS
  String? unit;
  
  final TextEditingController quantityController;
  final TextEditingController unitCostController;
  final TextEditingController sellingPriceController;  // ← ADD THIS

  POCartItem({
    required this.product,
    this.quantity = 1,
    this.unitCost = 0.0,
    this.sellingPrice = 0.0,          // ← ADD THIS
    this.unit,
  }) : quantityController = TextEditingController(text: quantity.toString()),
       unitCostController = TextEditingController(text: unitCost.toStringAsFixed(0)),
       sellingPriceController = TextEditingController(  // ← ADD THIS
         text: sellingPrice > 0 ? sellingPrice.toStringAsFixed(0) : '',
       );

  void dispose() {
    quantityController.dispose();
    unitCostController.dispose(); 
    sellingPriceController.dispose();  // ← ADD THIS
  }
}
```

### **Fix 2: Add Selling Price Field to Create PO Screen**

#### **Add Selling Price Input Field:**
```dart
Widget _buildSellingPriceField(POCartItem item, PurchaseOrderProvider poProvider) {
  return TextFormField(
    controller: item.sellingPriceController,  // ← NEW CONTROLLER
    decoration: const InputDecoration(
      labelText: 'Giá bán (tùy chọn)',       // ← NEW FIELD
      hintText: 'Nhập giá bán',
      border: OutlineInputBorder(),
    ),
    keyboardType: TextInputType.number,
    onChanged: (value) {
      final price = double.tryParse(value);
      if (price != null && price >= 0) {
        poProvider.updatePOCartItem(
          item.product.id, 
          newSellingPrice: price,  // ← NEW PARAMETER
        );
      }
    },
  );
}
```

### **Fix 3: Update RPC Function**

#### **Enhanced `create_batches_from_po` Function:**
```sql
CREATE OR REPLACE FUNCTION create_batches_from_po(po_id UUID)
RETURNS INTEGER AS $$
DECLARE
  item_record RECORD;
  batch_count INTEGER := 0;
BEGIN
  -- Create batches AND update selling prices
  FOR item_record IN
    SELECT poi.*, p.id as product_id
    FROM purchase_order_items poi
    LEFT JOIN products p ON poi.product_id = p.id  
    WHERE poi.purchase_order_id = po_id
    AND poi.quantity > 0
  LOOP
    -- Create batch (existing logic)
    INSERT INTO product_batches (...);
    
    -- ✅ ADD: Update product selling price if provided
    IF item_record.selling_price IS NOT NULL AND item_record.selling_price > 0 THEN
      UPDATE products 
      SET current_selling_price = item_record.selling_price,
          updated_at = NOW()
      WHERE id = item_record.product_id;
      
      -- Add price history entry
      INSERT INTO price_history (
        product_id,
        new_price,
        old_price, 
        reason,
        user_id_who_changed,
        store_id
      ) VALUES (
        item_record.product_id,
        item_record.selling_price,
        (SELECT current_selling_price FROM products WHERE id = item_record.product_id),
        'Updated from Purchase Order: ' || po_record.po_number,
        auth.uid(),
        po_record.store_id
      );
    END IF;
    
    batch_count := batch_count + 1;
  END LOOP;
  
  RETURN batch_count;
END; $$;
```

### **Fix 4: Update PurchaseOrderItem Model**

#### **Add selling_price field to database:**
```sql
ALTER TABLE purchase_order_items 
ADD COLUMN selling_price NUMERIC;
```

#### **Update PurchaseOrderItem Dart model:**
```dart
class PurchaseOrderItem {
  // ... existing fields
  final double? sellingPrice;  // ← ADD THIS

  const PurchaseOrderItem({
    // ... existing parameters
    this.sellingPrice,         // ← ADD THIS
  });
}
```

## 🎯 IMPLEMENTATION STEPS:

### **Step 1: Database Schema**
1. Add `selling_price` column to `purchase_order_items` table
2. Update `create_batches_from_po` RPC function

### **Step 2: Models Update** 
1. Add `sellingPrice` to POCartItem class
2. Add `sellingPriceController` to POCartItem
3. Update PurchaseOrderItem model

### **Step 3: UI Changes**
1. Add selling price field to Create PO screen 
2. Update form layout to show 3 fields: quantity, cost price, selling price
3. Add validation for selling price

### **Step 4: Provider Logic**
1. Update `updatePOCartItem()` to handle selling price
2. Update `createPOFromCart()` to include selling price in items
3. Test inventory update after PO receive

## 💡 EXPECTED RESULTS:

### **After Fixes:**
- ✅ Create PO with both cost price AND selling price
- ✅ Receive PO updates inventory (batches) AND product selling prices
- ✅ PO list shows correct selling prices (not 0)
- ✅ Price history tracks changes from PO
- ✅ Consistent with Quick Add Batch functionality

**The core issue is Create PO only handles cost prices, missing selling price entirely. This requires both frontend UI changes and backend RPC function updates.** 🛠️💰