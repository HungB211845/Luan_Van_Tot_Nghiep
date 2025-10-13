# Quy Trình Chuyển Provider Flutter Sang Next.js

1. **Đọc Provider gốc trong Flutter**
   - Vào `lib/.../providers/*.dart`, duyệt từng provider.
   - Ghi lại toàn bộ state riêng (biến private, enum trạng thái), các getter, setter, và method bất đồng bộ.
   - Xác định mỗi method đang gọi service nào (`ProductService`, `TransactionService`, v.v.) và các yêu cầu cache đặc thù.

2. **Đối chiếu service tương ứng trên web**
   - Kiểm tra hàm đã được port trong `web/lib/api` hoặc `web/lib/cache`.
   - Nếu provider cũ sử dụng cache (ví dụ `CachedProductService`), map sang helper cache tương đương (`cachedProductService`, `memoryCache`) hoặc dựng helper mới cùng chức năng.

3. **Tạo hook React thay thế**
   - Tạo file `web/hooks/use-<feature>.ts`.
   - Dùng `useState`/`useReducer` để lưu state giống provider cũ.
   - Triển khai `useEffect` để load dữ liệu ban đầu, gọi đúng service web.
   - Wrap các mutation trong `useCallback`, đảm bảo xử lý loading/error giống Flutter.
   - Khi mutation làm thay đổi dữ liệu cache, nhớ gọi `invalidate` tương ứng rồi refetch.

4. **Bọc context khi cần chia sẻ state**
   - Nếu nhiều component cùng tiêu thụ state (ví dụ giỏ hàng POS), tạo `FeatureProvider` trong `web/providers`.
   - Bọc hook đã viết vào context, expose thông qua `useFeatureContext`.

5. **Kết nối UI Next.js**
   - Client component import hook/context mới, render dựa trên `data/loading/error` như Flutter build widget.
   - Server component chỉ fetch dữ liệu tĩnh (nếu cần SEO); mọi interaction vẫn nằm ở client thông qua hook.

6. **Kiểm tra và dọn dẹp**
   - Đảm bảo hook mới cover đủ state/action đã ghi ban đầu.
   - Viết quick smoke test hoặc manual checklist (load, mutate, refresh) trước khi xóa provider Dart khỏi luồng web.

