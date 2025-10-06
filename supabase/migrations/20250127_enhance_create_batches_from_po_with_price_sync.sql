-- Recreate function với logic cập nhật giá bán đầy đủ
CREATE OR REPLACE FUNCTION create_batches_from_po(po_id UUID)
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
  FOR UPDATE OF po; -- FIXED: Chỉ định rõ bảng cần khóa

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purchase Order not found or access denied: %', po_id;
  END IF;

  -- 3. Check PO status - Allow both CONFIRMED and DELIVERED
  IF po_record.status NOT IN ('CONFIRMED', 'DELIVERED') THEN
    RAISE EXCEPTION 'PO must be in CONFIRMED or DELIVERED status to receive items. Current status: %',
    po_record.status;
  END IF;

  -- 4. Loop through PO items to create batches and update prices
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

    -- CRITICAL: Update product selling price if provided in PO item
    IF item_record.selling_price IS NOT NULL AND item_record.selling_price > 0 THEN
      -- Update the product's current selling price
      UPDATE public.products
      SET current_selling_price = item_record.selling_price,
          updated_at = NOW()
      WHERE id = item_record.product_id
        AND store_id = user_store_id;

      -- Create price history record for audit trail
      INSERT INTO public.price_history (
        product_id, old_price, new_price,
        changed_at, changed_by, reason, store_id
      ) VALUES (
        item_record.product_id,
        (SELECT current_selling_price FROM public.products WHERE id = item_record.product_id),
        item_record.selling_price,
        NOW(),
        auth.uid(),
        'Updated from PO: ' || COALESCE(po_record.po_number, po_id::text),
        user_store_id
      );
    END IF;

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