-- Migration: Add fields for enhanced tax code lookup
-- Date: 2025-10-22
-- Description: Add tax_authority and legal_representative columns to support
--              multi-source tax code lookup (VietQR, masothue)

-- Add new columns for additional business info
ALTER TABLE public.store_business_info
  ADD COLUMN IF NOT EXISTS tax_authority TEXT,
  ADD COLUMN IF NOT EXISTS legal_representative TEXT;

-- Update validation_source constraint to support new sources
ALTER TABLE public.store_business_info
  DROP CONSTRAINT IF EXISTS store_business_info_validation_source_check;

ALTER TABLE public.store_business_info
  ADD CONSTRAINT store_business_info_validation_source_check
  CHECK (validation_source IN ('VIETQR', 'MASOTHUE', 'MANUAL', 'API'));

-- Add comments for documentation
COMMENT ON COLUMN public.store_business_info.tax_authority IS
  'Cơ quan thuế quản lý (e.g., Thuế cơ sở 15 thành phố Hà Nội)';

COMMENT ON COLUMN public.store_business_info.legal_representative IS
  'Người đại diện pháp luật của hộ kinh doanh/doanh nghiệp';

-- Update existing records to have MANUAL source if null
UPDATE public.store_business_info
SET validation_source = 'MANUAL'
WHERE validation_source IS NULL;
