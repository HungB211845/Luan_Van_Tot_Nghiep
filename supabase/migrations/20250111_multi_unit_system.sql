-- =============================================================================
-- MIGRATION: MULTI-UNIT SYSTEM (Quản lý Đa Đơn vị tính)
-- Version: 1.0
-- Date: 2025-01-11
-- Description: Cho phép mỗi sản phẩm có nhiều đơn vị bán khác nhau
-- =============================================================================

-- =====================================================
-- PART 1: CREATE TABLE product_units
-- =====================================================
CREATE TABLE IF NOT EXISTS public.product_units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  unit_name TEXT NOT NULL,
  conversion_factor NUMERIC NOT NULL CHECK (conversion_factor > 0),
  unit_price NUMERIC NOT NULL CHECK (unit_price >= 0),
  is_default_selling_unit BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  store_id UUID NOT NULL REFERENCES public.stores(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Đảm bảo không duplicate unit name cho cùng 1 sản phẩm trong 1 store
  CONSTRAINT product_units_unique_name_per_product
    UNIQUE (product_id, unit_name, store_id)
);

-- Indexes cho performance
CREATE INDEX idx_product_units_product_id ON public.product_units(product_id);
CREATE INDEX idx_product_units_store_id ON public.product_units(store_id);

-- UNIQUE partial index để đảm bảo mỗi sản phẩm chỉ có DUY NHẤT 1 đơn vị mặc định
-- (Thay thế cho EXCLUDE constraint để tránh lỗi GIST với UUID)
CREATE UNIQUE INDEX product_units_one_default_per_product
  ON public.product_units(product_id, store_id)
  WHERE is_default_selling_unit = true AND is_active = true;

-- Comments
COMMENT ON TABLE public.product_units IS 'Quản lý các đơn vị bán khác nhau cho mỗi sản phẩm';
COMMENT ON COLUMN public.product_units.unit_name IS 'Tên đơn vị (Bao, Chai, kg, ml, etc.)';
COMMENT ON COLUMN public.product_units.conversion_factor IS 'Hệ số quy đổi về đơn vị cơ sở (1 Bao = 50 kg thì factor = 50)';
COMMENT ON COLUMN public.product_units.unit_price IS 'Giá bán cho đơn vị này';

-- =====================================================
-- PART 2: ADD base_unit COLUMN TO products
-- =====================================================
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS base_unit TEXT DEFAULT NULL;

COMMENT ON COLUMN public.products.base_unit IS 'Đơn vị cơ sở để quản lý tồn kho (kg, ml, unit, etc.)';

-- Populate base_unit dựa trên category
UPDATE public.products
SET base_unit = CASE
  WHEN category = 'FERTILIZER' THEN 'kg'
  WHEN category = 'PESTICIDE' THEN 'ml'
  WHEN category = 'SEED' THEN 'kg'
  ELSE 'unit'
END
WHERE base_unit IS NULL;

-- Đặt NOT NULL sau khi đã populate
ALTER TABLE public.products
  ALTER COLUMN base_unit SET NOT NULL;

-- =====================================================
-- PART 3: POPULATE DEFAULT UNITS FOR EXISTING PRODUCTS
-- =====================================================

-- 3.1: Phân bón (FERTILIZER) - Đơn vị mặc định từ attributes hoặc "Bao"
INSERT INTO public.product_units (
  product_id,
  unit_name,
  conversion_factor,
  unit_price,
  is_default_selling_unit,
  store_id
)
SELECT
  p.id AS product_id,
  COALESCE(
    (p.attributes->>'unit')::TEXT,
    'Bao'
  ) AS unit_name,
  GREATEST(
    COALESCE((p.attributes->>'weight')::NUMERIC, 50),
    1
  ) AS conversion_factor,  -- Đảm bảo >= 1
  p.current_selling_price AS unit_price,
  true AS is_default_selling_unit,
  p.store_id
FROM public.products p
WHERE p.category = 'FERTILIZER'
  AND p.is_active = true
  AND NOT EXISTS (
    SELECT 1 FROM public.product_units pu
    WHERE pu.product_id = p.id
  )
ON CONFLICT (product_id, unit_name, store_id) DO NOTHING;

-- 3.2: Thuốc BVTV (PESTICIDE) - Đơn vị mặc định từ attributes hoặc "Lít"
INSERT INTO public.product_units (
  product_id,
  unit_name,
  conversion_factor,
  unit_price,
  is_default_selling_unit,
  store_id
)
SELECT
  p.id AS product_id,
  COALESCE(
    (p.attributes->>'unit')::TEXT,
    'Lít'
  ) AS unit_name,
  GREATEST(
    COALESCE((p.attributes->>'volume')::NUMERIC, 1),
    1
  ) AS conversion_factor,  -- Đảm bảo >= 1
  p.current_selling_price AS unit_price,
  true AS is_default_selling_unit,
  p.store_id
FROM public.products p
WHERE p.category = 'PESTICIDE'
  AND p.is_active = true
  AND NOT EXISTS (
    SELECT 1 FROM public.product_units pu
    WHERE pu.product_id = p.id
  )
