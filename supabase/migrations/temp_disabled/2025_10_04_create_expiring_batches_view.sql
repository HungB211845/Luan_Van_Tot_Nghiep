-- Migration: Create expiring_batches view with store_id and RLS
-- Date: 2025-10-04
-- Purpose: Fix RLS error for expiring_batches by ensuring store_id is present and RLS is applied.

CREATE OR REPLACE VIEW expiring_batches AS
SELECT
  pb.*,
  p.name as product_name,
  p.sku,
  (pb.expiry_date - CURRENT_DATE) as days_until_expiry
FROM product_batches pb
JOIN products p ON pb.product_id = p.id
WHERE pb.expiry_date IS NOT NULL
  AND pb.expiry_date <= CURRENT_DATE + INTERVAL '30 days'
  AND pb.expiry_date > CURRENT_DATE
  AND pb.is_available = true
  AND pb.store_id = (SELECT store_id FROM user_profiles WHERE id = auth.uid()) -- RLS filter
ORDER BY pb.expiry_date ASC;

ALTER VIEW expiring_batches OWNER TO postgres; -- Hoặc role phù hợp

-- Add RLS policy to the view (views kế thừa RLS từ bảng gốc, nhưng khai báo rõ ràng sẽ an toàn hơn)
ALTER TABLE expiring_batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view expiring batches for their store" ON expiring_batches
    FOR SELECT USING (store_id = (SELECT store_id FROM user_profiles WHERE id = auth.uid()));

-- Grant SELECT permission to authenticated role
GRANT SELECT ON expiring_batches TO authenticated;
