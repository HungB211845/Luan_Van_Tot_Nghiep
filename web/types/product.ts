export interface Product {
  id: string;
  name: string;
  price: number;
  store_id: string;
  description?: string;
  sku?: string;
  image_url?: string;
}

export type ProductSearchParams = {
  query: string;
  category?: string;
  minPrice?: number;
  maxPrice?: number;
  inStock?: boolean;
  limit?: number;
  offset?: number;
};

export type ProductListParams = {
  category?: string;
  companyId?: string;
  limit?: number;
  offset?: number;
  sortBy?: 'name' | 'price' | 'stock' | 'created_at' | 'updated_at';
  ascending?: boolean;
};

export type ProductSearchResult = {
  items: Product[];
  totalCount: number;
  offset: number;
  limit: number;
  hasNextPage: boolean;
};

export type ProductBatch = {
  id: string;
  product_id: string;
  quantity: number;
  cost_price: number;
  batch_number?: string;
  received_date?: string;
  expiry_date?: string | null;
  notes?: string | null;
  is_available: boolean;
  [key: string]: unknown;
};

export type ProductBatchResult = {
  items: ProductBatch[];
  totalCount: number;
  offset: number;
  limit: number;
  hasNextPage: boolean;
};

export type ProductUnit = {
  id: string;
  product_id: string;
  store_id: string;
  unit_name: string;
  conversion_factor: number;
  is_default_selling_unit: boolean;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
};

export type ExpiringBatch = {
  id: string;
  product_id: string;
  batch_number?: string | null;
  quantity: number;
  expiry_date?: string | null;
  days_until_expiry?: number | null;
  product_name?: string | null;
  product_sku?: string | null;
};

export type LowStockProduct = {
  id: string;
  name: string;
  sku?: string | null;
  category?: string | null;
  min_stock_level?: number | null;
  current_stock?: number | null;
  company_name?: string | null;
};
