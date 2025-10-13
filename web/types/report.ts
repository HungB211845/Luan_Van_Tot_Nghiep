export type RevenueSummaryComparison = {
  current_total_revenue: number;
  current_total_profit: number;
  current_total_transactions: number;
  previous_total_revenue: number;
  previous_total_profit: number;
  previous_total_transactions: number;
  revenue_change_percentage: number | null;
  profit_change_percentage: number | null;
  transactions_change_percentage: number | null;
};

export type RevenueTrendPoint = {
  date: string;
  revenue: number;
  transaction_count: number;
};

export type DailyRevenuePoint = {
  date: string;
  revenue: number;
  transaction_count: number;
};

export type TopPerformingProduct = {
  product_id: string;
  product_name: string;
  total_quantity: number;
  total_revenue: number;
  total_profit: number;
};

export type InventoryAnalyticsSummary = {
  total_inventory_value: number;
  total_selling_value: number;
  potential_profit: number;
  profit_margin: number;
  total_items: number;
  total_batches: number;
  low_stock_items: number;
  expiring_soon_items: number;
  slow_moving_items: number;
};

export type InventoryAlertProduct = {
  product_id: string;
  product_name: string;
  sku?: string | null;
  current_stock?: number | null;
  min_stock_level?: number | null;
  batch_id?: string | null;
  batch_number?: string | null;
  quantity?: number | null;
  expiry_date?: string | null;
  days_until_expiry?: number | null;
  last_sale_date?: string | null;
  days_since_last_sale?: number | null;
};

export type InventoryAnalyticsAlerts = {
  low_stock_products: InventoryAlertProduct[];
  expiring_soon_products: InventoryAlertProduct[];
  slow_moving_products: InventoryAlertProduct[];
};

export type InventoryAnalyticsCombined = {
  summary: InventoryAnalyticsSummary;
  alerts: InventoryAnalyticsAlerts;
};

export type InventoryAnalyticsLists = {
  top_value_products: InventoryAlertProduct[];
  fast_turnover_products: InventoryAlertProduct[];
  slow_turnover_products: InventoryAlertProduct[];
};

export type TaxSummary = {
  total_revenue: number;
  total_transactions: number;
  total_expenses: number;
  estimated_tax: number;
};

export type SalesLedgerRow = Record<string, unknown>;

