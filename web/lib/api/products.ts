import {
  ExpiringBatch,
  LowStockProduct,
  Product,
  ProductBatch,
  ProductBatchResult,
  ProductListParams,
  ProductUnit,
  ProductSearchParams,
  ProductSearchResult,
} from '@/types/product';
import { getAuthHeaders } from './utils';

export const productService = {
  getPaginated: async (params: ProductListParams = {}): Promise<ProductSearchResult> => {
    const headers = await getAuthHeaders();
    const searchParams = new URLSearchParams();

    if (params.category) {
      searchParams.set('category', params.category);
    }

    if (params.companyId) {
      searchParams.set('companyId', params.companyId);
    }

    if (typeof params.limit === 'number') {
      searchParams.set('limit', params.limit.toString());
    }

    if (typeof params.offset === 'number') {
      searchParams.set('offset', params.offset.toString());
    }

    if (params.sortBy) {
      searchParams.set('sortBy', params.sortBy);
    }

    if (typeof params.ascending === 'boolean') {
      searchParams.set('ascending', String(params.ascending));
    }

    const response = await fetch(`/api/products?${searchParams.toString()}`, { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to fetch products');
    }

    const payload = await response.json();
    const limitValue = payload.limit ?? params?.limit ?? 50;
    const offsetValue = payload.offset ?? params?.offset ?? 0;
    const total = payload.totalCount ?? payload.total ?? 0;
    return {
      items: payload.items ?? [],
      totalCount: total,
      offset: offsetValue,
      limit: limitValue,
      hasNextPage: payload.hasNextPage ?? offsetValue + limitValue < total,
    };
  },

  getAll: async (): Promise<Product[]> => {
    const items: Product[] = [];
    let offset = 0;
    const limit = 100;

    while (true) {
      const result = await productService.getPaginated({ limit, offset });
      items.push(...result.items);

      if (!result.hasNextPage) {
        break;
      }

      const nextOffset = result.offset + result.limit;
      if (nextOffset <= offset) {
        break;
      }
      offset = nextOffset;
    }

    return items;
  },

  getByCompany: async (companyId?: string): Promise<Product[]> => {
    if (!companyId) {
      return productService.getAll();
    }

    const items: Product[] = [];
    let offset = 0;
    const limit = 100;

    while (true) {
      const result = await productService.getPaginated({ companyId, limit, offset });
      items.push(...result.items);

      if (!result.hasNextPage) {
        break;
      }

      const nextOffset = result.offset + result.limit;
      if (nextOffset <= offset) {
        break;
      }
      offset = nextOffset;
    }

    return items;
  },

  getById: async (id: string): Promise<Product> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/products/${id}`, { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to fetch product');
    }

    return response.json();
  },

  searchPaginated: async (params: ProductSearchParams): Promise<ProductSearchResult> => {
    const headers = await getAuthHeaders();
    const searchParams = new URLSearchParams({ q: params.query });

    if (params.category) {
      searchParams.set('category', params.category);
    }

    if (typeof params.minPrice === 'number') {
      searchParams.set('minPrice', params.minPrice.toString());
    }

    if (typeof params.maxPrice === 'number') {
      searchParams.set('maxPrice', params.maxPrice.toString());
    }

    if (typeof params.inStock === 'boolean') {
      searchParams.set('inStock', String(params.inStock));
    }

    if (typeof params.limit === 'number') {
      searchParams.set('limit', params.limit.toString());
    }

    if (typeof params.offset === 'number') {
      searchParams.set('offset', params.offset.toString());
    }

    const response = await fetch(`/api/products/search?${searchParams.toString()}`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to search products');
    }

    const payload = await response.json();
    const limitValue = payload.limit ?? params?.limit ?? 50;
    const offsetValue = payload.offset ?? params?.offset ?? 0;
    const total = payload.totalCount ?? payload.total ?? 0;
    return {
      items: payload.items ?? [],
      totalCount: total,
      offset: offsetValue,
      limit: limitValue,
      hasNextPage: payload.hasNextPage ?? offsetValue + limitValue < total,
    };
  },

  search: async (query: string): Promise<Product[]> => {
    const result = await productService.searchPaginated({ query, limit: 50 });
    return result.items;
  },

  getBatchesPaginated: async (productId: string, params?: { limit?: number; offset?: number }): Promise<ProductBatchResult> => {
    const headers = await getAuthHeaders();
    const searchParams = new URLSearchParams();

    if (params?.limit) {
      searchParams.set('limit', params.limit.toString());
    }

    if (params?.offset) {
      searchParams.set('offset', params.offset.toString());
    }

    const queryString = searchParams.toString();
    const response = await fetch(
      `/api/products/${encodeURIComponent(productId)}/batches${queryString ? `?${queryString}` : ''}`,
      { headers },
    );

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to fetch product batches');
    }

    const payload = await response.json();
    const limitValue = payload.limit ?? params.limit ?? 50;
    const offsetValue = payload.offset ?? params.offset ?? 0;
    return {
      items: payload.items ?? [],
      totalCount: payload.totalCount ?? payload.total ?? 0,
      offset: offsetValue,
      limit: limitValue,
      hasNextPage: payload.hasNextPage ?? ((payload.totalCount ?? payload.total ?? 0) > offsetValue + limitValue),
    };
  },

  getBatches: async (productId: string): Promise<ProductBatchResult['items']> => {
    const pageSize = 100;
    let offset = 0;
    const items: ProductBatchResult['items'] = [];

    // Loop until no more pages
    while (true) {
      const result = await productService.getBatchesPaginated(productId, { limit: pageSize, offset });
      items.push(...result.items);

      if (!result.hasNextPage) {
        break;
      }

      const nextOffset = result.offset + result.limit;

      // Prevent infinite loops by ensuring offset increases
      if (nextOffset <= offset) {
        break;
      }

      offset = nextOffset;
    }

    return items;
  },

  getProductUnits: async (productId: string): Promise<ProductUnit[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/rpc/get_product_units', {
      method: 'POST',
      headers,
      body: JSON.stringify({ p_product_id: productId }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to fetch product units');
    }

    const payload = await response.json();
    return Array.isArray(payload) ? (payload as ProductUnit[]) : [];
  },

  getDefaultUnit: async (productId: string): Promise<ProductUnit | null> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/products/${encodeURIComponent(productId)}/units/default`, { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to fetch default unit');
    }

    const payload = await response.json();
    return (payload.item as ProductUnit | null) ?? null;
  },

  createProductUnit: async (productId: string, payload: Record<string, unknown>): Promise<ProductUnit> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/products/${encodeURIComponent(productId)}/units`, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      const message = errorData.error ?? 'Failed to create product unit';
      if (message.includes('product_units_unique_name_per_product')) {
        throw new Error('Đơn vị đã tồn tại cho sản phẩm này');
      }
      throw new Error(message);
    }

    return response.json();
  },

  updateProductUnit: async (unitId: string, payload: Record<string, unknown>): Promise<ProductUnit> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/product-units/${encodeURIComponent(unitId)}`, {
      method: 'PATCH',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to update product unit');
    }

    return response.json();
  },

  deleteProductUnit: async (unitId: string): Promise<void> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/product-units/${encodeURIComponent(unitId)}`, {
      method: 'DELETE',
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to delete product unit');
    }
  },

  setDefaultUnit: async (productId: string, unitId: string): Promise<ProductUnit> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/products/${encodeURIComponent(productId)}/units/${encodeURIComponent(unitId)}`, {
      method: 'POST',
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to set default unit');
    }

    return response.json();
  },

  checkStockAvailability: async (productId: string, quantity: number, unitId: string): Promise<boolean> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/rpc/check_stock_availability', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        p_product_id: productId,
        p_quantity: quantity,
        p_unit_id: unitId,
      }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to check stock availability');
    }

    const payload = await response.json();
    return Boolean(payload);
  },

  getAvailableStockBaseUnit: async (productId: string): Promise<number> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/rpc/get_available_stock_base_unit', {
      method: 'POST',
      headers,
      body: JSON.stringify({ p_product_id: productId }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to get available stock base unit');
    }

    const payload = await response.json();
    return typeof payload === 'number' ? payload : Number(payload ?? 0);
  },

  addBatch: async (productId: string, payload: Record<string, unknown>): Promise<ProductBatch> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/products/${encodeURIComponent(productId)}/batches`, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to add product batch');
    }

    return response.json();
  },

  updateBatch: async (
    productId: string,
    batchId: string,
    payload: Record<string, unknown>,
  ): Promise<ProductBatchResult['items'][number]> => {
    const headers = await getAuthHeaders();
    const response = await fetch(
      `/api/products/${encodeURIComponent(productId)}/batches/${encodeURIComponent(batchId)}`,
      {
        method: 'PATCH',
        headers,
        body: JSON.stringify(payload),
      },
    );

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to update product batch');
    }

    return response.json();
  },

  deleteBatch: async (batchId: string): Promise<void> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/product-batches/${encodeURIComponent(batchId)}`, {
      method: 'DELETE',
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to delete product batch');
    }
  },

  getAvailableStock: async (productId: string): Promise<number> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/products/${encodeURIComponent(productId)}/stock`, { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to get available stock');
    }

    const payload = await response.json();
    return payload.stock ?? 0;
  },

  getExpiringBatches: async (months?: number): Promise<ExpiringBatch[]> => {
    const headers = await getAuthHeaders();
    const searchParams = new URLSearchParams();
    if (months && months > 0) {
      searchParams.set('months', months.toString());
    }

    const queryString = searchParams.toString();
    const response = await fetch(
      `/api/inventory/expiring-batches${queryString ? `?${queryString}` : ''}`,
      { headers },
    );

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to fetch expiring batches');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  getLowStockProducts: async (): Promise<LowStockProduct[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/inventory/low-stock', { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to fetch low stock products');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  quickAddBatch: async (
    productId: string,
    payload: {
      quantity: number;
      costPrice: number;
      newSellingPrice: number;
      unitId?: string;
      batchNumber?: string;
      expiryDate?: string;
      notes?: string;
      reason?: string;
    },
  ): Promise<Product> => {
    const headers = await getAuthHeaders();
    const response = await fetch(
      `/api/products/${encodeURIComponent(productId)}/quick-add-batch`,
      {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
      },
    );

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to quick add batch');
    }

    const updatedProduct = await response.json();
    return updatedProduct as Product;
  },

  quickSearchForPOS: async (query: string): Promise<Product[]> => {
    const headers = await getAuthHeaders();
    const searchParams = new URLSearchParams({ q: query });
    const response = await fetch(`/api/products/pos-search?${searchParams.toString()}`, { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to search products for POS');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  scanBySKU: async (sku: string): Promise<Product | null> => {
    const headers = await getAuthHeaders();
    const searchParams = new URLSearchParams({ sku });
    const response = await fetch(`/api/products/scan?${searchParams.toString()}`, { headers });

    if (response.status === 404) {
      return null;
    }

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to scan product by SKU');
    }

    const payload = await response.json();
    return payload.item ?? null;
  },

  create: async (payload: Record<string, unknown>): Promise<Product> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/products', {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to create product');
    }

    return response.json();
  },

  update: async (id: string, payload: Record<string, unknown>): Promise<Product> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/products/${encodeURIComponent(id)}`, {
      method: 'PUT',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to update product');
    }

    return response.json();
  },

  delete: async (id: string): Promise<void> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/products/${encodeURIComponent(id)}`, {
      method: 'DELETE',
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to delete product');
    }
  },

  getCurrentPrice: async (id: string): Promise<number> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/products/${encodeURIComponent(id)}/current-price`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to get current price');
    }

    const payload = await response.json();
    return payload.price ?? 0;
  },

  updateCurrentSellingPrice: async (id: string, newPrice: number, reason?: string): Promise<boolean> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/products/${encodeURIComponent(id)}/current-price`, {
      method: 'PATCH',
      headers,
      body: JSON.stringify({ newPrice, reason }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to update product price');
    }

    const payload = await response.json().catch(() => ({}));
    return payload?.success !== false;
  },

  calculateAverageCostPrice: async (id: string): Promise<number> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/rpc/get_average_cost_price', {
      method: 'POST',
      headers,
      body: JSON.stringify({ p_product_id: id }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to calculate average cost price');
    }

    const value = await response.json();
    return (value ?? 0) as number;
  },

  calculateGrossProfitPercentage: async (id: string): Promise<number> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/rpc/get_gross_profit_percentage', {
      method: 'POST',
      headers,
      body: JSON.stringify({ p_product_id: id }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to calculate gross profit percentage');
    }

    const value = await response.json();
    return (value ?? 0) as number;
  },

  getPriceHistory: async (id: string, limit = 20): Promise<Record<string, unknown>[]> => {
    const headers = await getAuthHeaders();
    const searchParams = new URLSearchParams({ limit: String(limit) });
    const response = await fetch(
      `/api/products/${encodeURIComponent(id)}/price-history?${searchParams.toString()}`,
      { headers },
    );

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to fetch price history');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  getSeasonalPrices: async (productId: string): Promise<Record<string, unknown>[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/products/${encodeURIComponent(productId)}/seasonal-prices`, {
      headers,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to fetch seasonal prices');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  addSeasonalPrice: async (productId: string, payload: Record<string, unknown>) => {
    const headers = await getAuthHeaders();
    const response = await fetch(`/api/products/${encodeURIComponent(productId)}/seasonal-prices`, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to add seasonal price');
    }

    return response.json();
  },

  updateSeasonalPrice: async (
    productId: string,
    priceId: string,
    payload: Record<string, unknown>,
  ): Promise<Record<string, unknown>> => {
    const headers = await getAuthHeaders();
    const response = await fetch(
      `/api/products/${encodeURIComponent(productId)}/seasonal-prices/${encodeURIComponent(priceId)}`,
      {
        method: 'PATCH',
        headers,
        body: JSON.stringify(payload),
      },
    );

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to update seasonal price');
    }

    return response.json();
  },

  deleteSeasonalPrice: async (productId: string, priceId: string): Promise<void> => {
    const headers = await getAuthHeaders();
    const response = await fetch(
      `/api/products/${encodeURIComponent(productId)}/seasonal-prices/${encodeURIComponent(priceId)}`,
      {
        method: 'DELETE',
        headers,
      },
    );

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to delete seasonal price');
    }
  },

  getBannedSubstances: async (): Promise<Record<string, unknown>[]> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/banned-substances', { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to fetch banned substances');
    }

    const payload = await response.json();
    return payload.items ?? [];
  },

  addBannedSubstance: async (payload: Record<string, unknown>) => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/banned-substances', {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to add banned substance');
    }

    return response.json();
  },

  checkBannedSubstance: async (activeIngredient: string): Promise<boolean> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/banned-substances/check', {
      method: 'POST',
      headers,
      body: JSON.stringify({ activeIngredient }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to check banned substance');
    }

    const payload = await response.json();
    return Boolean(payload.isBanned);
  },

  getProductDashboardStats: async (): Promise<{ total_products: number; low_stock_count: number; expiring_batches_count: number }> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/products/dashboard', { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to fetch product dashboard stats');
    }

    return response.json();
  },

  getTotalProductsCount: async (): Promise<number> => {
    const headers = await getAuthHeaders();
    const response = await fetch('/api/products/count', { headers });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error ?? 'Failed to fetch product count');
    }

    const payload = await response.json();
    return payload.total ?? payload.totalCount ?? 0;
  },
};
