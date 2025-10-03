-- Migration: Add surcharge_amount column to transactions table
-- Date: 2025-10-03
-- Purpose: Support surcharge fees for debt transactions

-- Add surcharge_amount column to transactions table
ALTER TABLE transactions
ADD COLUMN surcharge_amount NUMERIC DEFAULT 0 NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN transactions.surcharge_amount IS 'Phụ phí được thêm vào giao dịch ghi nợ';

-- Update any existing debt transactions to have explicit 0 surcharge
-- (This is redundant due to DEFAULT 0, but good for clarity)
UPDATE transactions
SET surcharge_amount = 0
WHERE surcharge_amount IS NULL;

-- Verify the column was added correctly
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'transactions' AND column_name = 'surcharge_amount';

-- Note: total_amount will be calculated as base_amount + surcharge_amount
-- where base_amount is the sum of transaction_items.sub_total