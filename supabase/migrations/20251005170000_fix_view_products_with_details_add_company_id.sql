-- Migration to fix the products_with_details view by re-adding the company_id
-- and other essential columns that were removed by a previous rollback.

BEGIN;

-- It's safer to drop and recreate to avoid potential dependency issues.
DROP VIEW IF EXISTS public.products_with_details CASCADE;

-- Recreate the view using the correct definition from the original migration.
CREATE VIEW public.products_with_details AS
SELECT
    p.id,
    p.store_id,
    p.sku,
    p.name,
    p.category,
    p.company_id, -- <<< CỘT BỊ THIẾU ĐÂY
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
    c.name as company_name,

    -- Current available stock (sum of available batches)
    COALESCE(stock.available_stock, 0) as available_stock,

    -- Current active price (from seasonal_prices)
    COALESCE(price.current_price, 0) as current_price

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

-- Add comment for documentation
COMMENT ON VIEW public.products_with_details IS 'Multi-tenant aware view of products with enriched data (stock, price, company). Includes company_id and store_id for RLS filtering.';

COMMIT;
