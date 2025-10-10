
-- supabase/migrations/YYYYMMDDHHMMSS_rollback_report_rpc_functions.sql
-- Description: Rolls back the creation of report-related RPC functions.

DROP FUNCTION IF EXISTS get_revenue_summary(date, date);

DROP FUNCTION IF EXISTS get_revenue_trend(date, date, text);

DROP FUNCTION IF EXISTS get_top_performing_products(date, date, text, int);

DROP FUNCTION IF EXISTS get_inventory_summary();

DROP FUNCTION IF EXISTS get_inventory_alerts(int, int);
