-- This migration creates a function to manually add a debt record for a customer,
-- without associating it with a specific sales transaction.

-- To revert this migration, run:
-- DROP FUNCTION IF EXISTS create_manual_debt(uuid, uuid, numeric, text);

CREATE OR REPLACE FUNCTION create_manual_debt(
  p_store_id uuid,
  p_customer_id uuid,
  p_amount numeric,
  p_notes text
)
RETURNS uuid -- Returns the ID of the newly created debt record
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_debt_id uuid;
BEGIN
  -- Validate input
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Debt amount must be greater than zero.';
  END IF;

  -- Insert the new debt record
  INSERT INTO public.debts (
    store_id,
    customer_id,
    original_amount,
    remaining_amount,
    status,
    notes,
    due_date
  )
  VALUES (
    p_store_id,
    p_customer_id,
    p_amount,
    p_amount,
    'pending', -- Corrected status
    'Ghi nợ thủ công: ' || COALESCE(p_notes, ''),
    current_date + interval '30 days' -- Default due date 30 days from now
  )
  RETURNING id INTO new_debt_id;

  -- Return the new debt ID
  RETURN new_debt_id;
END;
$$;
