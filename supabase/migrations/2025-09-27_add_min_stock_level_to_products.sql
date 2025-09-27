-- Add min_stock_level to products table

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS min_stock_level integer NOT NULL DEFAULT 0;

-- Update existing rows to have a default value if they are NULL
UPDATE public.products
SET min_stock_level = 0
WHERE min_stock_level IS NULL;
