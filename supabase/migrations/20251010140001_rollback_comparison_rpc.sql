
-- supabase/migrations/YYYYMMDDHHMMSS_rollback_comparison_rpc.sql
-- Description: Rolls back the creation of the get_revenue_summary_with_comparison function.

DROP FUNCTION IF EXISTS get_revenue_summary_with_comparison(date, date);
