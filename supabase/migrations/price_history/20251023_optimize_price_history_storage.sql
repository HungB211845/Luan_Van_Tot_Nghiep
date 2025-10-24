-- =============================================================================
-- MIGRATION: Optimize Price History Storage
-- Description: Replace text reason column with smallint reason_id + lookup table
-- Expected Savings: 60-70MB (60-70% reduction in price_history table size)
-- Date: 2025-10-23
-- Status: STEP 1-3 (SAFE, REVERSIBLE)
-- =============================================================================

-- =============================================================================
-- STEP 1: Create Lookup Table for Price Change Reasons
-- =============================================================================
-- Purpose: Store reason codes once instead of repeating text strings
-- Storage: ~1 KB vs ~50 MB for repeated text
-- Rollback: DROP TABLE IF EXISTS public.price_change_reasons CASCADE;

CREATE TABLE IF NOT EXISTS public.price_change_reasons (
  id smallint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  reason_code text NOT NULL UNIQUE,
  description text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Populate with common reasons from existing data analysis
INSERT INTO public.price_change_reasons (reason_code, description)
VALUES
  ('MANUAL_UPDATE', 'Cập nhật giá thủ công'),
  ('PO_UPDATE', 'Cập nhật từ đơn nhập hàng'),
  ('BATCH_IMPORT', 'Import hàng loạt'),
  ('PROMOTION_START', 'Bắt đầu khuyến mãi'),
  ('PROMOTION_END', 'Kết thúc khuyến mãi'),
  ('SYSTEM_AUTO', 'Hệ thống tự động điều chỉnh'),
  ('PRICE_CORRECTION', 'Điều chỉnh giá sai sót'),
  ('MARKET_ADJUSTMENT', 'Điều chỉnh theo thị trường'),
  ('UNKNOWN', 'Không rõ lý do')
ON CONFLICT (reason_code) DO NOTHING;

-- Grant permissions
GRANT SELECT ON public.price_change_reasons TO authenticated;
GRANT SELECT ON public.price_change_reasons TO anon;

COMMENT ON TABLE public.price_change_reasons IS
  'Lookup table for price change reasons. Replaces repeated text in price_history to save storage.';

-- =============================================================================
-- STEP 2: Add New Column to price_history (NON-DESTRUCTIVE)
-- =============================================================================
-- Purpose: Add reason_id column WITHOUT dropping old reason column yet
-- Safety: Old column remains functional during migration
-- Rollback: ALTER TABLE public.price_history DROP COLUMN IF EXISTS reason_id;

ALTER TABLE public.price_history
ADD COLUMN IF NOT EXISTS reason_id smallint REFERENCES public.price_change_reasons(id);

-- Create index for query performance
CREATE INDEX IF NOT EXISTS idx_price_history_reason_id
ON public.price_history(reason_id);

COMMENT ON COLUMN public.price_history.reason_id IS
  'Foreign key to price_change_reasons. Replaces text reason column for storage optimization.';

-- =============================================================================
-- STEP 3: Migrate Existing Data (IDEMPOTENT)
-- =============================================================================
-- Purpose: Copy data from old 'reason' text column to new 'reason_id' smallint column
-- Safety: WHERE reason_id IS NULL makes this idempotent (safe to run multiple times)
-- Rollback: UPDATE public.price_history SET reason_id = NULL;

-- Migration query with pattern matching
UPDATE public.price_history
SET reason_id = CASE
  -- Match Purchase Order updates
  WHEN reason ILIKE '%purchase order%'
    OR reason ILIKE '%PO-%'
    OR reason ILIKE '%đơn nhập%'
    OR reason ILIKE '%nhập hàng%'
    THEN (SELECT id FROM public.price_change_reasons WHERE reason_code = 'PO_UPDATE')

  -- Match batch imports
  WHEN reason ILIKE '%import%'
    OR reason ILIKE '%batch%'
    OR reason ILIKE '%hàng loạt%'
    THEN (SELECT id FROM public.price_change_reasons WHERE reason_code = 'BATCH_IMPORT')

  -- Match promotions
  WHEN reason ILIKE '%promotion%'
    OR reason ILIKE '%khuyến mãi%'
    OR reason ILIKE '%giảm giá%'
    THEN (SELECT id FROM public.price_change_reasons WHERE reason_code = 'PROMOTION_START')

  -- Match manual updates
  WHEN reason ILIKE '%manual%'
    OR reason ILIKE '%thủ công%'
    OR reason ILIKE '%hand%'
    THEN (SELECT id FROM public.price_change_reasons WHERE reason_code = 'MANUAL_UPDATE')

  -- Match auto adjustments
  WHEN reason ILIKE '%auto%'
    OR reason ILIKE '%tự động%'
    OR reason ILIKE '%system%'
    THEN (SELECT id FROM public.price_change_reasons WHERE reason_code = 'SYSTEM_AUTO')

  -- Match price corrections
  WHEN reason ILIKE '%correct%'
    OR reason ILIKE '%fix%'
    OR reason ILIKE '%sửa%'
    OR reason ILIKE '%điều chỉnh%'
    THEN (SELECT id FROM public.price_change_reasons WHERE reason_code = 'PRICE_CORRECTION')

  -- Default to UNKNOWN
  ELSE (SELECT id FROM public.price_change_reasons WHERE reason_code = 'UNKNOWN')
END
WHERE reason_id IS NULL; -- IDEMPOTENT: only update rows not yet migrated

-- =============================================================================
-- VERIFICATION QUERIES (Run these to verify migration)
-- =============================================================================

-- Query 1: Check migration progress (should return 0 when complete)
-- SELECT COUNT(*) as remaining_unmigrated
-- FROM public.price_history
-- WHERE reason_id IS NULL;

-- Query 2: Distribution of reason codes after migration
-- SELECT
--   pcr.reason_code,
--   pcr.description,
--   COUNT(ph.id) as count,
--   ROUND(COUNT(ph.id) * 100.0 / SUM(COUNT(ph.id)) OVER (), 2) as percentage
-- FROM public.price_history ph
-- JOIN public.price_change_reasons pcr ON ph.reason_id = pcr.id
-- GROUP BY pcr.reason_code, pcr.description
-- ORDER BY count DESC;

-- Query 3: Test JOIN query (verify reads work correctly)
-- SELECT
--   ph.id,
--   p.name as product_name,
--   ph.old_price,
--   ph.new_price,
--   pcr.description as reason,
--   ph.changed_at
-- FROM public.price_history ph
-- JOIN public.price_change_reasons pcr ON ph.reason_id = pcr.id
-- JOIN public.products p ON ph.product_id = p.id
-- ORDER BY ph.changed_at DESC
-- LIMIT 20;

-- =============================================================================
-- NEXT STEPS (DO NOT RUN YET - MANUAL EXECUTION REQUIRED)
-- =============================================================================

-- ⚠️ STEP 4: Update App Code (price_history_service.dart)
--    - Modify INSERT statements to use reason_id instead of reason
--    - Deploy app with dual-write (write both columns for safety)
--    - Monitor for 24-48 hours

-- ⚠️ STEP 5: Test Thoroughly
--    - Verify all queries work with new column
--    - Check app functionality (create test price changes)
--    - Ensure no errors in logs

-- ⚠️ STEP 6: Drop Old Column (IRREVERSIBLE - requires backup first!)
--    Run in Supabase SQL Editor ONLY after Steps 4-5 complete:
--
--    -- Create backup first (Supabase Dashboard → Database → Backups)
--    --
--    -- ALTER TABLE public.price_history DROP COLUMN reason;
--    -- VACUUM FULL public.price_history;
--    -- ANALYZE public.price_history;
--    --
--    -- Expected result: 60-70MB storage freed

-- =============================================================================
-- ROLLBACK INSTRUCTIONS
-- =============================================================================

-- If migration fails at Step 3:
--   UPDATE public.price_history SET reason_id = NULL;

-- If need to completely rollback (before Step 6):
--   DROP INDEX IF EXISTS idx_price_history_reason_id;
--   ALTER TABLE public.price_history DROP COLUMN IF EXISTS reason_id;
--   DROP TABLE IF EXISTS public.price_change_reasons CASCADE;

-- If need to rollback AFTER Step 6 (column already dropped):
--   ALTER TABLE public.price_history ADD COLUMN reason text;
--   UPDATE public.price_history ph
--   SET reason = pcr.description
--   FROM public.price_change_reasons pcr
--   WHERE ph.reason_id = pcr.id;

-- =============================================================================
-- MIGRATION COMPLETE (Steps 1-3)
-- =============================================================================

-- ✅ Lookup table created
-- ✅ New column added (old column still intact)
-- ✅ Data migrated (idempotent, can re-run safely)
-- ⏸️ Ready for Step 4 (app code update)
