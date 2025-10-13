import {
  CreateTransactionPayload,
  CreateTransactionResponse,
  TodaySalesStats,
  Transaction,
  TransactionHistoryParams,
  TransactionItem,
  TransactionPaginationParams,
  TransactionSearchFilters,
  TransactionSearchResult,
} from '@/types/transaction';
import { getAuthHeaders } from './utils';

function toIsoString(value?: string) {
  if (!value) {
    return undefined;
  }

  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? undefined : date.toISOString();
}

function generateItemId(transactionId: string, index: number) {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  return `${transactionId}-item-${index}`;
}

function mapTransactionItem(raw: Record<string, any>, transactionId: string, index = 0): TransactionItem {
  const productId = raw.product_id ?? raw.productId;
  const quantity = Number(raw.quantity ?? raw.qty ?? 0);
  const priceAtSale = Number(
    raw.price_at_sale ?? raw.unit_price ?? raw.priceAtSale ?? raw.unitPrice ?? 0,
  );
  const subTotal = Number(raw.sub_total ?? raw.subTotal ?? raw.total ?? priceAtSale * quantity);

  return {
    id: String(raw.id ?? raw.transaction_item_id ?? productId ?? generateItemId(transactionId, index)),
    transaction_id: String(raw.transaction_id ?? raw.transactionId ?? transactionId),
    product_id: String(productId ?? ''),
    batch_id: raw.batch_id ?? raw.batchId ?? null,
    quantity,
    price_at_sale: priceAtSale,
    sub_total: subTotal,
    discount_amount:
      raw.discount_amount !== undefined ? Number(raw.discount_amount) : raw.discountAmount,
    unit_id: raw.unit_id ?? raw.unitId ?? null,
    unit_name: raw.unit_name ?? raw.unitName ?? null,
    unit_conversion_factor:
      raw.unit_conversion_factor !== undefined
        ? Number(raw.unit_conversion_factor)
        : raw.unitConversionFactor ?? null,
    base_unit_quantity:
      raw.base_unit_quantity !== undefined
        ? Number(raw.base_unit_quantity)
        : raw.baseUnitQuantity ?? null,
    created_at: raw.created_at ?? raw.createdAt ?? new Date().toISOString(),
    store_id: raw.store_id ?? raw.storeId,
    products:
      raw.products ??
      (raw.product_name || raw.product_sku
        ? { name: raw.product_name ?? raw.productName, sku: raw.product_sku ?? raw.productSku }
        : undefined),
  };
}

function parseItemsFromRpc(itemsJson: unknown, transactionId: string) {
  if (!itemsJson) {
    return undefined;
  }

  let payload: unknown;
  if (typeof itemsJson === 'string') {
    try {
      payload = JSON.parse(itemsJson);
    } catch (error) {
      console.warn('Failed to parse items_json for transaction', transactionId, error);
      return undefined;
    }
  } else if (Array.isArray(itemsJson)) {
    payload = itemsJson;
  } else if (typeof itemsJson === 'object' && itemsJson !== null && 'items' in itemsJson) {
    payload = (itemsJson as Record<string, unknown>).items;
  } else {
    payload = itemsJson;
  }

  if (!Array.isArray(payload)) {
    return undefined;
  }

  return payload.map((item, index) => mapTransactionItem(item as Record<string, unknown>, transactionId, index));
}

function normalizeTransaction(raw: Record<string, any>): Transaction {
  const id = String(raw.id);
  const transactionItems = Array.isArray(raw.transaction_items)
    ? raw.transaction_items.map((item: Record<string, unknown>, index: number) =>
        mapTransactionItem(item, id, index),
      )
    : parseItemsFromRpc(raw.items_json, id);

  const surcharge =
    raw.surcharge_amount !== undefined && raw.surcharge_amount !== null
      ? Number(raw.surcharge_amount)
      : undefined;

  const totalAmount = Number(raw.total_amount ?? raw.totalAmount ?? 0);

  return {
    id,
    store_id: String(raw.store_id ?? raw.storeId ?? ''),
    customer_id: raw.customer_id ?? raw.customerId ?? null,
    total_amount: totalAmount,
    surcharge_amount: surcharge,
    transaction_date: raw.transaction_date ?? raw.transactionDate ?? new Date().toISOString(),
    is_debt: Boolean(raw.is_debt ?? raw.isDebt),
    payment_method: raw.payment_method ?? raw.paymentMethod ?? '',
    notes: raw.notes ?? null,
    invoice_number: raw.invoice_number ?? raw.invoiceNumber ?? null,
    created_by: raw.created_by ?? raw.createdBy ?? null,
    created_at: raw.created_at ?? raw.createdAt ?? new Date().toISOString(),
    customers: raw.customers ?? (raw.customer_name ? { name: raw.customer_name } : null),
    customer_name: raw.customer_name ?? raw.customers?.name ?? null,
    transaction_items: transactionItems,
  };
}

function buildSearchPayload(filters: TransactionSearchFilters) {
  return {
    p_search_text: filters.searchText ?? null,
    p_start_date: toIsoString(filters.startDate) ?? null,
    p_end_date: toIsoString(filters.endDate) ?? null,
    p_min_amount: typeof filters.minAmount === 'number' ? filters.minAmount : null,
    p_max_amount: typeof filters.maxAmount === 'number' ? filters.maxAmount : null,
    p_payment_methods: filters.paymentMethods?.length ? filters.paymentMethods : null,
    p_customer_ids: filters.customerIds?.length ? filters.customerIds : null,
    p_debt_status: filters.debtStatus && filters.debtStatus !== 'all' ? filters.debtStatus : null,
    p_include_items: Boolean(filters.includeItems),
    p_page: filters.page ?? 1,
    p_page_size: filters.pageSize ?? 20,
  };
}

