-- ROLLBACK MIGRATION: Restore original products_with_details view
-- This removes the current_selling_price column and restores the previous state
-- Use this if the migration causes issues

BEGIN;

-- Drop the modified view
DROP VIEW IF EXISTS public.products_with_details CASCADE;

-- Restore original view definition (without current_selling_price)
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
  
  CASE
    WHEN p.category = 'FERTILIZER'::text THEN p.attributes ->> 'npk_ratio'::text
    ELSE NULL::text
  END AS npk_ratio,
  
  CASE
    WHEN p.category = 'PESTICIDE'::text THEN p.attributes ->> 'active_ingredient'::text
    ELSE NULL::text
  END AS active_ingredient,
  
  CASE
    WHEN p.category = 'SEED'::text THEN p.attributes ->> 'strain'::text
    ELSE NULL::text
  END AS seed_strain,
  
  c.name AS company_name,
  
  COALESCE(stock.available_stock, 0::bigint) AS available_stock,
  
  -- ORIGINAL: Only current_price from seasonal_prices (no current_selling_price)
  COALESCE(price.current_price, 0::numeric) AS current_price

FROM products p
LEFT JOIN companies c ON p.company_id = c.id
LEFT JOIN (
    SELECT
        product_batches.product_id,
        SUM(product_batches.quantity) AS available_stock
    FROM product_batches
    WHERE product_batches.is_available = true
      AND (product_batches.expiry_date IS NULL OR product_batches.expiry_date > CURRENT_DATE)
    GROUP BY product_batches.product_id
) stock ON stock.product_id = p.id
LEFT JOIN (
    SELECT DISTINCT ON (seasonal_prices.product_id) 
        seasonal_prices.product_id,
        seasonal_prices.selling_price AS current_price
    FROM seasonal_prices
    WHERE seasonal_prices.start_date <= CURRENT_DATE
      AND seasonal_prices.end_date >= CURRENT_DATE
      AND seasonal_prices.is_active = true
    ORDER BY seasonal_prices.product_id, seasonal_prices.start_date DESC
) price ON price.product_id = p.id;

-- Grant permissions
GRANT SELECT ON public.products_with_details TO authenticated;

-- Restore original comment
COMMENT ON VIEW public.products_with_details IS 'Multi-tenant aware view of products with enriched data (stock, price, company). Includes company_id and store_id for RLS filtering.';

COMMIT;