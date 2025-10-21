-- Migration: Create store_business_info table for invoice management
-- Date: 2025-10-21
-- Purpose: Store business information for invoices (MST, tax authority, etc.)

-- Create table
CREATE TABLE IF NOT EXISTS public.store_business_info (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE UNIQUE NOT NULL,

  -- Tax & Business Info
  tax_code VARCHAR(13) NOT NULL,           -- MST (10 hoặc 13 chữ số)
  business_name VARCHAR(255) NOT NULL,      -- Tên doanh nghiệp/hộ kinh doanh
  tax_authority VARCHAR(255),               -- Cơ quan thuế quản lý
  business_address TEXT,                    -- Địa chỉ kinh doanh

  -- Contact Info
  phone_number VARCHAR(20),
  email VARCHAR(255),

  -- Banking Info (Optional)
  bank_account VARCHAR(50),
  bank_name VARCHAR(255),

  -- Legal Info
  legal_representative VARCHAR(255),        -- Người đại diện pháp luật

  -- Validation Info
  validated_at TIMESTAMPTZ,                 -- Thời điểm validate MST
  validation_source VARCHAR(50),            -- 'API' | 'MANUAL'

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_store_business_info_store_id
  ON public.store_business_info(store_id);

CREATE INDEX IF NOT EXISTS idx_store_business_info_tax_code
  ON public.store_business_info(tax_code);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION public.update_store_business_info_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_store_business_info_updated_at
  BEFORE UPDATE ON public.store_business_info
  FOR EACH ROW
  EXECUTE FUNCTION public.update_store_business_info_updated_at();

-- RLS Policies
ALTER TABLE public.store_business_info ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only view their own store's business info
CREATE POLICY "Users can view their store business info"
  ON public.store_business_info
  FOR SELECT
  USING (
    store_id IN (
      SELECT store_id FROM public.user_profiles
      WHERE id = auth.uid()
    )
  );

-- Policy: Users can insert business info for their store
CREATE POLICY "Users can insert their store business info"
  ON public.store_business_info
  FOR INSERT
  WITH CHECK (
    store_id IN (
      SELECT store_id FROM public.user_profiles
      WHERE id = auth.uid()
    )
  );

-- Policy: Users can update their store's business info
CREATE POLICY "Users can update their store business info"
  ON public.store_business_info
  FOR UPDATE
  USING (
    store_id IN (
      SELECT store_id FROM public.user_profiles
      WHERE id = auth.uid()
    )
  )
  WITH CHECK (
    store_id IN (
      SELECT store_id FROM public.user_profiles
      WHERE id = auth.uid()
    )
  );

-- Policy: Users can delete their store's business info
CREATE POLICY "Users can delete their store business info"
  ON public.store_business_info
  FOR DELETE
  USING (
    store_id IN (
      SELECT store_id FROM public.user_profiles
      WHERE id = auth.uid()
    )
  );

-- Comment
COMMENT ON TABLE public.store_business_info IS
  'Stores business information for invoice generation (MST, tax authority, etc.)';
