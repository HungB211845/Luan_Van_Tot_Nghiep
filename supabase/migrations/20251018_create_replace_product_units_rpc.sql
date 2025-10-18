-- Migration: Create replace_product_units RPC function
-- Purpose: Atomically replace all units for a product (prevent zombie units)
-- Date: 2025-10-18
-- Related Issue: Product unit changes causing duplicate active units

-- Function to replace all units for a product in a single transaction
CREATE OR REPLACE FUNCTION replace_product_units(
  p_product_id UUID,
  p_new_units JSONB[]
) RETURNS VOID AS $$
DECLARE
  v_store_id UUID;
  v_unit JSONB;
BEGIN
  -- Get the store_id for this product (for security & multi-tenancy)
  SELECT store_id INTO v_store_id
  FROM products
  WHERE id = p_product_id;

  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'Product not found: %', p_product_id;
  END IF;

  -- Step 1: Deactivate ALL existing units for this product
  -- This prevents "zombie units" from remaining active
  UPDATE product_units
  SET
    is_active = FALSE,
    updated_at = NOW()
  WHERE product_id = p_product_id
    AND store_id = v_store_id;

  -- Step 2: Insert new units (all within same transaction)
  -- Loop through each unit in the input array
  FOREACH v_unit IN ARRAY p_new_units
  LOOP
    INSERT INTO product_units (
      product_id,
      unit_name,
      conversion_factor,
      unit_price,
      is_default_selling_unit,
      is_active,
      store_id,
      created_at,
      updated_at
    ) VALUES (
      p_product_id,
      (v_unit->>'unit_name')::TEXT,
      (v_unit->>'conversion_factor')::NUMERIC,
      (v_unit->>'unit_price')::NUMERIC,
      COALESCE((v_unit->>'is_default_selling_unit')::BOOLEAN, FALSE),
      TRUE, -- All new units are active
      v_store_id, -- Use store_id from product for security
      NOW(),
      NOW()
    );
  END LOOP;

  -- Success: All operations committed atomically
  -- If any step fails, entire transaction is rolled back
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION replace_product_units(UUID, JSONB[]) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION replace_product_units(UUID, JSONB[]) IS
'Atomically replaces all product units for a given product. Deactivates old units and creates new ones in a single transaction to prevent zombie units.';
