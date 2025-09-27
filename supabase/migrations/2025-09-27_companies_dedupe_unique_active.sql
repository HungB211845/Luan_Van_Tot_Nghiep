-- Migration: Dọn trùng companies theo từng store (Phương án B - inactive) + Unique index partial
-- Mục tiêu:
-- 1) Chuẩn hoá tên (trim + gộp khoảng trắng)
-- 2) Hạ inactive các bản ghi trùng trong phạm vi (store_id, lower(name)), giữ 1 bản ghi
-- 3) Tạo unique index partial: (store_id, lower(trim(name))) WHERE is_active = true
-- 4) Trigger normalize tên trước khi INSERT/UPDATE

BEGIN;

-- 0) Ràng buộc an toàn: thêm cột is_active nếu chưa có
ALTER TABLE public.companies
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

-- 1) Chuẩn hoá tên: trim và gộp khoảng trắng thừa
UPDATE public.companies c
SET name = norm.norm_name
FROM (
  SELECT id, regexp_replace(trim(name), '\s+', ' ', 'g') AS norm_name
  FROM public.companies
) AS norm
WHERE c.id = norm.id
  AND c.name <> norm.norm_name;

-- 2) Hạ inactive các bản ghi trùng (giữ 1 theo created_at rồi id)
WITH ranked AS (
  SELECT
    id,
    store_id,
    name,
    row_number() OVER (
      PARTITION BY store_id, lower(name)
      ORDER BY created_at ASC NULLS LAST, id ASC
    ) AS rn
  FROM public.companies
)
UPDATE public.companies c
SET is_active = false
FROM ranked r
WHERE c.id = r.id
  AND r.rn > 1;

-- 3) Unique index partial: đảm bảo không trùng tên trong cùng store đối với bản ghi đang active
--    Case-insensitive và bỏ khoảng trắng đầu/cuối
CREATE UNIQUE INDEX IF NOT EXISTS companies_store_name_unique_active_idx
  ON public.companies (store_id, lower(trim(name)))
  WHERE is_active = true;

-- (Khuyến nghị) Thêm index hỗ trợ truy vấn theo store_id
CREATE INDEX IF NOT EXISTS companies_store_id_idx ON public.companies (store_id);

-- 4) Trigger chuẩn hoá tên trước khi INSERT/UPDATE để tránh sai khác do khoảng trắng
CREATE OR REPLACE FUNCTION public.companies_normalize_name() RETURNS trigger AS $$
BEGIN
  NEW.name := regexp_replace(trim(NEW.name), '\s+', ' ', 'g');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_companies_normalize_name ON public.companies;
CREATE TRIGGER trg_companies_normalize_name
BEFORE INSERT OR UPDATE ON public.companies
FOR EACH ROW EXECUTE FUNCTION public.companies_normalize_name();

COMMIT;