function buildPaginationResult(
  items: Transaction[],
  totalCount: number,
  page: number,
  pageSize: number,
): TransactionSearchResult {
  const offset = (page - 1) * pageSize;
  return {
    items,
    totalCount,
    offset,
    limit: pageSize,
    hasNextPage: offset + pageSize < totalCount,
  };
}

export const transactionService = {
  create: async (payload: CreateTransactionPayload): Promise<CreateTransactionResponse> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/transactions', {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi tạo giao dịch');
    }

    const result = await response.json();
    return {
      transaction: normalizeTransaction(result.transaction),
      debtId: result.debtId ?? null,
    };
  },

  search: async (filters: TransactionSearchFilters = {}): Promise<TransactionSearchResult> => {
    const headers = await getAuthHeaders();
    const searchPayload = buildSearchPayload(filters);
    const response = await fetch('/api/rpc/search_transactions_with_items', {
      method: 'POST',
      headers,
      body: JSON.stringify(searchPayload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi tìm kiếm giao dịch');
    }

    const payload = await response.json();
    const rows: Record<string, any>[] = Array.isArray(payload) ? payload : [];

    if (!rows.length) {
      return buildPaginationResult([], 0, searchPayload.p_page, searchPayload.p_page_size);
    }

    const totalCount = Number(rows[0].total_count ?? rows.length);
    const items = rows.map(normalizeTransaction);

    return buildPaginationResult(items, totalCount, searchPayload.p_page, searchPayload.p_page_size);
  },

  getHistoryPaginated: async (
    params: TransactionPaginationParams = {},
    customerId?: string,
  ): Promise<TransactionSearchResult> => {
    return transactionService.search({
      customerIds: customerId ? [customerId] : undefined,
      page: params.page,
      pageSize: params.pageSize,
    });
  },

  searchPaginated: async (
    query: string,
    params: TransactionPaginationParams = {},
  ): Promise<TransactionSearchResult> => {
    return transactionService.search({
      searchText: query,
      page: params.page,
      pageSize: params.pageSize,
    });
  },

  getDebtTransactionsPaginated: async (
    params: TransactionPaginationParams = {},
    customerId?: string,
  ): Promise<TransactionSearchResult> => {
    return transactionService.search({
      customerIds: customerId ? [customerId] : undefined,
      debtStatus: 'unpaid',
      page: params.page,
      pageSize: params.pageSize,
    });
  },

  getTodayTransactionsPaginated: async (
    params: TransactionPaginationParams = {},
    customerId?: string,
  ): Promise<TransactionSearchResult> => {
    const today = new Date();
    const start = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const end = new Date(start);
    end.setDate(start.getDate() + 1);

    return transactionService.search({
      customerIds: customerId ? [customerId] : undefined,
      startDate: start.toISOString(),
      endDate: end.toISOString(),
      page: params.page,
      pageSize: params.pageSize,
    });
  },

  getHistory: async (params: TransactionHistoryParams = {}): Promise<Transaction[]> => {
    const headers = await getAuthHeaders();
    const searchParams = new URLSearchParams();

    if (params.customerId) {
      searchParams.set('customerId', params.customerId);
    }

    if (typeof params.limit === 'number') {
      searchParams.set('limit', params.limit.toString());
    }

    const response = await fetch(
      `/api/transactions/history${searchParams.toString() ? `?${searchParams}` : ''}`,
      { headers },
    );

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy lịch sử giao dịch');
    }

    const payload = await response.json();
    const items: Record<string, any>[] = Array.isArray(payload.items) ? payload.items : [];
    return items.map(normalizeTransaction);
  },

  getItems: async (transactionId: string): Promise<TransactionItem[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch(
      `/api/transactions/${encodeURIComponent(transactionId)}/items`,
      { headers },
    );

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy danh sách sản phẩm của giao dịch');
    }

    const payload = await response.json();
    const items: Record<string, any>[] = Array.isArray(payload.items) ? payload.items : [];
    return items.map((item, index) => mapTransactionItem(item, transactionId, index));
  },

  getWithItems: async (transactionId: string): Promise<Transaction> => {
    const headers = await getAuthHeaders();
    const response = await fetch(
      `/api/transactions/${encodeURIComponent(transactionId)}?include=items`,
      { headers },
    );

    if (response.status === 404) {
      throw new Error('Giao dịch không tồn tại');
    }

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy thông tin giao dịch');
    }

    const payload = await response.json();
    return normalizeTransaction(payload);
  },

  getById: async (transactionId: string): Promise<Transaction> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/transactions/${encodeURIComponent(transactionId)}`, {
      headers,
    });

    if (response.status === 404) {
      throw new Error('Giao dịch không tồn tại');
    }

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy thông tin giao dịch');
    }

    const payload = await response.json();
    return normalizeTransaction(payload);
  },

  getDebtTransactions: async (customerId?: string): Promise<Transaction[]> => {
    const headers = await getAuthHeaders();
    const searchParams = new URLSearchParams({ isDebt: 'true' });

    if (customerId) {
      searchParams.set('customerId', customerId);
    }

    searchParams.set('limit', '100');

    const response = await fetch(`/api/transactions?${searchParams.toString()}`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy danh sách giao dịch nợ');
    }

    const payload = await response.json();
    const items: Record<string, any>[] = Array.isArray(payload.items) ? payload.items : [];
    return items.map(normalizeTransaction);
  },

  getTodaySalesStats: async (): Promise<TodaySalesStats> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/transactions/today-summary', { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Lỗi lấy thống kê bán hàng hôm nay');
    }

    const payload = await response.json();
    return {
      today_revenue: Number(payload.today_revenue ?? 0),
      today_transactions: Number(payload.today_transactions ?? 0),
    };
  },
};

