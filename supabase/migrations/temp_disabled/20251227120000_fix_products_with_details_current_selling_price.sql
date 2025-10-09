-- Fix products_with_details view to use current_selling_price column name
-- This aligns with the Product model expectation for current_selling_price field

BEGIN;

-- Drop existing view if it exists
DROP VIEW IF EXISTS public.products_with_details CASCADE;

-- Create a minimal products table for local testing if it doesn't exist
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL,
    sku TEXT,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    company_id UUID,
    attributes JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    is_banned BOOLEAN DEFAULT false,
    image_url TEXT,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    min_stock_level INTEGER DEFAULT 0
);

-- Create a minimal companies table for local testing if it doesn't exist
CREATE TABLE IF NOT EXISTS public.companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL,
    name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create a minimal product_batches table for local testing if it doesn't exist
CREATE TABLE IF NOT EXISTS public.product_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL,
    product_id UUID REFERENCES products(id),
    batch_number TEXT,
    quantity INTEGER DEFAULT 0,
    cost_price NUMERIC DEFAULT 0,
    received_date TIMESTAMPTZ DEFAULT NOW(),
    expiry_date DATE,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create a minimal seasonal_prices table for local testing if it doesn't exist
CREATE TABLE IF NOT EXISTS public.seasonal_prices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL,
    product_id UUID REFERENCES products(id),
    selling_price NUMERIC DEFAULT 0,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Now recreate the view with correct column naming
CREATE VIEW public.products_with_details AS
SELECT
    p.id,
    p.store_id,
    p.sku,
    p.name,
    p.category,
    p.company_id,
    p.attributes,
    p.is_active,
    p.is_banned,
    p.image_url,
    p.description,
    p.created_at,
    p.updated_at,
    p.min_stock_level,

    -- Computed fields from attributes for convenience
    CASE
        WHEN p.category = 'FERTILIZER' THEN (p.attributes->>'npk_ratio')
        ELSE NULL
    END as npk_ratio,

    CASE
        WHEN p.category = 'PESTICIDE' THEN (p.attributes->>'active_ingredient')
        ELSE NULL
    END as active_ingredient,

    CASE
        WHEN p.category = 'SEED' THEN (p.attributes->>'strain')
        ELSE NULL
    END as seed_strain,

    -- Company name from join
    COALESCE(c.name, 'Unknown Company') as company_name,

    -- Current available stock (sum of available batches)
    COALESCE(stock.available_stock, 0) as available_stock,

    -- FIXED: Current active price (renamed to match Product model expectation)
    COALESCE(price.current_price, 0) as current_selling_price

FROM public.products p
LEFT JOIN public.companies c ON p.company_id = c.id
LEFT JOIN (
    -- Calculate available stock from product_batches
    SELECT
        product_id,
        SUM(quantity) AS available_stock
    FROM public.product_batches
    WHERE is_available = true
      AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE)
    GROUP BY product_id
) stock ON stock.product_id = p.id
LEFT JOIN (
    -- Get current active price from seasonal_prices
    SELECT DISTINCT ON (product_id)
        product_id,
        selling_price AS current_price
    FROM public.seasonal_prices
    WHERE start_date <= CURRENT_DATE
      AND end_date >= CURRENT_DATE
      AND is_active = true
    ORDER BY product_id, start_date DESC
) price ON price.product_id = p.id;

-- Grant permissions
GRANT SELECT ON public.products_with_details TO authenticated;
GRANT SELECT ON public.products_with_details TO anon;

-- Add comment for documentation
COMMENT ON VIEW public.products_with_details IS 'Multi-tenant aware view of products with enriched data (stock, price, company). Uses current_selling_price column name to match Product model expectations.';

-- Insert some test data for local development
INSERT INTO public.products (id, store_id, sku, name, category, company_id, min_stock_level) VALUES
('550e8400-e29b-41d4-a716-446655440001', '0cf92076-0e10-4984-bd5d-f4b56937e9c0', 'ADC1', 'ADC1 Product', 'FERTILIZER', null, 10),
('550e8400-e29b-41d4-a716-446655440002', '0cf92076-0e10-4984-bd5d-f4b56937e9c0', 'ADC2', 'ADC2 Product', 'FERTILIZER', null, 10),
('550e8400-e29b-41d4-a716-446655440003', '0cf92076-0e10-4984-bd5d-f4b56937e9c0', 'ADC3', 'ADC3 Product', 'FERTILIZER', null, 10)
ON CONFLICT (id) DO NOTHING;

-- Insert some test stock data
INSERT INTO public.product_batches (product_id, store_id, quantity, batch_number) VALUES
('550e8400-e29b-41d4-a716-446655440001', '0cf92076-0e10-4984-bd5d-f4b56937e9c0', 100, 'BATCH-001'),
('550e8400-e29b-41d4-a716-446655440002', '0cf92076-0e10-4984-bd5d-f4b56937e9c0', 100, 'BATCH-002'),
('550e8400-e29b-41d4-a716-446655440003', '0cf92076-0e10-4984-bd5d-f4b56937e9c0', 100, 'BATCH-003')
ON CONFLICT (id) DO NOTHING;

-- Insert some test prices
INSERT INTO public.seasonal_prices (product_id, store_id, selling_price, start_date, end_date) VALUES
('550e8400-e29b-41d4-a716-446655440001', '0cf92076-0e10-4984-bd5d-f4b56937e9c0', 15000, '2025-01-01', '2025-12-31'),
('550e8400-e29b-41d4-a716-446655440002', '0cf92076-0e10-4984-bd5d-f4b56937e9c0', 25000, '2025-01-01', '2025-12-31'),
('550e8400-e29b-41d4-a716-446655440003', '0cf92076-0e10-4984-bd5d-f4b56937e9c0', 35000, '2025-01-01', '2025-12-31')
ON CONFLICT (id) DO NOTHING;

COMMIT;