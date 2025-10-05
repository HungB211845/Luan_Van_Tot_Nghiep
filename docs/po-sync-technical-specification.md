# PO-POS-History Synchronization Technical Specification

## 📋 **PROJECT OVERVIEW**

**Objective:** Resolve synchronization issues between Purchase Orders, POS Screen, History Screens, and Product Detail Screen to create a unified, real-time inventory and pricing system.

**Current Issues:**
- Create PO lacks selling price handling
- POS Screen doesn't auto-refresh after PO operations  
- History screens are disconnected from PO workflow
- Missing cross-screen navigation and data links

## 🎯 **IMPLEMENTATION PLAN**

### **PHASE 1: Database Schema & RPC Updates**

#### **Step 1.1: Database Migration**
**File:** `supabase/migrations/20250127_po_sync_enhancement.sql`

**Changes:**
1. Add `selling_price` column to `purchase_order_items` table
2. Update `create_batches_from_po` RPC function
3. Create new views for PO-inventory tracking
4. Add indexes for performance optimization

#### **Step 1.2: Rollback Migration**
**File:** `supabase/migrations/20250127_po_sync_rollback.sql`

**Safety:** Complete rollback procedure to restore original state if issues occur

---

### **PHASE 2: Backend Model Updates**

#### **Step 2.1: Model Enhancements**
1. **PurchaseOrderItem Model:** Add `sellingPrice` field
2. **POCartItem Class:** Add selling price controller and logic
3. **ProductBatch Model:** Ensure PO reference tracking

#### **Step 2.2: Service Layer Updates**
1. **PurchaseOrderService:** Handle selling price in create/receive operations
2. **ProductService:** Add PO-aware price update methods
3. **Event Bus System:** Create global notification system

---

### **PHASE 3: Frontend UI Enhancements**

#### **Step 3.1: Create PO Screen**
- Add selling price input fields
- Update form validation and submission
- Implement responsive design

#### **Step 3.2: PO List & Detail Screens**
- Add inventory impact summaries
- Implement cross-screen navigation
- Show profit margin calculations

#### **Step 3.3: History Screens Integration**
- Add PO references to batch displays
- Implement "View source PO" functionality
- Create bidirectional navigation

---

### **PHASE 4: POS Real-time Sync**

#### **Step 4.1: Event System Integration**
- Implement inventory update event bus
- Add POS auto-refresh on PO completion
- Create user notifications for price updates

#### **Step 4.2: Performance Optimization**
- Optimize product loading strategies
- Implement selective refresh mechanisms
- Add loading states and error handling

---

## 🗃️ **DATABASE SPECIFICATIONS**

### **Migration 1: Schema Updates**

```sql
-- =============================================================================
-- MIGRATION: PO Sync Enhancement - Add Selling Price Support
-- Date: 2025-01-27
-- Author: AgriPOS Development Team
-- =============================================================================

-- 1. Add selling_price to purchase_order_items
ALTER TABLE purchase_order_items 
ADD COLUMN selling_price NUMERIC DEFAULT NULL;

-- 2. Add metadata columns for better tracking
ALTER TABLE purchase_order_items
ADD COLUMN profit_margin NUMERIC DEFAULT NULL,
ADD COLUMN price_updated_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;

-- 3. Create index for performance
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_selling_price 
ON purchase_order_items (selling_price) WHERE selling_price IS NOT NULL;

-- 4. Create view for PO inventory impact
CREATE OR REPLACE VIEW po_inventory_impact AS
SELECT 
    po.id as po_id,
    po.po_number,
    po.status,
    po.delivery_date,
    COUNT(pb.id) as batch_count,
    SUM(pb.quantity) as total_quantity,
    SUM(pb.cost_price * pb.quantity) as total_cost,
    AVG(CASE WHEN poi.selling_price > 0 
        THEN ((poi.selling_price - poi.unit_cost) / poi.unit_cost * 100) 
        ELSE NULL END) as avg_profit_margin
FROM purchase_orders po
LEFT JOIN product_batches pb ON po.id = pb.purchase_order_id
LEFT JOIN purchase_order_items poi ON po.id = poi.purchase_order_id 
    AND pb.product_id = poi.product_id
WHERE po.status = 'DELIVERED'
GROUP BY po.id, po.po_number, po.status, po.delivery_date;
```

### **Migration 2: Enhanced RPC Functions**

