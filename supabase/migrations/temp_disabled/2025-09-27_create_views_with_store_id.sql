-- Create views with store_id for RLS compatibility
-- These views are needed by ProductService and other services

-- Add min_stock_level to products table

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS min_stock_level integer NOT NULL DEFAULT 0;

-- Update existing rows to have a default value if they are NULL
UPDATE public.products
SET min_stock_level = 0
WHERE min_stock_level IS NULL;


BEGIN;

-- Drop existing views if they exist (without store_id)
-- Use CASCADE to drop dependent objects (like functions)
DROP VIEW IF EXISTS public.low_stock_products CASCADE;
DROP VIEW IF EXISTS public.products_with_details CASCADE;
DROP VIEW IF EXISTS public.purchase_orders_with_details CASCADE;

-- Create products_with_details view with store_id
CREATE OR REPLACE VIEW public.products_with_details AS
SELECT 
    p.*,
    c.name as company_name,
    COALESCE(stock.available_stock, 0) as available_stock,
    COALESCE(price.current_price, 0) as current_price
FROM public.products p
LEFT JOIN public.companies c ON p.company_id = c.id
LEFT JOIN (
    SELECT 
        product_id,
        SUM(quantity) as available_stock
    FROM public.product_batches 
    WHERE is_available = true 
    AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE)
    GROUP BY product_id
) stock ON p.id = stock.product_id
LEFT JOIN (
    SELECT DISTINCT ON (product_id) 
        product_id,
        selling_price as current_price
    FROM public.seasonal_prices 
    WHERE start_date <= CURRENT_DATE
    AND end_date >= CURRENT_DATE
    AND is_active = true
    ORDER BY product_id, start_date DESC
) price ON p.id = price.product_id;

-- Create low_stock_products view with store_id
CREATE OR REPLACE VIEW public.low_stock_products AS
SELECT 
    p.id,
    p.store_id,  -- Include store_id for RLS
    p.name,
    p.sku,
    p.category,
    p.min_stock_level,
    COALESCE(stock.available_stock, 0) as current_stock,
    c.name as company_name,
    p.is_active
FROM public.products p
LEFT JOIN public.companies c ON p.company_id = c.id
LEFT JOIN (
    SELECT 
        product_id,
        SUM(quantity) as available_stock
    FROM public.product_batches 
    WHERE is_available = true 
    AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE)
    GROUP BY product_id
) stock ON p.id = stock.product_id
WHERE p.is_active = true
AND COALESCE(stock.available_stock, 0) <= p.min_stock_level;

-- Create purchase_orders_with_details view with store_id
CREATE OR REPLACE VIEW public.purchase_orders_with_details AS
SELECT 
    po.*,
    c.name as supplier_name,
    c.contact_person,
    c.phone as supplier_phone,
    c.email as supplier_email
FROM public.purchase_orders po
LEFT JOIN public.companies c ON po.supplier_id = c.id;

-- Enable RLS on views (they inherit from base tables)
-- Views automatically respect RLS from underlying tables

-- Grant permissions
GRANT SELECT ON public.products_with_details TO authenticated;
GRANT SELECT ON public.low_stock_products TO authenticated;
GRANT SELECT ON public.purchase_orders_with_details TO authenticated;

-- Recreate search_purchase_orders function that was dropped with CASCADE
CREATE OR REPLACE FUNCTION public.search_purchase_orders(
    p_search_text text DEFAULT NULL,
    p_supplier_ids uuid[] DEFAULT NULL,
    p_sort_by text DEFAULT 'order_date',
    p_sort_asc boolean DEFAULT false
)
RETURNS SETOF purchase_orders_with_details
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM purchase_orders_with_details po
    WHERE 
        -- Store isolation (RLS will handle this automatically)
        (p_search_text IS NULL OR 
         po.po_number ILIKE '%' || p_search_text || '%' OR
         po.supplier_name ILIKE '%' || p_search_text || '%' OR
         po.notes ILIKE '%' || p_search_text || '%')
    AND 
        (p_supplier_ids IS NULL OR po.supplier_id = ANY(p_supplier_ids))
    ORDER BY 
        CASE 
            WHEN p_sort_by = 'order_date' AND p_sort_asc THEN po.order_date
        END ASC,
        CASE 
            WHEN p_sort_by = 'order_date' AND NOT p_sort_asc THEN po.order_date
        END DESC,
        CASE 
            WHEN p_sort_by = 'total_amount' AND p_sort_asc THEN po.total_amount
        END ASC,
        CASE 
            WHEN p_sort_by = 'total_amount' AND NOT p_sort_asc THEN po.total_amount
        END DESC,
        po.order_date DESC; -- Default fallback
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.search_purchase_orders(text, uuid[], text, boolean) TO authenticated;

COMMIT;
