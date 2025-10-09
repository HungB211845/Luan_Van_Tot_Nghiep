-- Recreate the low_stock_products view which was dropped as a dependency.
-- This view is used for dashboard alerts.

CREATE OR REPLACE VIEW public.low_stock_products AS
SELECT
    p.id,
    p.store_id,
    p.name,
    p.sku,
    p.category,
    p.min_stock_level,
    pwd.available_stock AS current_stock,
    c.name AS company_name,
    p.is_active
FROM public.products p
LEFT JOIN public.products_with_details pwd ON p.id = pwd.id
LEFT JOIN public.companies c ON p.company_id = c.id
WHERE p.is_active = true
  AND pwd.available_stock IS NOT NULL
  AND p.min_stock_level IS NOT NULL
  AND pwd.available_stock <= p.min_stock_level;

-- Grant permissions
GRANT SELECT ON public.low_stock_products TO authenticated;