```sql
-- Enhanced create_batches_from_po with selling price support
DROP FUNCTION IF EXISTS create_batches_from_po(UUID);

CREATE OR REPLACE FUNCTION create_batches_from_po(po_id UUID)
RETURNS JSON AS $$
DECLARE
    po_record RECORD;
    item_record RECORD;
    batch_count INTEGER := 0;
    price_updates_count INTEGER := 0;
    new_batch_number TEXT;
    old_selling_price NUMERIC;
    batch_id UUID;
BEGIN
    -- Get PO info with supplier
    SELECT po.*, c.name as supplier_name, u.store_id
    INTO po_record
    FROM purchase_orders po
    LEFT JOIN companies c ON po.supplier_id = c.id
    LEFT JOIN user_profiles u ON u.id = auth.uid()
    WHERE po.id = po_id;

    -- Validate PO exists and user has access
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Purchase Order not found or access denied: %', po_id;
    END IF;

    -- Validate PO status
    IF po_record.status != 'DELIVERED' THEN
        RAISE EXCEPTION 'PO must be DELIVERED status, current: %', po_record.status;
    END IF;

    -- Process each PO item
    FOR item_record IN
        SELECT 
            poi.*, 
            p.name as product_name, 
            p.sku as product_sku,
            p.current_selling_price as current_price
        FROM purchase_order_items poi
        LEFT JOIN products p ON poi.product_id = p.id
        WHERE poi.purchase_order_id = po_id
        AND poi.quantity > 0
        AND p.store_id = po_record.store_id  -- Security: store isolation
    LOOP
        -- Generate unique batch number
        new_batch_number := COALESCE(po_record.po_number, 'PO') || '-' || 
                           COALESCE(SUBSTRING(item_record.product_sku FROM 1 FOR 6), 'PROD') || '-' || 
                           LPAD((batch_count + 1)::TEXT, 2, '0');

        -- Create product batch
        INSERT INTO product_batches (
            product_id,
            batch_number,
            quantity,
            cost_price,
            received_date,
            purchase_order_id,
            supplier_id,
            store_id,
            notes
        ) VALUES (
            item_record.product_id,
            new_batch_number,
            item_record.quantity,
            item_record.unit_cost,
            COALESCE(po_record.delivery_date::date, CURRENT_DATE),
            po_id,
            po_record.supplier_id,
            po_record.store_id,
            'Auto-created from PO: ' || COALESCE(po_record.po_number, po_id::text)
        ) RETURNING id INTO batch_id;

        -- ✅ NEW: Update selling price if provided
        IF item_record.selling_price IS NOT NULL AND item_record.selling_price > 0 THEN
            -- Store old price for history
            old_selling_price := item_record.current_price;
            
            -- Update product selling price
            UPDATE products 
            SET 
                current_selling_price = item_record.selling_price,
                updated_at = NOW()
            WHERE id = item_record.product_id 
            AND store_id = po_record.store_id;

            -- Create price history entry
            INSERT INTO price_history (
                product_id,
                new_price,
                old_price,
                reason,
                user_id_who_changed,
                store_id,
                created_at
            ) VALUES (
                item_record.product_id,
                item_record.selling_price,
                old_selling_price,
                'Updated from Purchase Order: ' || COALESCE(po_record.po_number, 'PO-' || po_id::text),
                auth.uid(),
                po_record.store_id,
                NOW()
            );

            -- Update PO item with profit margin
            UPDATE purchase_order_items
            SET 
                profit_margin = CASE 
                    WHEN item_record.unit_cost > 0 
                    THEN ((item_record.selling_price - item_record.unit_cost) / item_record.unit_cost * 100)
                    ELSE NULL 
                END,
                price_updated_at = NOW()
            WHERE id = item_record.id;

            price_updates_count := price_updates_count + 1;
        END IF;

        batch_count := batch_count + 1;
    END LOOP;

    -- Return summary
    RETURN json_build_object(
        'success', true,
        'batches_created', batch_count,
        'prices_updated', price_updates_count,
        'po_number', po_record.po_number,
        'message', format('Created %s batches, updated %s prices', batch_count, price_updates_count)
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'batches_created', 0,
            'prices_updated', 0
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### **Rollback Migration**

```sql
-- =============================================================================
-- ROLLBACK: PO Sync Enhancement
-- Date: 2025-01-27
-- Purpose: Complete rollback to restore original system state
-- =============================================================================

