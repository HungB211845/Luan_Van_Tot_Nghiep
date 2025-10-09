BEGIN;

-- 1) Drop function phụ thuộc (nếu có) để tránh lỗi dependency
DROP FUNCTION IF EXISTS public.search_purchase_orders(text, uuid[], text, boolean);

-- 2) Drop view cũ
DROP VIEW IF EXISTS public.purchase_orders_with_details CASCADE;

-- 3) Create view mới CÓ cột po_number
CREATE VIEW public.purchase_orders_with_details AS
SELECT
  po.id,
  po.store_id,
  po.po_number,                      -- thêm cột này để UI hiển thị số PO
  po.supplier_id,
  po.order_date,
  po.status,
  po.notes,
  po.total_amount,
  po.subtotal,
  po.created_at,
  po.updated_at,
  c.name   AS supplier_name,
  c.phone  AS supplier_phone,
  c.address AS supplier_address,
  COALESCE(items.item_count, 0)     AS item_count,
  COALESCE(items.total_quantity, 0) AS total_quantity
FROM public.purchase_orders po
LEFT JOIN public.companies c ON po.supplier_id = c.id
LEFT JOIN (
  SELECT purchase_order_id, COUNT(*) AS item_count, SUM(quantity) AS total_quantity
  FROM public.purchase_order_items
  GROUP BY purchase_order_id
) items ON items.purchase_order_id = po.id;

-- 4) Cấp quyền
GRANT SELECT ON public.purchase_orders_with_details TO authenticated;

-- 5) Recreate function phụ thuộc (nếu app đang dùng)
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
        (p_search_text IS NULL
         OR po.po_number ILIKE '%' || p_search_text || '%'
         OR po.supplier_name ILIKE '%' || p_search_text || '%'
         OR po.notes ILIKE '%' || p_search_text || '%')
      AND (p_supplier_ids IS NULL OR po.supplier_id = ANY(p_supplier_ids))
    ORDER BY
      CASE WHEN p_sort_by = 'order_date'   AND p_sort_asc      THEN po.order_date   END ASC,
      CASE WHEN p_sort_by = 'order_date'   AND NOT p_sort_asc  THEN po.order_date   END DESC,
      CASE WHEN p_sort_by = 'total_amount' AND p_sort_asc      THEN po.total_amount END ASC,
      CASE WHEN p_sort_by = 'total_amount' AND NOT p_sort_asc  THEN po.total_amount END DESC,
      po.order_date DESC; -- fallback
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_purchase_orders(text, uuid[], text, boolean) TO authenticated;

COMMIT;