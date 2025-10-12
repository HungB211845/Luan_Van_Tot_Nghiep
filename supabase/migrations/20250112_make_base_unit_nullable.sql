-- =============================================================================
-- MIGRATION: Make base_unit Column Nullable
-- Version: 1.0
-- Date: 2025-01-12
-- Description: Remove NOT NULL constraint from products.base_unit column
--              to support backward compatibility with existing products
--              and allow optional base unit specification
-- =============================================================================

-- =====================================================
-- ALTER TABLE: Make base_unit nullable
-- =====================================================
-- Problem: Database still has NOT NULL constraint on base_unit
--          but Dart model is nullable → crashes on edit/update
-- Fix: Drop NOT NULL constraint to allow existing products
--      without base_unit to remain valid
-- =====================================================

ALTER TABLE public.products
ALTER COLUMN base_unit DROP NOT NULL;

-- =====================================================
-- UPDATE COMMENT
-- =====================================================
COMMENT ON COLUMN public.products.base_unit IS
'Base unit for inventory tracking (kg, ml, lít, chai, gói, bao, etc). Nullable for backward compatibility with existing products. Use effectiveBaseUnit in Dart model for fallback to ''đơn vị'' when null.';

-- =====================================================
-- VERIFICATION QUERY
-- =====================================================
-- Run this to verify the change:
-- SELECT column_name, is_nullable, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'products' AND column_name = 'base_unit';
-- Expected: is_nullable = 'YES'

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- Summary:
-- ✅ Removed NOT NULL constraint from products.base_unit
-- ✅ Existing products with base_unit = NULL are now valid
-- ✅ New products can omit base_unit (will use 'đơn vị' default in app)
-- ✅ Dart model Product.baseUnit (nullable) now matches DB schema
-- =====================================================
