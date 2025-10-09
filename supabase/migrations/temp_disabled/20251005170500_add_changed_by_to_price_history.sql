-- Add the missing changed_by column to the price_history table
-- This column was likely removed during a previous destructive rollback.

BEGIN;

-- Add the column, making it a foreign key to auth.users for data integrity.
ALTER TABLE public.price_history
ADD COLUMN changed_by UUID REFERENCES auth.users(id);

-- Add a comment for future reference.
COMMENT ON COLUMN public.price_history.changed_by IS 'ID of the user who made the price change.';

COMMIT;
