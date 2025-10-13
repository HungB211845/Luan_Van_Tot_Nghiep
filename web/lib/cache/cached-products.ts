import { productService } from '@/lib/api/products';
import { Product, ProductListParams, ProductSearchResult } from '@/types/product';
import { memoryCache } from './memory-cache';
import { supabaseClient } from '@/lib/supabase/client';

const DEFAULT_PAGINATED_TTL_MS = 3 * 60 * 1000; // 3 minutes
const DEFAULT_SEARCH_TTL_MS = 2 * 60 * 1000; // 2 minutes
const DEFAULT_DASHBOARD_TTL_MS = 10 * 60 * 1000; // 10 minutes
const DEFAULT_LOW_STOCK_TTL_MS = 5 * 60 * 1000; // 5 minutes

let cachedStoreId: string | null = null;

async function getStoreKey(): Promise<string> {
  if (cachedStoreId) {
    return cachedStoreId;
  }

  const {
    data: { session },
  } = await supabaseClient.auth.getSession();

  cachedStoreId = (session?.user?.user_metadata?.store_id as string | undefined) ?? 'anonymous';
  return cachedStoreId;
}

function stableStringify(value: Record<string, unknown>): string {
  const sortedEntries = Object.entries(value)
    .filter(([, v]) => v !== undefined && v !== null)
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
  return JSON.stringify(sortedEntries);
}

async function buildKey(prefix: string, params: Record<string, unknown>): Promise<string> {
  const storeId = await getStoreKey();
  return `${prefix}::store=${storeId}::${stableStringify(params)}`;
}

function resetStoreKey() {
  cachedStoreId = null;
}

export const cachedProductService = {
  async getPaginated(
    params: ProductListParams = {},
    options: { useCache?: boolean; ttlMs?: number } = {},
  ): Promise<ProductSearchResult> {
    const useCache = options.useCache ?? true;
    const ttlMs = options.ttlMs ?? DEFAULT_PAGINATED_TTL_MS;

    const cacheKey = await buildKey('products:paginated', params);

    if (useCache) {
      const cached = memoryCache.get<ProductSearchResult>(cacheKey);
      if (cached) {
        return cached;
      }
    }

    const result = await productService.getPaginated(params);
    memoryCache.set(cacheKey, result, ttlMs);
    return result;
  },

  async getAll(options: { useCache?: boolean; ttlMs?: number } = {}): Promise<Product[]> {
    const useCache = options.useCache ?? true;
    const ttlMs = options.ttlMs ?? DEFAULT_PAGINATED_TTL_MS;
    const cacheKey = await buildKey('products:all', {});

    if (useCache) {
      const cached = memoryCache.get<Product[]>(cacheKey);
      if (cached) {
        return cached;
      }
    }

    const result = await productService.getAll();
    memoryCache.set(cacheKey, result, ttlMs);
    return result;
  },

  async search(
    query: string,
    params: Pick<ProductListParams, 'category' | 'limit' | 'offset'> = {},
    options: { useCache?: boolean; ttlMs?: number } = {},
  ): Promise<ProductSearchResult> {
    const normalizedQuery = query.trim();
    if (normalizedQuery.length === 0) {
      return {
        items: [],
        totalCount: 0,
        offset: params.offset ?? 0,
        limit: params.limit ?? 0,
        hasNextPage: false,
      };
    }

    const useCache = options.useCache ?? true;
    const ttlMs = options.ttlMs ?? DEFAULT_SEARCH_TTL_MS;

    const cacheKey = await buildKey('products:search', {
      query: normalizedQuery.toLowerCase(),
      ...params,
    });

    if (useCache) {
      const cached = memoryCache.get<ProductSearchResult>(cacheKey);
      if (cached) {
        return cached;
      }
    }

    const result = await productService.searchPaginated({
      query: normalizedQuery,
      category: params.category,
      limit: params.limit,
      offset: params.offset,
    });

    memoryCache.set(cacheKey, result, ttlMs);
    return result;
  },

  async getDashboardStats(options: { useCache?: boolean; ttlMs?: number } = {}) {
    const useCache = options.useCache ?? true;
    const ttlMs = options.ttlMs ?? DEFAULT_DASHBOARD_TTL_MS;
    const cacheKey = await buildKey('products:dashboard', {});

    if (useCache) {
      const cached = memoryCache.get<Record<string, unknown>>(cacheKey);
      if (cached) {
        return cached;
      }
    }

    const result = await productService.getProductDashboardStats();
    memoryCache.set(cacheKey, result, ttlMs, true);
    return result;
  },

  async getLowStockProducts(options: { useCache?: boolean; ttlMs?: number } = {}) {
    const useCache = options.useCache ?? true;
    const ttlMs = options.ttlMs ?? DEFAULT_LOW_STOCK_TTL_MS;
    const cacheKey = await buildKey('products:low-stock', {});

    if (useCache) {
      const cached = memoryCache.get<Record<string, unknown>[]>(cacheKey);
      if (cached) {
        return cached;
      }
    }

    const result = await productService.getLowStockProducts();
    memoryCache.set(cacheKey, result, ttlMs);
    return result;
  },

  async refreshMaterializedViews(): Promise<void> {
    await productService.refreshMaterializedViews();
    await this.invalidateProductCache();
    await this.invalidateDashboardCache();
  },

  async invalidateProductCache(): Promise<void> {
    memoryCache.invalidateWhere((key) => key.startsWith('products:paginated') || key.startsWith('products:all'));
  },

  async invalidateSearchCache(): Promise<void> {
    memoryCache.invalidateWhere((key) => key.startsWith('products:search'));
  },

  async invalidateDashboardCache(): Promise<void> {
    memoryCache.invalidateWhere((key) => key.startsWith('products:dashboard') || key.startsWith('products:low-stock'));
  },

  clearAll(): void {
    resetStoreKey();
    memoryCache.clear();
  },
};

