'use client';

import Link from 'next/link';
import { useCompanyProducts } from '@/hooks/use-company-products';
import { ProductCard } from '../../_components/product-card';

type CompanyProductsPageProps = {
  params: {
    companyId: string;
  };
};

export default function CompanyProductsPage({ params }: CompanyProductsPageProps) {
  const companyId = decodeURIComponent(params.companyId);
  const { products, loading, error, refetch } = useCompanyProducts(companyId);

  return (
    <section className="space-y-6">
      <header className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Sản phẩm theo nhà cung cấp</h1>
          <p className="text-sm text-gray-600">Nhà cung cấp: {companyId}</p>
        </div>
        <Link href="/products" className="rounded bg-gray-200 px-3 py-2 text-sm font-medium text-gray-700">
          ← Quay lại danh sách sản phẩm
        </Link>
      </header>

      {loading && <p>Đang tải danh sách sản phẩm...</p>}

      {error ? (
        <div className="space-y-3">
          <p className="text-red-500">Lỗi: {error}</p>
          <button
            type="button"
            onClick={refetch}
            className="rounded bg-blue-600 px-4 py-2 text-white"
          >
            Thử lại
          </button>
        </div>
      ) : null}

      {!loading && !error && products.length === 0 ? (
        <p className="text-sm text-gray-600">
          Không có sản phẩm nào thuộc nhà cung cấp <strong>{companyId}</strong>.
        </p>
      ) : null}

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {products.map((product) => (
          <ProductCard key={product.id} product={product} />
        ))}
      </div>
    </section>
  );
}

