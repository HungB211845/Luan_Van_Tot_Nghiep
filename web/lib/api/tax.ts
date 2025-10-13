import { SalesLedgerRow, TaxSummary } from '@/types/report';
import { getAuthHeaders } from './utils';

type DateLike = Date | string;

function toIsoString(value: DateLike) {
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

function toCsv(rows: SalesLedgerRow[]): string {
  if (!rows.length) {
    return '';
  }

  const headers = Object.keys(rows[0]);
  const escape = (value: unknown) => {
    if (value == null) {
      return '';
    }
    const str = String(value);
    if (/[",\n]/.test(str)) {
      return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
  };

  const lines = rows.map((row) => headers.map((key) => escape(row[key])).join(','));
  return `${headers.join(',')}\n${lines.join('\n')}`;
}

export const taxService = {
  getTaxSummary: async (startDate: DateLike, endDate: DateLike): Promise<TaxSummary> => {
    const payload = {
      p_start_date: toIsoString(startDate),
      p_end_date: toIsoString(endDate),
    };
    const response = await postRpc<Record<string, unknown>>('get_tax_summary', payload);
    return {
      total_revenue: Number(response.total_revenue ?? 0),
      total_transactions: Number(response.total_transactions ?? 0),
      total_expenses: Number(response.total_expenses ?? 0),
      estimated_tax: Number(response.estimated_tax ?? 0),
    };
  },

  getSalesLedgerForExport: async (
    startDate: DateLike,
    endDate: DateLike,
  ): Promise<SalesLedgerRow[]> => {
    const payload = {
      p_start_date: toIsoString(startDate),
      p_end_date: toIsoString(endDate),
    };
    const response = await postRpc<SalesLedgerRow[]>('get_sales_ledger_for_export', payload);
    return Array.isArray(response) ? response : [];
  },

  exportSalesLedgerToCSV: async (
    startDate: DateLike,
    endDate: DateLike,
  ): Promise<string> => {
    const rows = await taxService.getSalesLedgerForExport(startDate, endDate);
    return toCsv(rows);
  },
};

