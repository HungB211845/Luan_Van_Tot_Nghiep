import { useCallback, useEffect, useMemo, useState } from 'react';
import { productService } from '@/lib/api/products';
import { Product } from '@/types/product';

type UseCompanyProductsState = {
  products: Product[];
  loading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
};

export function useCompanyProducts(companyId?: string | null): UseCompanyProductsState {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState<boolean>(Boolean(companyId));
  const [error, setError] = useState<string | null>(null);

  const normalizedCompanyId = useMemo(() => companyId?.trim() ?? '', [companyId]);

  const fetchProducts = useCallback(async () => {
    if (!normalizedCompanyId) {
      setProducts([]);
      setLoading(false);
      setError(null);
      return;
    }

    try {
      setLoading(true);
      setError(null);
      const data = await productService.getByCompany(normalizedCompanyId);
      setProducts(data);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Không thể tải sản phẩm theo nhà cung cấp';
      setError(message);
    } finally {
      setLoading(false);
    }
  }, [normalizedCompanyId]);

  useEffect(() => {
    void fetchProducts();
  }, [fetchProducts]);

  return { products, loading, error, refetch: fetchProducts };
}

