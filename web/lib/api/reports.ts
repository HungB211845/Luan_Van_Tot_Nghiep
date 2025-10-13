import {
  DailyRevenuePoint,
  InventoryAnalyticsAlerts,
  InventoryAnalyticsCombined,
  InventoryAnalyticsLists,
  InventoryAnalyticsSummary,
  InventoryAlertProduct,
  RevenueSummaryComparison,
  RevenueTrendPoint,
  SalesLedgerRow,
  TaxSummary,
  TopPerformingProduct,
} from '@/types/report';
import { getAuthHeaders } from './utils';

type DateInput = Date | string;

function toISOString(value: DateInput) {
  if (value instanceof Date) {
    return value.toISOString();
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error('Ngày không hợp lệ');
  }
  return parsed.toISOString();
}

async function postRpc<T>(functionName: string, payload: Record<string, unknown>): Promise<T> {
  const headers = await getAuthHeaders();
  const response = await fetch(`/api/rpc/${functionName}`, {
    method: 'POST',
    headers,
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new Error(errorData.error ?? `RPC ${functionName} failed`);
  }

  return response.json();
}

export const reportService = {
  getRevenueSummaryWithComparison: async (
    startDate: DateInput,
    endDate: DateInput,
  ): Promise<RevenueSummaryComparison> => {
    const payload = {
      p_start_date: toISOString(startDate),
      p_end_date: toISOString(endDate),
    };
    const result = await postRpc<RevenueSummaryComparison[]>('get_revenue_summary_with_comparison', payload);
    if (!Array.isArray(result) || result.length === 0) {
      throw new Error('Không nhận được dữ liệu doanh thu');
    }
    const summary = result[0];
    return {
      current_total_revenue: Number(summary.current_total_revenue ?? 0),
      current_total_profit: Number(summary.current_total_profit ?? 0),
      current_total_transactions: Number(summary.current_total_transactions ?? 0),
      previous_total_revenue: Number(summary.previous_total_revenue ?? 0),
      previous_total_profit: Number(summary.previous_total_profit ?? 0),
      previous_total_transactions: Number(summary.previous_total_transactions ?? 0),
      revenue_change_percentage: summary.revenue_change_percentage ?? null,
      profit_change_percentage: summary.profit_change_percentage ?? null,
      transactions_change_percentage: summary.transactions_change_percentage ?? null,
    };
  },

  getRevenueTrend: async (
    startDate: DateInput,
    endDate: DateInput,
    interval: 'day' | 'week' | 'month' = 'day',
  ): Promise<RevenueTrendPoint[]> => {
    const payload = {
      p_start_date: toISOString(startDate),
      p_end_date: toISOString(endDate),
      p_interval: interval,
    };
    const result = await postRpc<RevenueTrendPoint[]>('get_revenue_trend', payload);
    return Array.isArray(result)
      ? result.map((row) => ({
          date: row.date,
          revenue: Number(row.revenue ?? 0),
          transaction_count: Number(row.transaction_count ?? 0),
        }))
      : [];
  },

  getRevenueForWeek: async (startDate: DateInput): Promise<DailyRevenuePoint[]> => {
    const start = new Date(startDate);
    if (Number.isNaN(start.getTime())) {
      throw new Error('Ngày bắt đầu không hợp lệ');
    }
    const end = new Date(start);
    end.setDate(start.getDate() + 6);
    const trend = await reportService.getRevenueTrend(start, end, 'day');
    return trend.map((point) => ({
      date: point.date,
      revenue: point.revenue,
      transaction_count: point.transaction_count,
    }));
  },

  getTopPerformingProducts: async (
    startDate: DateInput,
    endDate: DateInput,
    options: { orderBy?: 'revenue' | 'profit'; limit?: number } = {},
  ): Promise<TopPerformingProduct[]> => {
    const payload = {
      p_start_date: toISOString(startDate),
      p_end_date: toISOString(endDate),
      p_order_by: options.orderBy ?? 'revenue',
      p_limit: options.limit ?? 5,
    };
    const result = await postRpc<TopPerformingProduct[]>('get_top_performing_products', payload);
    return Array.isArray(result)
      ? result.map((item) => ({
          product_id: item.product_id,
          product_name: item.product_name,
          total_quantity: Number(item.total_quantity ?? 0),
          total_revenue: Number(item.total_revenue ?? 0),
          total_profit: Number(item.total_profit ?? 0),
        }))
      : [];
  },

  getInventoryAnalytics: async (params: {
    lowStockThreshold?: number;
    expiringSoonDays?: number;
    slowMovingDays?: number;
  } = {}): Promise<InventoryAnalyticsCombined> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/reports/inventory-analytics', {
      method: 'POST',
      headers,
      body: JSON.stringify(params),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy phân tích tồn kho');
    }

    const payload = (await response.json()) as InventoryAnalyticsCombined;
    const summary = payload.summary as InventoryAnalyticsSummary;
    const alerts = payload.alerts as InventoryAnalyticsAlerts;

    return {
      summary: {
        total_inventory_value: Number(summary.total_inventory_value ?? 0),
        total_selling_value: Number(summary.total_selling_value ?? 0),
        potential_profit: Number(summary.potential_profit ?? 0),
        profit_margin: Number(summary.profit_margin ?? 0),
        total_items: Number(summary.total_items ?? 0),
        total_batches: Number(summary.total_batches ?? 0),
        low_stock_items: Number(summary.low_stock_items ?? 0),
        expiring_soon_items: Number(summary.expiring_soon_items ?? 0),
        slow_moving_items: Number(summary.slow_moving_items ?? 0),
      },
      alerts: {
        low_stock_products: Array.isArray(alerts.low_stock_products)
          ? (alerts.low_stock_products as InventoryAlertProduct[])
          : [],
        expiring_soon_products: Array.isArray(alerts.expiring_soon_products)
          ? (alerts.expiring_soon_products as InventoryAlertProduct[])
          : [],
        slow_moving_products: Array.isArray(alerts.slow_moving_products)
          ? (alerts.slow_moving_products as InventoryAlertProduct[])
          : [],
      },
    };
  },

  getInventoryAnalyticsLists: async (): Promise<InventoryAnalyticsLists> => {
    const result = await postRpc<Record<string, unknown>>('get_inventory_analytics_lists', {});
    const topValue = Array.isArray(result?.top_value_products)
      ? (result.top_value_products as InventoryAlertProduct[])
      : [];
    const fastTurnover = Array.isArray(result?.fast_turnover_products)
      ? (result.fast_turnover_products as InventoryAlertProduct[])
      : [];
    const slowTurnover = Array.isArray(result?.slow_turnover_products)
      ? (result.slow_turnover_products as InventoryAlertProduct[])
      : [];

    return {
      top_value_products: topValue,
      fast_turnover_products: fastTurnover,
      slow_turnover_products: slowTurnover,
    };
  },

  getLowStockProducts: async (threshold = 10): Promise<InventoryAlertProduct[]> => {
    const result = await postRpc<Record<string, unknown>>('get_inventory_alerts', {
      p_low_stock_threshold: threshold,
    });
    return Array.isArray(result?.low_stock_products)
      ? (result.low_stock_products as InventoryAlertProduct[])
      : [];
  },

  getSlowMovingProducts: async (days = 90): Promise<InventoryAlertProduct[]> => {
    const result = await postRpc<Record<string, unknown>>('get_inventory_alerts', {
      p_slow_moving_days: days,
    });
    return Array.isArray(result?.slow_moving_products)
      ? (result.slow_moving_products as InventoryAlertProduct[])
      : [];
  },

  getTaxSummary: async (startDate: DateInput, endDate: DateInput): Promise<TaxSummary> => {
    const headers = await getAuthHeaders();
    const params = new URLSearchParams({
      start: toISOString(startDate),
      end: toISOString(endDate),
    });
    const response = await fetch(`/api/reports/tax-summary?${params.toString()}`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy báo cáo thuế');
    }

    const payload = (await response.json()) as TaxSummary;
    return {
      total_revenue: Number(payload.total_revenue ?? 0),
      total_transactions: Number(payload.total_transactions ?? 0),
      total_expenses: Number(payload.total_expenses ?? 0),
      estimated_tax: Number(payload.estimated_tax ?? 0),
    };
  },

  exportSalesLedger: async (
    startDate: DateInput,
    endDate: DateInput,
  ): Promise<SalesLedgerRow[]> => {
    const payload = {
      p_start_date: toISOString(startDate),
      p_end_date: toISOString(endDate),
    };
    const result = await postRpc<SalesLedgerRow[]>('export_sales_ledger', payload);
    return Array.isArray(result) ? result : [];
  },
};

