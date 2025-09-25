-- =============================================================================
-- MIGRATION: ADD PURCHASE ORDER TABLES CHO NHẬP LÔ SỈ
-- =============================================================================
-- File này để mày copy vào Supabase SQL Editor

-- =====================================================
-- 1. PURCHASE ORDERS TABLE - ĐƠN NHẬP HÀNG
-- =====================================================
CREATE TABLE purchase_orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  supplier_id UUID NOT NULL REFERENCES companies(id), -- Dùng companies table
  po_number TEXT UNIQUE, -- Số PO tự generate
  order_date DATE DEFAULT CURRENT_DATE,
  expected_delivery_date DATE,
  delivery_date DATE, -- Ngày nhận hàng thực tế
  status TEXT CHECK (status IN ('DRAFT', 'SENT', 'CONFIRMED', 'DELIVERED', 'CANCELLED')) DEFAULT 'DRAFT',
  subtotal DECIMAL(15,2) DEFAULT 0,
  tax_amount DECIMAL(15,2) DEFAULT 0,
  total_amount DECIMAL(15,2) DEFAULT 0,
  discount_amount DECIMAL(15,2) DEFAULT 0,
  payment_terms TEXT, -- Net 30, Cash, etc.
  notes TEXT,
  created_by TEXT, -- User ID hoặc username
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Business constraints
  CHECK (total_amount >= 0),
  CHECK (subtotal >= 0),
  CHECK (expected_delivery_date >= order_date OR expected_delivery_date IS NULL)
);

-- Indexes cho performance
CREATE INDEX idx_purchase_orders_supplier ON purchase_orders (supplier_id);
CREATE INDEX idx_purchase_orders_status ON purchase_orders (status);
CREATE INDEX idx_purchase_orders_date ON purchase_orders (order_date DESC);
CREATE INDEX idx_purchase_orders_po_number ON purchase_orders (po_number);

-- =====================================================
-- 2. PURCHASE ORDER ITEMS TABLE - CHI TIẾT SẢN PHẨM
-- =====================================================
CREATE TABLE purchase_order_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_cost DECIMAL(10,2) NOT NULL CHECK (unit_cost >= 0),
  total_cost DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
  received_quantity INTEGER DEFAULT 0 CHECK (received_quantity >= 0),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Business constraint: không nhận quá số đặt
  CHECK (received_quantity <= quantity)
);

-- Indexes cho queries
CREATE INDEX idx_po_items_po ON purchase_order_items (purchase_order_id);
CREATE INDEX idx_po_items_product ON purchase_order_items (product_id);

-- =====================================================
-- 3. AUTO-UPDATE PO TOTALS TRIGGER
-- =====================================================
CREATE OR REPLACE FUNCTION update_po_totals()
RETURNS TRIGGER AS $$
BEGIN
  -- Tính lại totals cho PO
  UPDATE purchase_orders 
  SET 
    subtotal = (
      SELECT COALESCE(SUM(total_cost), 0) 
      FROM purchase_order_items 
      WHERE purchase_order_id = COALESCE(NEW.purchase_order_id, OLD.purchase_order_id)
    ),
    total_amount = (
      SELECT COALESCE(SUM(total_cost), 0) 
      FROM purchase_order_items 
      WHERE purchase_order_id = COALESCE(NEW.purchase_order_id, OLD.purchase_order_id)
    ) - COALESCE(discount_amount, 0) + COALESCE(tax_amount, 0),
    updated_at = NOW()
  WHERE id = COALESCE(NEW.purchase_order_id, OLD.purchase_order_id);
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger tự động update totals
CREATE TRIGGER trigger_update_po_totals
  AFTER INSERT OR UPDATE OR DELETE ON purchase_order_items
  FOR EACH ROW EXECUTE FUNCTION update_po_totals();

