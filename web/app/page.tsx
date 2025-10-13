import Link from 'next/link';

export default function Home() {
  return (
    <main className="mx-auto flex min-h-screen max-w-4xl flex-col justify-center gap-10 px-6 py-16">
      <section className="space-y-4">
        <p className="text-sm uppercase tracking-wide text-green-600">Agricultural POS</p>
        <h1 className="text-4xl font-semibold">Quản lý nông sản của bạn với Next.js App Router</h1>
        <p className="text-base text-gray-600">
          Cấu trúc đã được tách bạch rõ ràng giữa View, ViewModel, Service và Backend tương tự kiến trúc
          Flutter của bạn. Bắt đầu với các tính năng chính dưới đây.
        </p>
      </section>

      <section className="grid gap-4 md:grid-cols-2">
        <Link
          href="/products"
          className="rounded-lg border border-gray-200 p-6 transition hover:border-green-500 hover:shadow"
        >
          <h2 className="text-xl font-semibold">Sản phẩm</h2>
          <p className="mt-2 text-sm text-gray-600">
            Xem danh sách sản phẩm, trạng thái tồn kho và giá bán.
          </p>
        </Link>
        <Link
          href="/pos"
          className="rounded-lg border border-gray-200 p-6 transition hover:border-blue-500 hover:shadow"
        >
          <h2 className="text-xl font-semibold">Điểm bán hàng</h2>
          <p className="mt-2 text-sm text-gray-600">
            Thao tác bán hàng và xử lý hoá đơn trực tiếp cho nhân viên.
          </p>
        </Link>
        <Link
          href="/auth/login"
          className="rounded-lg border border-gray-200 p-6 transition hover:border-purple-500 hover:shadow"
        >
          <h2 className="text-xl font-semibold">Đăng nhập</h2>
          <p className="mt-2 text-sm text-gray-600">
            Đăng nhập bằng tài khoản Supabase để truy cập dữ liệu cửa hàng và API bảo vệ.
          </p>
        </Link>
      </section>

      <section className="rounded-lg border border-dashed border-gray-300 p-6 text-sm text-gray-600">
        <p>
          Cấu trúc thư mục đã được chuẩn hoá: API Gateway nằm dưới <code>app/api</code>, các nhóm tính
          năng trong <code>app/(features)</code>, và service/hook/model được tổ chức trong{' '}
          <code>lib</code>, <code>hooks</code>, <code>types</code>.
        </p>
      </section>
    </main>
  );
}
