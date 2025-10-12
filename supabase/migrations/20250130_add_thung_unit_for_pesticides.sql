-- =============================================================================
-- MIGRATION: ADD THÙNG UNIT FOR PESTICIDES
-- Version: 1.0
-- Date: 2025-01-30
-- Description: Thêm đơn vị "Thùng" cho thuốc BVTV để hỗ trợ nhập hàng theo thùng
-- =============================================================================

-- =====================================================
-- PART 1: ADD THÙNG UNIT FOR EXISTING PESTICIDES
-- =====================================================

-- Thêm đơn vị "Thùng" cho tất cả sản phẩm PESTICIDE hiện có
-- Mỗi thùng chứa 20 chai, mỗi chai 500ml → conversion_factor = 20 * 500 = 10,000
INSERT INTO public.product_units (
  product_id,
  unit_name,
  conversion_factor,
  unit_price,
  is_default_selling_unit,
  store_id
)
SELECT
  p.id AS product_id,
  'Thùng' AS unit_name,
  -- Calculate thùng conversion factor: packageQty × volume per package
  -- Default: 20 chai × 500ml = 10,000ml
  COALESCE((p.attributes->>'packageQty')::NUMERIC, 20) * 
  COALESCE((p.attributes->>'volume')::NUMERIC, 500) AS conversion_factor,
  -- Calculate thùng price: current_selling_price × packageQty
  p.current_selling_price * COALESCE((p.attributes->>'packageQty')::NUMERIC, 20) AS unit_price,
  false AS is_default_selling_unit, -- Thùng is for wholesale, not default selling
  p.store_id
FROM public.products p
WHERE p.category = 'PESTICIDE'
  AND p.is_active = true
  AND NOT EXISTS (
    SELECT 1 FROM public.product_units pu
    WHERE pu.product_id = p.id
      AND pu.unit_name = 'Thùng'
  )
ON CONFLICT (product_id, unit_name, store_id) DO NOTHING;

-- =====================================================
-- PART 2: UPDATE EXISTING PESTICIDE ATTRIBUTES
-- =====================================================

-- Update existing pesticides to include packageQty if not present
-- This helps future edits to work correctly
UPDATE public.products
SET attributes = attributes || jsonb_build_object('packageQty', 20)
WHERE category = 'PESTICIDE'
  AND is_active = true
  AND (attributes->>'packageQty') IS NULL;

-- =====================================================
-- PART 3: VERIFICATION QUERIES (FOR DEBUGGING)
-- =====================================================

-- Query to check the results (uncomment to run manually):
/*
SELECT 
  p.name,
  p.category,
  pu.unit_name,
  pu.conversion_factor,
  pu.unit_price,
  pu.is_default_selling_unit
FROM products p
JOIN product_units pu ON p.id = pu.product_id
WHERE p.category = 'PESTICIDE'
  AND p.is_active = true
ORDER BY p.name, pu.is_default_selling_unit DESC, pu.unit_name;
*/

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- Summary:
-- ✅ Added "Thùng" unit for all existing PESTICIDE products
-- ✅ Updated product attributes to include packageQty
-- ✅ Set correct conversion factors and prices for wholesale units
--
-- Now pesticides have 3 units:
-- 1. "Chai 500ml" (default selling unit, factor = 500)
-- 2. "Thùng" (wholesale unit, factor = 10,000)  
-- 3. "ml" (base unit, factor = 1)
-- =====================================================