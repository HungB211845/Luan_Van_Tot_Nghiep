-- Migration: Add revenue tax rate configuration to store_business_info

ALTER TABLE public.store_business_info
  ADD COLUMN IF NOT EXISTS revenue_tax_rate NUMERIC(5,2) DEFAULT 1.5;

ALTER TABLE public.store_business_info
  ALTER COLUMN revenue_tax_rate SET DEFAULT 1.5;

UPDATE public.store_business_info
SET revenue_tax_rate = 1.5
WHERE revenue_tax_rate IS NULL;

COMMENT ON COLUMN public.store_business_info.revenue_tax_rate IS
  'Thuế khoán trên doanh thu (tỷ lệ % áp dụng cho báo cáo thuế). Mặc định 1.5%.';