-- 1. Drop new views
DROP VIEW IF EXISTS po_inventory_impact CASCADE;

-- 2. Drop enhanced RPC function and restore original
DROP FUNCTION IF EXISTS create_batches_from_po(UUID);

-- Restore original simple version
CREATE OR REPLACE FUNCTION create_batches_from_po(po_id UUID)
RETURNS INTEGER AS $$
DECLARE
  po_record RECORD;
  item_record RECORD;
  batch_count INTEGER := 0;
  new_batch_number TEXT;
BEGIN
  -- Get PO info
  SELECT po.*, c.name as supplier_name
  INTO po_record
  FROM purchase_orders po
  LEFT JOIN companies c ON po.supplier_id = c.id
  WHERE po.id = po_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purchase Order not found: %', po_id;
  END IF;

  IF po_record.status != 'DELIVERED' THEN
    RAISE EXCEPTION 'PO must be DELIVERED status: %', po_record.status;
  END IF;

  -- Create batches (original logic only)
  FOR item_record IN
    SELECT poi.*, p.name as product_name, p.sku as product_sku
    FROM purchase_order_items poi
    LEFT JOIN products p ON poi.product_id = p.id
    WHERE poi.purchase_order_id = po_id
    AND poi.quantity > 0
  LOOP
    new_batch_number := po_record.po_number || '-' || 
                       SUBSTRING(item_record.product_sku FROM 1 FOR 6) || '-' || 
                       LPAD(batch_count + 1::TEXT, 2, '0');

    INSERT INTO product_batches (
      product_id, batch_number, quantity, cost_price, 
      received_date, purchase_order_id, supplier_id, store_id
    ) VALUES (
      item_record.product_id, new_batch_number, item_record.quantity,
      item_record.unit_cost, CURRENT_DATE, po_id, 
      po_record.supplier_id, po_record.store_id
    );

    batch_count := batch_count + 1;
  END LOOP;

  RETURN batch_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Remove added columns from purchase_order_items
ALTER TABLE purchase_order_items 
DROP COLUMN IF EXISTS selling_price,
DROP COLUMN IF EXISTS profit_margin,
DROP COLUMN IF EXISTS price_updated_at;

-- 4. Drop indexes
DROP INDEX IF EXISTS idx_purchase_order_items_selling_price;

-- 5. Grant permissions
GRANT EXECUTE ON FUNCTION create_batches_from_po(UUID) TO authenticated;
```

---

## 📱 **FRONTEND SPECIFICATIONS**

### **POCartItem Model Enhancement**

```dart
class POCartItem {
  final Product product;
  int quantity;
  double unitCost;
  double sellingPrice;                    // ✅ NEW FIELD
  String? unit;
  
  // Controllers for form inputs
  final TextEditingController quantityController;
  final TextEditingController unitCostController;
  final TextEditingController sellingPriceController;  // ✅ NEW CONTROLLER

  POCartItem({
    required this.product,
    this.quantity = 1,
    this.unitCost = 0.0,
    this.sellingPrice = 0.0,              // ✅ NEW PARAMETER
    this.unit,
  }) : quantityController = TextEditingController(text: quantity.toString()),
       unitCostController = TextEditingController(
         text: unitCost > 0 ? AppFormatter.formatNumber(unitCost) : '',
       ),
       sellingPriceController = TextEditingController(  // ✅ NEW CONTROLLER
         text: sellingPrice > 0 ? AppFormatter.formatNumber(sellingPrice) : '',
       );

  void dispose() {
    quantityController.dispose();
    unitCostController.dispose();
    sellingPriceController.dispose();     // ✅ DISPOSE NEW CONTROLLER
  }

  // ✅ NEW: Calculate profit margin
  double get profitMargin {
    if (unitCost <= 0) return 0;
    return ((sellingPrice - unitCost) / unitCost * 100);
  }

  // ✅ NEW: Validation
  bool get isValid {
    return quantity > 0 && unitCost > 0;
  }

  bool get hasSellingPrice {
    return sellingPrice > 0;
  }
}
```

### **Event Bus System**

```dart
// lib/shared/services/inventory_event_bus.dart
import 'dart:async';

