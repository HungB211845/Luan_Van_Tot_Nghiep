-- Migration: Fix create_batches_from_po price override bug
-- Date: 2025-10-20
-- Issue: Function was overriding correct default unit prices with base unit prices
-- Solution: Remove redundant price update logic (price already set during PO creation)

-- Drop existing function
DROP FUNCTION IF EXISTS public.create_batches_from_po(UUID);

-- Recreate function WITHOUT price update logic
CREATE OR REPLACE FUNCTION public.create_batches_from_po(po_id UUID)
RETURNS INTEGER AS $$
DECLARE
  po_record RECORD;
  item_record RECORD;
  batch_count INTEGER := 0;
  new_batch_number TEXT;
  user_store_id UUID;
  total_received_quantity INTEGER := 0;
BEGIN
  -- 1. Get current user's store_id for security
  SELECT store_id INTO user_store_id
  FROM public.user_profiles
  WHERE id = auth.uid();

  IF user_store_id IS NULL THEN
    RAISE EXCEPTION 'User not associated with any store';
  END IF;

  -- 2. Get PO info with lock để tránh race condition
  SELECT po.*, c.name as supplier_name
  INTO po_record
  FROM public.purchase_orders po
  LEFT JOIN public.companies c ON po.supplier_id = c.id
  WHERE po.id = po_id
    AND po.store_id = user_store_id
  FOR UPDATE OF po;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purchase Order not found or access denied: %', po_id;
  END IF;

  -- 3. Check PO status - Allow both CONFIRMED and DELIVERED
  IF po_record.status NOT IN ('CONFIRMED', 'DELIVERED') THEN
    RAISE EXCEPTION 'PO must be in CONFIRMED or DELIVERED status to receive items. Current status: %',
    po_record.status;
  END IF;

  -- 4. Loop through PO items to create batches
  FOR item_record IN
    SELECT poi.*
    FROM public.purchase_order_items poi
    WHERE poi.purchase_order_id = po_id
      AND poi.store_id = user_store_id
      AND poi.quantity > poi.received_quantity
    ORDER BY poi.created_at
  LOOP
    -- Create unique batch number with date
    new_batch_number := COALESCE(po_record.po_number, 'PO') || '-' ||
                       (SELECT COALESCE(SUBSTRING(sku FROM 1 FOR 6), 'PROD')
                        FROM public.products WHERE id = item_record.product_id) || '-' ||
                       to_char(CURRENT_DATE, 'YYMMDD');

    -- Create product batch
    INSERT INTO public.product_batches (
      product_id, batch_number, quantity, cost_price,
      received_date, purchase_order_id, supplier_id, store_id,
      notes, is_available, is_deleted
    ) VALUES (
      item_record.product_id,
      new_batch_number,
      item_record.quantity - item_record.received_quantity,
      item_record.unit_cost,
      COALESCE(po_record.delivery_date::date, CURRENT_DATE),
      po_id,
      po_record.supplier_id,
      user_store_id,
      'Auto-created from PO: ' || COALESCE(po_record.po_number, po_id::text),
      true,
      false
    );

    -- ✅ REMOVED: Price update logic (old lines 74-96)
    -- Price is already updated correctly during PO creation via updateCurrentSellingPrice()
    -- Removing this prevents incorrect override of default unit prices with base unit prices
    --
    -- Previous bug:
    -- - purchase_order_items.selling_price stores BASE UNIT price (e.g. 15k/kg)
    -- - products.current_selling_price should store DEFAULT UNIT price (e.g. 750k/Bao)
    -- - Old code directly copied base unit price → products table, causing wrong display
    --
    -- Fix:
    -- - Price is set correctly during PO creation with proper unit conversion
    -- - No need to update again during PO receipt (batch creation)
    -- - This function should only create batches, not manage prices

    -- Update the received quantity for the PO item
    UPDATE public.purchase_order_items
    SET received_quantity = item_record.quantity
    WHERE id = item_record.id;

    batch_count := batch_count + 1;
  END LOOP;

  -- 5. Update the overall PO status based on received quantities
  SELECT SUM(received_quantity) INTO total_received_quantity
  FROM public.purchase_order_items
  WHERE purchase_order_id = po_id;

  IF total_received_quantity >= (
    SELECT SUM(quantity)
    FROM public.purchase_order_items
    WHERE purchase_order_id = po_id
  ) THEN
    -- All items fully received - mark as DELIVERED
    UPDATE public.purchase_orders
    SET status = 'DELIVERED',
        delivery_date = COALESCE(delivery_date, CURRENT_DATE),
        updated_at = NOW()
    WHERE id = po_id;
  ELSE
    IF po_record.status = 'DELIVERED' THEN
      UPDATE public.purchase_orders
      SET updated_at = NOW()
      WHERE id = po_id;
    END IF;
  END IF;

  RAISE NOTICE 'Successfully created % batches from PO %', batch_count, COALESCE(po_record.po_number, po_id::text);

  RETURN batch_count;

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error processing PO delivery: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comment explaining the fix
COMMENT ON FUNCTION public.create_batches_from_po(UUID) IS
'Creates product batches from purchase order items when receiving goods.
Fixed 2025-10-20: Removed price update logic to prevent incorrect override of default unit prices.
Price updates should only happen during PO creation via updateCurrentSellingPrice() RPC.';
