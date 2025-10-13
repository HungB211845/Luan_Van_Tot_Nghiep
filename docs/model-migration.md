# Pipeline Chuyển Model Flutter → TypeScript

1. **Đọc model Dart gốc**
   - Vào `lib/.../models/*.dart` và ghi lại danh sách field, kiểu dữ liệu, nullable, enum.
   - Nếu có factory từ Supabase/RPC, ghi chú cách map key JSON.

2. **Tạo type/interface TypeScript tương ứng**
   - Mỗi model tạo type trong `web/types/<feature>.ts` hoặc file mới nếu chưa có.
   - Giữ nguyên tên trường (snake_case nếu API trả về vậy) để tránh phải map lại khi fetch.
   - Với enum Dart, tạo union literal hoặc enum TS tương ứng.

3. **Viết helper chuyển đổi (nếu cần)**
   - Nếu Dart có `fromJson` phức tạp (ví dụ parse nested fields), tạo hàm `normalizeX` trong service/hook để xử lý response → type mới.
   - getter tính toán trong Dart (ví dụ `netProfit`) chuyển thành function hoặc computed getter bên TS.

4. **Cập nhật export chung**
   - Sau khi tạo type, thêm export vào `web/types/index.ts` để toàn bộ app dùng.

5. **Kiểm tra & refactor call-site**
   - Đảm bảo các service/hook sử dụng type mới, bỏ dần phụ thuộc vào Dart models.
   - Viết TS guard nếu API trả về null/optional.

---

# Checklist Model Migration

## Customers
- [ ] `customer.dart`

## Products
- [ ] `product.dart`
- [ ] `seasonal_price.dart`
- [ ] `seed_attributes.dart`
- [ ] `product_backup.dart`
- [ ] `banned_substance.dart`
- [ ] `fertilizer_attributes.dart`
- [ ] `purchase_order_status.dart`
- [ ] `purchase_order.dart`
- [ ] `pesticide_attributes.dart`
- [ ] `product_batch.dart`
- [ ] `purchase_order_item.dart`
- [ ] `product_unit.dart`
- [ ] `company.dart`

## Auth
- [ ] `store_invitation.dart`
- [ ] `user_profile.dart`
- [ ] `permission.dart`
- [ ] `user_session.dart`
- [ ] `store.dart`
- [ ] `store_user.dart`
- [ ] `auth_state.dart`
- [ ] `employee_invitation.dart`

## Debt
- [ ] `debt_payment.dart`
- [ ] `debt_status.dart`
- [ ] `debt.dart`
- [ ] `debt_adjustment.dart`

## POS
- [ ] `payment_method.dart`
- [ ] `transaction_item.dart`
- [ ] `transaction.dart`
- [ ] `transaction_item_details.dart`
- [ ] `pos_view_model.dart`

## Reports
- [ ] `daily_revenue.dart`
- [ ] `quarterly_report.dart`
- [ ] `inventory_product.dart`
- [ ] `revenue_trend_point.dart`
- [ ] `tax_summary.dart`
- [ ] `monthly_report.dart`
- [ ] `top_product.dart`
- [ ] `inventory_analytics.dart`

## Shared/Layout
- [ ] `navigation_item.dart`
- [ ] `layout_config.dart`
- [ ] `paginated_result.dart`
- [ ] `quick_access_item.dart`