class InventoryUpdateEvent {
  final InventoryUpdateType type;
  final String? poId;
  final List<String> productIds;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  InventoryUpdateEvent({
    required this.type,
    this.poId,
    required this.productIds,
    this.data,
  }) : timestamp = DateTime.now();
}

enum InventoryUpdateType { 
  poReceived, 
  priceUpdated, 
  batchCreated, 
  inventoryAdjusted 
}

class InventoryEventBus {
  static final _controller = StreamController<InventoryUpdateEvent>.broadcast();
  
  static Stream<InventoryUpdateEvent> get stream => _controller.stream;
  
  // Notify when PO is received and batches are created
  static void notifyPOReceived(String poId, List<String> productIds, {Map<String, dynamic>? summary}) {
    _controller.add(InventoryUpdateEvent(
      type: InventoryUpdateType.poReceived,
      poId: poId,
      productIds: productIds,
      data: summary,
    ));
  }
  
  // Notify when product price is updated
  static void notifyPriceUpdated(String productId, double newPrice, {String? reason}) {
    _controller.add(InventoryUpdateEvent(
      type: InventoryUpdateType.priceUpdated,
      productIds: [productId],
      data: {'newPrice': newPrice, 'reason': reason},
    ));
  }
  
  // Notify when new batch is created
  static void notifyBatchCreated(String productId, String batchId, {String? poId}) {
    _controller.add(InventoryUpdateEvent(
      type: InventoryUpdateType.batchCreated,
      productIds: [productId],
      poId: poId,
      data: {'batchId': batchId},
    ));
  }
  
  static void dispose() {
    _controller.close();
  }
}
```

---

## 🧪 **TESTING SPECIFICATIONS**

### **Database Testing**

1. **Migration Testing:**
   - Test forward migration success
   - Test rollback migration success
   - Verify data integrity after migrations
   - Test RPC function with selling prices

2. **Performance Testing:**
   - Test RPC function performance with large datasets
   - Verify index effectiveness
   - Test concurrent PO operations

### **Frontend Testing**

1. **PO Creation Flow:**
   - Test selling price input validation
   - Test profit margin calculations
   - Test form submission with selling prices

2. **Cross-Screen Navigation:**
   - Test PO → Product Detail links
   - Test Batch History → PO links
   - Test event bus notifications

3. **POS Sync Testing:**
   - Test auto-refresh after PO receive
   - Test price update notifications
   - Test selective refresh performance

---

## 🚀 **DEPLOYMENT PLAN**

### **Phase 1: Database (Week 1)**
- Deploy migration with selling price support
- Test RPC functions in staging
- Verify performance with production data volume

### **Phase 2: Backend Models (Week 1)**  
- Update Dart models for selling price
- Implement event bus system
- Update service layer logic

### **Phase 3: UI Updates (Week 2)**
- Update Create PO screen with selling price inputs
- Enhance PO List/Detail screens with inventory impact
- Implement responsive design

### **Phase 4: Integration (Week 2)**
- Connect all screens with event bus
- Implement cross-navigation
- Add real-time sync to POS

### **Phase 5: Testing & Optimization (Week 3)**
- Comprehensive testing across all screens
- Performance optimization
- User acceptance testing

---

## ⚡ **SUCCESS CRITERIA**

✅ **Complete PO Workflow:** Create PO with selling prices → Receive PO → Auto-update inventory & prices → Reflect in POS immediately

✅ **Cross-Screen Integration:** All screens show related data with navigation links (PO ↔ Product ↔ Batches ↔ History)

✅ **Real-time Updates:** No manual refresh needed across any screen after inventory/price changes

✅ **Audit Trail:** Full traceability from PO creation to final sales with profit margin tracking

✅ **Performance:** All operations complete within 3 seconds with proper loading states

✅ **User Experience:** Intuitive navigation, clear profit margin display, helpful notifications

---

## 🔧 **ROLLBACK STRATEGY**

**If Critical Issues Occur:**
1. Run rollback migration to restore original RPC functions
2. Deploy previous frontend version without selling price fields
3. Disable event bus system
4. Restore original PO workflow

**Data Safety:**
- All existing data preserved during rollback
- New selling price data marked as inactive, not deleted
- Price history entries retained for audit purposes

**Recovery Time Objective:** < 30 minutes for complete rollback

---

**This specification provides the complete roadmap for resolving PO-POS-History synchronization issues while maintaining system stability and data integrity.** 🎯🔄💰