ON CONFLICT (product_id, unit_name, store_id) DO NOTHING;

-- 3.3: Lúa giống (SEED) - Đơn vị mặc định
INSERT INTO public.product_units (
  product_id,
  unit_name,
  conversion_factor,
  unit_price,
  is_default_selling_unit,
  store_id
)
SELECT
  p.id AS product_id,
  COALESCE(
    (p.attributes->>'unit')::TEXT,
    'kg'
  ) AS unit_name,
  GREATEST(
    COALESCE((p.attributes->>'weight')::NUMERIC, 1),
    1
  ) AS conversion_factor,  -- Đảm bảo >= 1
  p.current_selling_price AS unit_price,
  true AS is_default_selling_unit,
  p.store_id
FROM public.products p
WHERE p.category = 'SEED'
  AND p.is_active = true
  AND NOT EXISTS (
    SELECT 1 FROM public.product_units pu
    WHERE pu.product_id = p.id
  )
ON CONFLICT (product_id, unit_name, store_id) DO NOTHING;

-- 3.4: Thêm đơn vị cơ sở (kg/ml) làm lựa chọn bán lẻ
INSERT INTO public.product_units (
  product_id,
  unit_name,
  conversion_factor,
  unit_price,
  is_default_selling_unit,
  store_id
)
SELECT
  p.id AS product_id,
  p.base_unit AS unit_name,
  1 AS conversion_factor,
  -- Tính giá lẻ = giá bao / conversion factor của đơn vị mặc định
  CASE
    WHEN EXISTS (
      SELECT 1 FROM product_units pu
      WHERE pu.product_id = p.id
        AND pu.is_default_selling_unit = true
    ) THEN p.current_selling_price / COALESCE(
      (SELECT pu.conversion_factor
       FROM product_units pu
       WHERE pu.product_id = p.id
         AND pu.is_default_selling_unit = true
       LIMIT 1),
      1
    )
    ELSE p.current_selling_price
  END AS unit_price,
  false AS is_default_selling_unit,
  p.store_id
FROM public.products p
WHERE p.base_unit IS NOT NULL
  AND p.category IN ('FERTILIZER', 'PESTICIDE', 'SEED')
  AND p.is_active = true
  AND NOT EXISTS (
    SELECT 1 FROM public.product_units pu
    WHERE pu.product_id = p.id
      AND pu.unit_name = p.base_unit
  )
ON CONFLICT (product_id, unit_name, store_id) DO NOTHING;

-- =====================================================
-- PART 4: ADD UNIT TRACKING TO transaction_items
-- =====================================================
ALTER TABLE public.transaction_items
  ADD COLUMN IF NOT EXISTS unit_id UUID REFERENCES public.product_units(id),
  ADD COLUMN IF NOT EXISTS unit_name TEXT,
  ADD COLUMN IF NOT EXISTS unit_conversion_factor NUMERIC,
  ADD COLUMN IF NOT EXISTS base_unit_quantity NUMERIC;

COMMENT ON COLUMN public.transaction_items.unit_id IS 'ID của đơn vị đã được dùng cho item này';
COMMENT ON COLUMN public.transaction_items.unit_name IS 'Tên đơn vị (snapshot để giữ lịch sử)';
COMMENT ON COLUMN public.transaction_items.unit_conversion_factor IS 'Hệ số quy đổi (snapshot)';
COMMENT ON COLUMN public.transaction_items.base_unit_quantity IS 'Số lượng quy đổi về đơn vị cơ sở (dùng cho inventory calculation)';

-- Index
CREATE INDEX IF NOT EXISTS idx_transaction_items_unit_id ON public.transaction_items(unit_id);

-- Cập nhật dữ liệu cũ (gán default unit cho transactions cũ)
UPDATE public.transaction_items ti
SET
  unit_name = pu.unit_name,
  unit_id = pu.id,
  unit_conversion_factor = pu.conversion_factor,
  base_unit_quantity = ti.quantity * pu.conversion_factor
FROM public.product_units pu
WHERE ti.product_id = pu.product_id
  AND pu.is_default_selling_unit = true
  AND ti.unit_id IS NULL;

-- =====================================================
-- PART 5: RLS POLICIES FOR product_units
-- =====================================================
ALTER TABLE public.product_units ENABLE ROW LEVEL SECURITY;

-- Policy: Users view units in their store
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'product_units'
      AND policyname = 'Users view units in their store'
  ) THEN
    CREATE POLICY "Users view units in their store"
      ON public.product_units FOR SELECT
      USING (store_id IN (
        SELECT store_id
        FROM public.user_profiles
        WHERE id = auth.uid()
      ));
  END IF;
END $$;

-- Policy: Store owners manage units
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'product_units'
      AND policyname = 'Store owners manage units'
  ) THEN
    CREATE POLICY "Store owners manage units"
      ON public.product_units FOR ALL
      USING (store_id IN (
        SELECT store_id
        FROM public.user_profiles
        WHERE id = auth.uid()
      ));
  END IF;
