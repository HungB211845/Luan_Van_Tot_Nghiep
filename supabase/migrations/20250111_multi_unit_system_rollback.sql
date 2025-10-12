-- =============================================================================
-- ROLLBACK: MULTI-UNIT SYSTEM
-- Version: 1.0
-- Date: 2025-01-11
-- Description: Rollback toàn bộ thay đổi của multi-unit system
-- =============================================================================

-- WARNING: Script này sẽ XÓA toàn bộ data liên quan đến multi-unit system!
-- Chỉ chạy khi cần revert về trạng thái ban đầu.

-- =====================================================
-- STEP 1: DROP RPC FUNCTIONS
-- =====================================================
DROP FUNCTION IF EXISTS public.search_transactions_with_units(TEXT);
DROP FUNCTION IF EXISTS public.check_stock_availability(UUID, NUMERIC, UUID);
DROP FUNCTION IF EXISTS public.get_available_stock_base_unit(UUID);
DROP FUNCTION IF EXISTS public.get_product_units(UUID);

-- =====================================================
-- STEP 2: REMOVE COLUMNS FROM transaction_items
-- =====================================================
ALTER TABLE public.transaction_items
  DROP COLUMN IF EXISTS base_unit_quantity,
  DROP COLUMN IF EXISTS unit_conversion_factor,
  DROP COLUMN IF EXISTS unit_name,
  DROP COLUMN IF EXISTS unit_id;

-- Drop index
DROP INDEX IF EXISTS public.idx_transaction_items_unit_id;

-- =====================================================
-- STEP 3: REMOVE base_unit COLUMN FROM products
-- =====================================================
ALTER TABLE public.products
  DROP COLUMN IF EXISTS base_unit;

-- =====================================================
-- STEP 4: DROP TABLE product_units
-- =====================================================
-- Drop policies first
DROP POLICY IF EXISTS "Store owners manage units" ON public.product_units;
DROP POLICY IF EXISTS "Users view units in their store" ON public.product_units;

-- Drop trigger
DROP TRIGGER IF EXISTS update_product_units_updated_at ON public.product_units;

-- Drop indexes (including the UNIQUE partial index that replaces EXCLUDE constraint)
DROP INDEX IF EXISTS public.product_units_one_default_per_product;
DROP INDEX IF EXISTS public.idx_product_units_store_id;
DROP INDEX IF EXISTS public.idx_product_units_product_id;

-- Drop table (CASCADE will drop all foreign key references)
DROP TABLE IF EXISTS public.product_units CASCADE;

-- =====================================================
-- ROLLBACK COMPLETE
-- =====================================================
-- Summary:
-- ✅ Dropped 4 RPC functions
-- ✅ Removed 4 columns from transaction_items
-- ✅ Removed base_unit column from products
-- ✅ Dropped product_units table with all constraints
-- ✅ Dropped all indexes and policies
--
-- Database reverted to pre-migration state.
-- =====================================================
