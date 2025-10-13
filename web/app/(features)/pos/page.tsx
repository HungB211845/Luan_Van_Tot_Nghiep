'use client';

import Link from 'next/link';

export default function PosPage() {
  return (
    <section className="space-y-6">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Điểm bán hàng</h1>
          <p className="text-sm text-gray-600">Màn hình bán hàng trực tiếp cho nhân viên thu ngân</p>
        </div>
        <Link href="/products" className="rounded bg-blue-600 px-4 py-2 text-white">
          Trở về sản phẩm
        </Link>
      </header>
      <p className="text-gray-700">
        Khu vực này sẽ hiển thị UI POS (giỏ hàng, hình thức thanh toán, khách hàng, v.v.).
      </p>
      <div className="rounded-md border border-dashed border-gray-300 p-6 text-sm text-gray-500">
        Thêm các component chuyên biệt của POS trong thư mục{' '}
        <code>app/(features)/pos/_components</code> để tái sử dụng giữa các phần của màn hình.
      </div>
    </section>
  );
}

