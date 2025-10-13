export type TransactionCustomer = {
  name?: string | null;
};

export type TransactionProductInfo = {
  name?: string | null;
  sku?: string | null;
};

export type TransactionItem = {
  id: string;
  transaction_id: string;
  product_id: string;
  batch_id?: string | null;
  quantity: number;
  price_at_sale: number;
  sub_total: number;
  discount_amount?: number | null;
  unit_id?: string | null;
  unit_name?: string | null;
  unit_conversion_factor?: number | null;
  base_unit_quantity?: number | null;
  created_at: string;
  store_id?: string;
  products?: TransactionProductInfo | null;
};

export type Transaction = {
  id: string;
  store_id: string;
  customer_id?: string | null;
  total_amount: number;
  surcharge_amount?: number | null;
  transaction_date: string;
  is_debt: boolean;
  payment_method: string;
  notes?: string | null;
  invoice_number?: string | null;
  created_by?: string | null;
  created_at: string;
  customers?: TransactionCustomer | null;
  transaction_items?: TransactionItem[];
  customer_name?: string | null;
};

export type CreateTransactionItemPayload = {
  productId: string;
  quantity: number;
  priceAtSale?: number;
  subTotal: number;
  discountAmount?: number;
  batchId?: string;
  unitId?: string;
  unitName?: string;
  unitConversionFactor?: number;
  baseUnitQuantity?: number;
};

export type CreateTransactionPayload = {
  customerId?: string;
  items: CreateTransactionItemPayload[];
  paymentMethod: string;
  notes?: string;
  debtDueDate?: string;
  surchargeAmount?: number;
  transactionDate?: string;
  invoiceNumber?: string;
};

export type CreateTransactionResponse = {
  transaction: Transaction;
  debtId?: string | null;
};

export type TransactionSearchFilters = {
  searchText?: string;
  startDate?: string;
  endDate?: string;
  minAmount?: number;
  maxAmount?: number;
  paymentMethods?: string[];
  customerIds?: string[];
  debtStatus?: 'paid' | 'unpaid' | 'all';
  includeItems?: boolean;
  page?: number;
  pageSize?: number;
};

export type TransactionSearchResult = {
  items: Transaction[];
  totalCount: number;
  offset: number;
  limit: number;
  hasNextPage: boolean;
};

export type TransactionPaginationParams = {
  page?: number;
  pageSize?: number;
};

export type TransactionHistoryParams = {
  customerId?: string;
  limit?: number;
};

export type TodaySalesStats = {
  today_revenue: number;
  today_transactions: number;
};