-- =====================================================
-- 4. AUTO-GENERATE PO NUMBER FUNCTION
-- =====================================================
CREATE OR REPLACE FUNCTION generate_po_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.po_number IS NULL THEN
    NEW.po_number := 'PO' || TO_CHAR(NEW.order_date, 'YYYYMMDD') || '-' || 
                     LPAD(nextval('po_sequence')::TEXT, 3, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Sequence cho PO number
CREATE SEQUENCE IF NOT EXISTS po_sequence START 1;

-- Trigger tự động generate PO number
CREATE TRIGGER trigger_generate_po_number
  BEFORE INSERT ON purchase_orders
  FOR EACH ROW EXECUTE FUNCTION generate_po_number();

-- =====================================================
-- 5. BUSINESS LOGIC FUNCTIONS
-- =====================================================

-- Function tạo product batches từ PO khi delivered
CREATE OR REPLACE FUNCTION create_batches_from_po(po_id UUID)
RETURNS INTEGER AS $$
DECLARE
  po_record RECORD;
  item_record RECORD;
  batch_count INTEGER := 0;
BEGIN
  -- Get PO info
  SELECT * INTO po_record FROM purchase_orders WHERE id = po_id;
  
  IF po_record.status != 'DELIVERED' THEN
    RAISE EXCEPTION 'PO must be DELIVERED status to create batches';
  END IF;
  
  -- Loop through PO items
  FOR item_record IN 
    SELECT * FROM purchase_order_items WHERE purchase_order_id = po_id
  LOOP
    -- Create product batch
    INSERT INTO product_batches (
      product_id,
      batch_number,
      quantity,
      cost_price,
      received_date,
      supplier_batch_id,
      notes
    ) VALUES (
      item_record.product_id,
      po_record.po_number || '-' || item_record.product_id,
      item_record.received_quantity,
      item_record.unit_cost,
      po_record.delivery_date,
      po_record.po_number,
      'Auto-created from PO: ' || po_record.po_number
    );
    
    batch_count := batch_count + 1;
  END LOOP;
  
  RETURN batch_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. VIEWS CHO REPORTING
-- =====================================================

-- View PO với supplier info
CREATE OR REPLACE VIEW purchase_orders_with_details AS
SELECT 
  po.*,
  c.name as supplier_name,
  c.phone as supplier_phone,
  c.contact_person as supplier_contact,
  COUNT(poi.id) as items_count,
  SUM(poi.quantity) as total_quantity,
  SUM(poi.received_quantity) as total_received
FROM purchase_orders po
LEFT JOIN companies c ON po.supplier_id = c.id  
LEFT JOIN purchase_order_items poi ON po.id = poi.purchase_order_id
GROUP BY po.id, c.id;

-- View pending deliveries
CREATE OR REPLACE VIEW pending_deliveries AS
SELECT 
  po.*,
  c.name as supplier_name,
  (po.expected_delivery_date - CURRENT_DATE) as days_until_delivery
FROM purchase_orders po
LEFT JOIN companies c ON po.supplier_id = c.id
WHERE po.status IN ('SENT', 'CONFIRMED')
  AND po.expected_delivery_date >= CURRENT_DATE
ORDER BY po.expected_delivery_date ASC;

-- =====================================================
-- 7. RLS POLICIES (OPTIONAL - TÙY SECURITY REQUIREMENTS)
-- =====================================================

-- Enable RLS nếu cần
-- ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;

-- Basic policies (uncomment nếu cần)
-- CREATE POLICY "Enable read access for authenticated users" ON purchase_orders
--   FOR SELECT USING (auth.role() = 'authenticated');

-- =====================================================
-- 8. SAMPLE DATA FOR TESTING
-- =====================================================

-- Insert sample PO (uncomment để test)
/*
INSERT INTO purchase_orders (supplier_id, expected_delivery_date, notes)
SELECT 
  id,
  CURRENT_DATE + INTERVAL '7 days',
  'Sample purchase order for testing'
FROM companies 
WHERE name LIKE '%Đầu Trâu%' 
LIMIT 1;

-- Insert sample PO items
INSERT INTO purchase_order_items (purchase_order_id, product_id, quantity, unit_cost)
SELECT 
  po.id,
  p.id,
  100,
  45000
FROM purchase_orders po, products p
WHERE po.notes LIKE '%testing%' 
  AND p.name LIKE '%NPK%'
LIMIT 1;
*/
