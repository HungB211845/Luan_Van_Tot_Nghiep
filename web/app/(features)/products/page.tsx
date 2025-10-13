'use client';

import Link from 'next/link';
import { ProductCard } from './_components/product-card';
import { useProducts } from '@/hooks/use-products';

export default function ProductsPage() {
  const { products, loading, error, refetch } = useProducts();

  if (loading) {
    return <p>Đang tải danh sách sản phẩm...</p>;
  }

  if (error) {
    const requiresLogin = /đăng nhập/i.test(error);
    return (
      <div className="space-y-3">
        <p className="text-red-500">Lỗi: {error}</p>
        {requiresLogin ? (
          <Link
            href="/auth/login?redirect=/products"
            className="inline-flex w-fit items-center justify-center rounded bg-green-600 px-4 py-2 text-white"
          >
            Đăng nhập để tiếp tục
          </Link>
        ) : (
          <button
            type="button"
            className="rounded bg-blue-600 px-4 py-2 text-white"
            onClick={refetch}
          >
            Thử lại
          </button>
        )}
      </div>
    );
  }

  return (
    <section className="space-y-6">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Sản phẩm</h1>
          <p className="text-sm text-gray-600">Danh sách sản phẩm của cửa hàng bạn</p>
        </div>
        <Link href="/pos" className="rounded bg-green-600 px-4 py-2 text-white">
          Đi tới POS
        </Link>
      </header>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {products.map((product) => (
          <ProductCard key={product.id} product={product} />
        ))}
      </div>
    </section>
  );
}
