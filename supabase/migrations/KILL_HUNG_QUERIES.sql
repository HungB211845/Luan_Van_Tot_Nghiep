-- =============================================================================
-- KILL HUNG QUERIES - Fix Database Timeout Issues
-- =============================================================================

-- Step 1: Show all long-running queries (> 30 seconds)
SELECT
    pid,
    usename,
    application_name,
    now() - query_start as duration,
    state,
    LEFT(query, 200) as query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND query NOT LIKE '%pg_stat_activity%'
  AND (now() - query_start) > interval '30 seconds'
ORDER BY duration DESC;

-- Step 2: Kill all long-running queries automatically
-- ⚠️ CAUTION: This will terminate all queries running > 2 minutes
DO $$
DECLARE
    r RECORD;
    killed_count INTEGER := 0;
BEGIN
    FOR r IN
        SELECT pid
        FROM pg_stat_activity
        WHERE state != 'idle'
          AND query NOT LIKE '%pg_stat_activity%'
          AND (now() - query_start) > interval '2 minutes'
    LOOP
        PERFORM pg_terminate_backend(r.pid);
        killed_count := killed_count + 1;
        RAISE NOTICE 'Terminated query with PID: %', r.pid;
    END LOOP;

    RAISE NOTICE '✅ Killed % hung queries', killed_count;
END $$;

-- Step 3: Note about vacuum
-- VACUUM cannot run in transaction blocks or migrations
-- Run these manually in SQL Editor if needed:
-- VACUUM ANALYZE public.products;
-- VACUUM ANALYZE public.product_batches;
-- VACUUM ANALYZE public.price_history;

SELECT '✅ Database cleanup completed - hung queries terminated' as status;
