import { useCallback, useEffect, useState } from 'react';
import { cachedProductService } from '@/lib/cache/cached-products';
import { Product } from '@/types/product';

type UseProductsState = {
  products: Product[];
  loading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
};

export function useProducts(): UseProductsState {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchProducts = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const result = await cachedProductService.getPaginated({ limit: 100 });
      setProducts(result.items);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Không thể tải sản phẩm';
      setError(message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void fetchProducts();
  }, [fetchProducts]);

  return { products, loading, error, refetch: fetchProducts };
}
