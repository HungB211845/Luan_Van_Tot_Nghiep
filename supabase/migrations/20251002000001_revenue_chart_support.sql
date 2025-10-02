-- Revenue Chart Support Migration
-- This ensures transactions table has proper indexing for daily revenue aggregation

-- Add index on created_at for faster date range queries
CREATE INDEX IF NOT EXISTS idx_transactions_created_at
ON transactions(created_at DESC);

-- Add composite index for store-aware revenue queries (multi-tenant support)
CREATE INDEX IF NOT EXISTS idx_transactions_store_date
ON transactions(store_id, created_at DESC);

-- Add index on total_amount for aggregation performance
CREATE INDEX IF NOT EXISTS idx_transactions_total_amount
ON transactions(total_amount);

-- Create a materialized view for daily revenue (optional, for better performance)
-- This pre-aggregates revenue by day and can be refreshed periodically

CREATE MATERIALIZED VIEW IF NOT EXISTS daily_revenue_summary AS
SELECT
  store_id,
  DATE(created_at) as transaction_date,
  COUNT(*) as transaction_count,
  SUM(total_amount) as total_revenue,
  AVG(total_amount) as avg_transaction_value,
  MAX(total_amount) as max_transaction_value
FROM transactions
GROUP BY store_id, DATE(created_at)
ORDER BY transaction_date DESC;

-- Create index on the materialized view for fast lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_revenue_store_date
ON daily_revenue_summary(store_id, transaction_date DESC);

-- Create function to refresh the materialized view (call this via cron or manually)
CREATE OR REPLACE FUNCTION refresh_daily_revenue_summary()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY daily_revenue_summary;
END;
$$;

-- Grant permissions
GRANT SELECT ON daily_revenue_summary TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_daily_revenue_summary() TO authenticated;

-- Add comment for documentation
COMMENT ON MATERIALIZED VIEW daily_revenue_summary IS 'Pre-aggregated daily revenue data for dashboard charts. Refresh periodically using refresh_daily_revenue_summary()';
