DROP FUNCTION IF EXISTS get_revenue_trend(date, date, text);

-- =============================================================================
-- FUNCTION: get_revenue_trend
-- Description: Returns time-series revenue data for a given date range and the preceding period.
--              Used to populate trend analysis charts.
-- Parameters:
--   - p_start_date: The start date of the current period.
--   - p_end_date: The end date of the current period.
--   - p_interval: The interval for grouping data ('day' or 'month').
-- Returns: A table with report_date, current_period_revenue, and previous_period_revenue.
-- =============================================================================
CREATE OR REPLACE FUNCTION get_revenue_trend(p_start_date date, p_end_date date, p_interval text)
RETURNS TABLE (
    report_date date,
    current_period_revenue numeric,
    previous_period_revenue numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_store_id uuid;
    v_previous_start_date date;
    v_previous_end_date date;
    v_duration int;
    v_period_offset interval;
BEGIN
    -- 1. Get current user's store ID for data isolation
    SELECT store_id INTO current_user_store_id
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF current_user_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    -- 2. Calculate the duration and date range for the preceding comparison period
    v_duration := p_end_date - p_start_date;
    v_previous_end_date := p_start_date - interval '1 day';
    v_previous_start_date := v_previous_end_date - (v_duration || ' days')::interval;
    v_period_offset := (p_start_date - v_previous_start_date) || ' days';

    RETURN QUERY
    WITH 
    -- 3. Generate a complete series of dates for the specified interval. This is the backbone of the chart.
    date_series AS (
        SELECT generate_series(
            date_trunc(p_interval, p_start_date),
            date_trunc(p_interval, p_end_date),
            ('1 ' || p_interval)::interval
        )::date AS day
    ),
    -- 4. Aggregate revenue for the current period, grouped by the specified interval.
    current_period_data AS (
        SELECT
            date_trunc(p_interval, t.transaction_date)::date AS transaction_day,
            SUM(t.total_amount) AS revenue
        FROM transactions t
        WHERE t.store_id = current_user_store_id
          AND t.transaction_date BETWEEN p_start_date AND p_end_date
        GROUP BY 1
    ),
    -- 5. Aggregate revenue for the previous period, grouped by the specified interval.
    previous_period_data AS (
        SELECT
            date_trunc(p_interval, t.transaction_date)::date AS transaction_day,
            SUM(t.total_amount) AS revenue
        FROM transactions t
        WHERE t.store_id = current_user_store_id
          AND t.transaction_date BETWEEN v_previous_start_date AND v_previous_end_date
        GROUP BY 1
    )
    -- 6. Join the date series with both revenue datasets.
    --    LEFT JOIN ensures all dates are present, even with zero revenue.
    --    The previous period's dates are shifted forward by the offset to align them with the current period for comparison.
    SELECT
        ds.day AS report_date,
        COALESCE(cpd.revenue, 0) AS current_period_revenue,
        COALESCE(ppd.revenue, 0) AS previous_period_revenue
    FROM date_series ds
    LEFT JOIN current_period_data cpd ON ds.day = cpd.transaction_day
    LEFT JOIN previous_period_data ppd ON ds.day = (ppd.transaction_day + v_period_offset)
    ORDER BY ds.day;

END;
$$;

-- Grant permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_revenue_trend(date, date, text) TO authenticated;