END $$;

-- =====================================================
-- PART 6: TRIGGER FOR updated_at
-- =====================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_product_units_updated_at ON public.product_units;

CREATE TRIGGER update_product_units_updated_at
  BEFORE UPDATE ON public.product_units
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- PART 7: RPC FUNCTIONS
-- =====================================================

-- Function 1: Lấy danh sách đơn vị của một sản phẩm
CREATE OR REPLACE FUNCTION public.get_product_units(p_product_id UUID)
RETURNS TABLE (
  id UUID,
  unit_name TEXT,
  conversion_factor NUMERIC,
  unit_price NUMERIC,
  is_default_selling_unit BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    pu.id,
    pu.unit_name,
    pu.conversion_factor,
    pu.unit_price,
    pu.is_default_selling_unit
  FROM public.product_units pu
  WHERE pu.product_id = p_product_id
    AND pu.is_active = true
    AND pu.store_id IN (
      SELECT store_id
      FROM public.user_profiles
      WHERE id = auth.uid()
    )
  ORDER BY pu.is_default_selling_unit DESC, pu.unit_name ASC;
END;
$$;

-- Function 2: Lấy tồn kho theo đơn vị cơ sở
CREATE OR REPLACE FUNCTION public.get_available_stock_base_unit(p_product_id UUID)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_stock NUMERIC;
BEGIN
  SELECT COALESCE(SUM(pb.quantity), 0) INTO v_stock
  FROM public.product_batches pb
  WHERE pb.product_id = p_product_id
    AND pb.is_available = true
    AND pb.quantity > 0
    AND pb.store_id IN (
      SELECT store_id
      FROM public.user_profiles
      WHERE id = auth.uid()
    );

  RETURN v_stock;
END;
$$;

-- Function 3: Kiểm tra tồn kho với quy đổi đơn vị
CREATE OR REPLACE FUNCTION public.check_stock_availability(
  p_product_id UUID,
  p_quantity NUMERIC,
  p_unit_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conversion_factor NUMERIC;
  v_base_quantity NUMERIC;
  v_available_stock NUMERIC;
BEGIN
  -- Lấy hệ số quy đổi
  SELECT conversion_factor INTO v_conversion_factor
  FROM public.product_units
  WHERE id = p_unit_id;

  IF v_conversion_factor IS NULL THEN
    RETURN false;
  END IF;

  -- Tính số lượng cần theo đơn vị cơ sở
  v_base_quantity := p_quantity * v_conversion_factor;

  -- Lấy tồn kho hiện có
  v_available_stock := public.get_available_stock_base_unit(p_product_id);

  RETURN v_available_stock >= v_base_quantity;
END;
$$;

-- Function 4: Search transactions với thông tin unit (Enhanced version)
CREATE OR REPLACE FUNCTION public.search_transactions_with_units(
  p_search_text TEXT DEFAULT ''
)
RETURNS TABLE (
  id UUID,
  customer_name TEXT,
  total_amount NUMERIC,
  transaction_date TIMESTAMPTZ,
  payment_method TEXT,
  items_json JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.id,
    COALESCE(c.name, 'Khách lẻ') AS customer_name,
    t.total_amount,
    t.transaction_date,
    t.payment_method,
    jsonb_agg(
      jsonb_build_object(
        'product_name', p.name,
        'quantity', ti.quantity,
        'unit_name', COALESCE(ti.unit_name, 'đơn vị'),
        'price_at_sale', ti.price_at_sale,
        'sub_total', ti.sub_total
      ) ORDER BY ti.created_at
    ) AS items_json
  FROM public.transactions t
  LEFT JOIN public.customers c ON t.customer_id = c.id
  LEFT JOIN public.transaction_items ti ON t.id = ti.transaction_id
  LEFT JOIN public.products p ON ti.product_id = p.id
  WHERE t.store_id IN (
      SELECT store_id
      FROM public.user_profiles
      WHERE id = auth.uid()
    )
    AND (
      p_search_text = ''
      OR c.name ILIKE '%' || p_search_text || '%'
      OR p.name ILIKE '%' || p_search_text || '%'
      OR t.invoice_number ILIKE '%' || p_search_text || '%'
    )
  GROUP BY t.id, c.name
  ORDER BY t.transaction_date DESC
  LIMIT 100;
END;
$$;

-- =====================================================
-- PART 8: GRANT PERMISSIONS
-- =====================================================
GRANT SELECT ON public.product_units TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.product_units TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_product_units(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_available_stock_base_unit(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_stock_availability(UUID, NUMERIC, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_transactions_with_units(TEXT) TO authenticated;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- Summary:
-- ✅ Created table: product_units
-- ✅ Added column: products.base_unit
-- ✅ Populated default units for existing products
-- ✅ Added unit tracking columns to transaction_items
-- ✅ Created RLS policies
-- ✅ Created RPC functions
-- ✅ Granted permissions
--
-- Total tables modified: 2 (products, transaction_items)
-- Total tables created: 1 (product_units)
-- Total functions created: 4
-- =====================================================
