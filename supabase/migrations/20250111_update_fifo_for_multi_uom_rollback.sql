-- =============================================================================
-- ROLLBACK: Revert FIFO Function to Original Version
-- Version: 1.0
-- Date: 2025-01-11
-- Description: Rollback update_inventory_fifo_batch to original INT-based version
--              Use this if Multi-UoM update causes issues
-- =============================================================================

-- =====================================================
-- ROLLBACK RPC FUNCTION: update_inventory_fifo_batch
-- =====================================================
-- Restores original function that uses INT for quantities
-- Removes Multi-UoM support (base_unit_quantity)
-- =====================================================

CREATE OR REPLACE FUNCTION update_inventory_fifo_batch(items_json jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    item_record jsonb;
    product_id_param uuid;
    quantity_to_reduce int; -- Original: INT only
    batch_record record;
    remaining_to_reduce int; -- Original: INT only
    updated_batches jsonb := '[]'::jsonb;
    insufficient_stock jsonb := '[]'::jsonb;
    current_user_store_id uuid;
BEGIN
    -- Get current user's store ID
    SELECT store_id INTO current_user_store_id
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF current_user_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    -- Process each item in the batch
    FOR item_record IN SELECT * FROM jsonb_array_elements(items_json)
    LOOP
        product_id_param := (item_record->>'product_id')::uuid;
        quantity_to_reduce := (item_record->>'quantity')::int; -- Original: only uses quantity field
        remaining_to_reduce := quantity_to_reduce;

        -- Get batches for this product ordered by FIFO
        FOR batch_record IN
            SELECT id, quantity, received_date, expiry_date
            FROM product_batches
            WHERE product_id = product_id_param
            AND store_id = current_user_store_id
            AND is_available = true
            AND quantity > 0
            AND (expiry_date IS NULL OR expiry_date > NOW())
            ORDER BY
                received_date ASC,  -- FIFO by receive date
                expiry_date ASC     -- Then by expiry date
            FOR UPDATE -- Lock rows to prevent concurrent updates
        LOOP
            EXIT WHEN remaining_to_reduce <= 0;

            IF batch_record.quantity <= remaining_to_reduce THEN
                -- Use entire batch
                UPDATE product_batches
                SET quantity = 0, updated_at = NOW()
                WHERE id = batch_record.id;

                remaining_to_reduce := remaining_to_reduce - batch_record.quantity;

                updated_batches := updated_batches || jsonb_build_object(
                    'batch_id', batch_record.id,
                    'quantity_used', batch_record.quantity,
                    'remaining_quantity', 0
                );
            ELSE
                -- Use partial batch
                UPDATE product_batches
                SET quantity = quantity - remaining_to_reduce, updated_at = NOW()
                WHERE id = batch_record.id;

                updated_batches := updated_batches || jsonb_build_object(
                    'batch_id', batch_record.id,
                    'quantity_used', remaining_to_reduce,
                    'remaining_quantity', batch_record.quantity - remaining_to_reduce
                );

                remaining_to_reduce := 0;
            END IF;
        END LOOP;

        -- Check if we couldn't fulfill the entire quantity
        IF remaining_to_reduce > 0 THEN
            insufficient_stock := insufficient_stock || jsonb_build_object(
                'product_id', product_id_param,
                'requested_quantity', quantity_to_reduce,
                'available_quantity', quantity_to_reduce - remaining_to_reduce,
                'shortage', remaining_to_reduce
            );
        END IF;
    END LOOP;

    -- Return summary of operations
    RETURN jsonb_build_object(
        'success', true,
        'updated_batches', updated_batches,
        'insufficient_stock', insufficient_stock,
        'updated_at', NOW()
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'updated_batches', updated_batches,
            'insufficient_stock', insufficient_stock
        );
END;
$$;

-- =====================================================
-- COMMENT
-- =====================================================
COMMENT ON FUNCTION update_inventory_fifo_batch(jsonb) IS
'Original FIFO function using INT quantities. Multi-UoM support removed.';

-- =====================================================
-- ROLLBACK COMPLETE
-- =====================================================
-- Summary:
-- ✅ Restored original update_inventory_fifo_batch function
-- ✅ Removed Multi-UoM support (NUMERIC quantities)
-- ✅ Removed COALESCE logic for base_unit_quantity
-- ✅ Function now only accepts integer quantity field
-- =====================================================
