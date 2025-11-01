-- ============================================================================
-- Ensure low_stock_products view exists with store isolation
-- ============================================================================

BEGIN;

DROP VIEW IF EXISTS public.low_stock_products CASCADE;

CREATE OR REPLACE VIEW public.low_stock_products AS
SELECT
    p.id,
    p.store_id,
    p.name,
    p.sku,
    p.category,
    p.min_stock_level,
    pwd.available_stock AS current_stock,
    pwd.available_stock AS available_stock,
    p.current_selling_price,
    c.name AS company_name,
    p.is_active,
    p.updated_at
FROM public.products AS p
LEFT JOIN public.products_with_details AS pwd
    ON pwd.id = p.id AND pwd.store_id = p.store_id
LEFT JOIN public.companies AS c
    ON c.id = p.company_id AND c.store_id = p.store_id
WHERE p.is_active = true
  AND p.min_stock_level IS NOT NULL
  AND pwd.available_stock IS NOT NULL
  AND pwd.available_stock <= p.min_stock_level;

GRANT SELECT ON public.low_stock_products TO authenticated;

COMMIT;
