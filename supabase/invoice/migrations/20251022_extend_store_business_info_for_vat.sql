-- Migration: Extend store_business_info table for VAT invoice compliance
-- Date: 2025-10-22
-- Purpose: Add invoice symbol, template code, VAT rate, and other fields per NĐ 123/2020, NĐ 70/2025, TT 32/2025

-- Add new columns for invoice metadata and VAT compliance
ALTER TABLE public.store_business_info
  ADD COLUMN IF NOT EXISTS invoice_symbol VARCHAR(20),           -- Ký hiệu HĐDT (VD: 1C25TYY)
  ADD COLUMN IF NOT EXISTS invoice_template_code VARCHAR(20),    -- Mẫu số HĐDT (VD: 01GTKT3/001)
  ADD COLUMN IF NOT EXISTS bank_branch VARCHAR(255),             -- Chi nhánh ngân hàng
  ADD COLUMN IF NOT EXISTS default_vat_rate NUMERIC(5,2) DEFAULT 0,  -- % VAT mặc định (0-100)
  ADD COLUMN IF NOT EXISTS website VARCHAR(255),                 -- Website
  ADD COLUMN IF NOT EXISTS logo_url VARCHAR(500);                -- URL logo (NULL trong phase hiện tại)

-- Add index for invoice symbol lookups
CREATE INDEX IF NOT EXISTS idx_store_business_info_invoice_symbol
  ON public.store_business_info(invoice_symbol);

-- Add constraint: VAT rate must be between 0 and 100
ALTER TABLE public.store_business_info
  ADD CONSTRAINT check_vat_rate_range
  CHECK (default_vat_rate >= 0 AND default_vat_rate <= 100);

-- Comment on new columns
COMMENT ON COLUMN public.store_business_info.invoice_symbol IS
  'Ký hiệu hóa đơn điện tử theo TT 32/2025 (VD: 1C25TYY - 1=lần phát hành, C25=Cơ quan thuế 2025, T=Trụ sở, YY=năm)';

COMMENT ON COLUMN public.store_business_info.invoice_template_code IS
  'Mẫu số hóa đơn theo TT 32/2025 (VD: 01GTKT3/001)';

COMMENT ON COLUMN public.store_business_info.default_vat_rate IS
  'Thuế suất GTGT mặc định (%) - 0 = không VAT, 5 = 5%, 8 = 8%, 10 = 10%';

-- Note: All new columns are NULLABLE to avoid breaking existing records
-- Stores can gradually fill in invoice info through the edit form
