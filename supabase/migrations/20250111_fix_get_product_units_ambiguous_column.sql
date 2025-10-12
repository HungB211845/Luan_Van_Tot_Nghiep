-- =============================================================================
-- MIGRATION: Fix Ambiguous Column Error in RPC Functions
-- Version: 1.1 (Hotfix)
-- Date: 2025-01-11
-- Description: Fix "column reference 'id' is ambiguous" error in
--              get_product_units and search_transactions_with_units functions
-- =============================================================================

-- =====================================================
-- FIX 1: get_product_units Function
-- =====================================================
-- Problem: In subquery WHERE clause, column 'id' is ambiguous
--          Could refer to: function output column OR user_profiles.id
-- Fix: Qualify column with table name: user_profiles.id
-- Note: Must DROP first because we're changing return type
-- =====================================================

-- Drop existing function to allow return type change
DROP FUNCTION IF EXISTS public.get_product_units(UUID);

-- Create new function with all required fields
CREATE FUNCTION public.get_product_units(p_product_id UUID)
RETURNS TABLE (
  id UUID,
  product_id UUID,
  unit_name TEXT,
  conversion_factor NUMERIC,
  unit_price NUMERIC,
  is_default_selling_unit BOOLEAN,
  is_active BOOLEAN,
  store_id UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    pu.id,
    pu.product_id,
    pu.unit_name,
    pu.conversion_factor,
    pu.unit_price,
    pu.is_default_selling_unit,
    pu.is_active,
    pu.store_id,
    pu.created_at,
    pu.updated_at
  FROM public.product_units pu
  WHERE pu.product_id = p_product_id
    AND pu.is_active = true
    AND pu.store_id IN (
      SELECT user_profiles.store_id
      FROM public.user_profiles
      WHERE user_profiles.id = auth.uid()
    )
  ORDER BY pu.is_default_selling_unit DESC, pu.unit_name ASC;
END;
$$;

-- =====================================================
-- FIX 2: search_transactions_with_units Function
-- =====================================================
-- Same issue: ambiguous 'id' in subquery
-- Fix: Qualify with table name
-- =====================================================

CREATE OR REPLACE FUNCTION public.search_transactions_with_units(
  p_search_text TEXT DEFAULT ''
)
RETURNS TABLE (
  id UUID,
  customer_name TEXT,
  total_amount NUMERIC,
  transaction_date TIMESTAMPTZ,
  payment_method TEXT,
  items_json JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.id,
    COALESCE(c.name, 'Khách lẻ') AS customer_name,
    t.total_amount,
    t.transaction_date,
    t.payment_method,
    jsonb_agg(
      jsonb_build_object(
        'product_name', p.name,
        'quantity', ti.quantity,
        'unit_name', COALESCE(ti.unit_name, 'đơn vị'),
        'price_at_sale', ti.price_at_sale,
        'sub_total', ti.sub_total
      ) ORDER BY ti.created_at
    ) AS items_json
  FROM public.transactions t
  LEFT JOIN public.customers c ON t.customer_id = c.id
  LEFT JOIN public.transaction_items ti ON t.id = ti.transaction_id
  LEFT JOIN public.products p ON ti.product_id = p.id
  WHERE t.store_id IN (
      SELECT user_profiles.store_id
      FROM public.user_profiles
      WHERE user_profiles.id = auth.uid()
    )
    AND (
      p_search_text = ''
      OR c.name ILIKE '%' || p_search_text || '%'
      OR p.name ILIKE '%' || p_search_text || '%'
      OR t.invoice_number ILIKE '%' || p_search_text || '%'
    )
  GROUP BY t.id, c.name
  ORDER BY t.transaction_date DESC
  LIMIT 100;
END;
$$;

-- =====================================================
-- GRANT PERMISSIONS (Must re-grant after DROP)
-- =====================================================
GRANT EXECUTE ON FUNCTION public.get_product_units(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_transactions_with_units(TEXT) TO authenticated;

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON FUNCTION public.get_product_units(UUID) IS
'Get all active units for a product. FIXED: (1) Ambiguous column error by qualifying user_profiles.id, (2) Added missing fields (product_id, store_id, is_active, created_at, updated_at) to match ProductUnit model.';

COMMENT ON FUNCTION public.search_transactions_with_units(TEXT) IS
'Search transactions with unit information. FIXED: Ambiguous column error by qualifying user_profiles.id.';

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- Summary:
-- ✅ Fixed get_product_units:
--    - Dropped existing function to allow return type change
--    - Qualified 'id' with user_profiles.id (ambiguity fix #1)
--    - Qualified 'store_id' with user_profiles.store_id (ambiguity fix #2)
--    - Added missing fields: product_id, store_id, is_active, created_at, updated_at
--    - Now returns all 10 fields required by ProductUnit Dart model
--    - Re-granted permissions to authenticated users
-- ✅ Fixed search_transactions_with_units:
--    - Qualified 'id' with user_profiles.id (ambiguity fix #1)
--    - Qualified 'store_id' with user_profiles.store_id (ambiguity fix #2)
-- ✅ Fixes ambiguous column errors (id & store_id) AND type cast error
-- =====================================================
