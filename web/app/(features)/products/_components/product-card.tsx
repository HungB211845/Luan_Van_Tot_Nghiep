'use client';

import { Product } from '@/types/product';

type ProductCardProps = {
  product: Product;
};

export function ProductCard({ product }: ProductCardProps) {
  return (
    <article className="rounded-md border border-gray-200 p-4 shadow-sm">
      <h2 className="text-lg font-semibold">{product.name}</h2>
      <dl className="mt-2 space-y-1 text-sm">
        <div className="flex justify-between">
          <dt className="font-medium text-gray-500">Giá</dt>
          <dd className="font-semibold text-gray-900">
            {product.price.toLocaleString('vi-VN', { style: 'currency', currency: 'VND' })}
          </dd>
        </div>
        <div className="flex justify-between text-gray-600">
          <dt>Mã</dt>
          <dd>{product.id}</dd>
        </div>
      </dl>
    </article>
  );
}

