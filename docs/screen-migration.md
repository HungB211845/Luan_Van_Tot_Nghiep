# Pipeline Chuyển Screen Flutter → Next.js

## 1. Chuẩn bị route & component
- Định nghĩa route App Router tương ứng: `app/(features)/<feature>/page.tsx` (server component) + các segment con `[id]/page.tsx` nếu cần master-detail.
- Tạo layout wrapper (`app/(features)/layout.tsx`) cho phần sidebar/navbar dùng chung.

## 2. Tách server/client
- Server component: fetch dữ liệu tĩnh (SEO) bằng service mới (`await reportService.get...`).
- Client component: thêm `use client` và dùng hook/context để quản lý state, tương tác.

## 3. Dựng layout responsive
- Thay ResponsiveScaffold bằng CSS Grid/Flex: master-detail => `grid-cols-[320px_1fr]` ở breakpoint `lg` trở lên.
- Sử dụng 8px grid cho spacing, đảm bảo action hierarchy (primary button nổi bật).

## 4. Map state từ Provider sang hook/context
- Thay Provider Flutter bằng hook tương ứng (`useProducts`, `useTransactions`, `useReportCenter`, v.v.).
- Nếu cần state chia sẻ toàn trang, bọc bằng context provider (`ProductContextProvider`, `CartContextProvider`).

## 5. Chuyển widget sang component React
- Mỗi widget Flutter => component JSX trong `web/app/(features)/.../_components`.
- Dịch layout, style (Tailwind hoặc CSS module), event binding (onClick, onChange).
- Reuse helper ở `web/lib/utils` cho format/ngày/tiền tệ.

## 6. Form & validation
- TextField → `<input>` hoặc UI lib (Shadcn/Radix).
- Gộp input theo nhóm (Email + Password), áp dụng grouped card theo Apple HIG.
- Validation: dùng `react-hook-form` hoặc custom `useState`.

## 7. Navigation
- `Navigator.pushNamed` → `useRouter().push` hoặc `<Link>`.
- Deep link detail => dynamic routes `[id]/page.tsx`.

## 8. Kiểm thử
- Chạy `npm run lint`, `npm run dev`.
- Smoke test flow: load, filter, paginate, mutate, export.
- Đảm bảo Supabase token/headers hoạt động và cache invalidation đúng.

---

# Checklist Screen Migration

## Products
- [ ] Product Catalog (master-detail)
- [ ] Product Detail / Seasonal Pricing
- [ ] Product Batches / Inventory
- [ ] Product Dashboard
- [ ] Batch History (`lib/features/products/screens/products/batch_history_screen.dart`)
- [ ] Batch Detail (`lib/features/products/screens/products/batch_detail_screen.dart`)
- [ ] Add/Edit Product Wizard (Step1/Step2/Step3)
- [ ] Add/Edit Batch (manual, from PO, edit)
- [ ] Seasonal Price CRUD (`add_seasonal_price_screen.dart`, `edit_seasonal_price_screen.dart`)
- [ ] Inventory History (`lib/features/products/screens/products/inventory_history_screen.dart`)

## POS
- [ ] POS Cart / Checkout
- [ ] Transaction History (master-detail)
- [ ] Debt Management
- [ ] Transaction Detail (`lib/features/pos/screens/transaction/transaction_detail_screen.dart`)
- [ ] Transaction Success (`lib/features/pos/screens/transaction/transaction_success_screen.dart`)

## Reports
- [ ] Revenue Overview
- [ ] Inventory Analytics
- [ ] Tax Summary & Export
- [ ] Top Value Products (`lib/features/reports/screens/top_value_products_screen.dart`)
- [ ] Fast Turnover Products (`lib/features/reports/screens/fast_turnover_products_screen.dart`)
- [ ] Slow Turnover Products (`lib/features/reports/screens/slow_turnover_products_screen.dart`)

## Customers
- [ ] Customer List / Detail
- [ ] Customer Debt History
- [ ] Add/Edit Customer (`add_customer_screen.dart`, `edit_customer_screen.dart`)
- [ ] Customer Transaction History (`customer_transaction_history_screen.dart`)

## Auth & Settings
- [ ] Splash Screen (`lib/presentation/splash/splash_screen.dart`)
- [ ] Store Code Entry (`lib/features/auth/screens/store_code_screen.dart`)
- [ ] Login Screen (`lib/features/auth/screens/login_screen.dart`)
- [ ] Signup Flow Step 1 (`lib/features/auth/screens/signup_step1_screen.dart`)
- [ ] Signup Flow Step 2 (`lib/features/auth/screens/signup_step2_screen.dart`)
- [ ] Signup Flow Step 3 (`lib/features/auth/screens/signup_step3_screen.dart`)
- [ ] OTP Verification (`lib/features/auth/screens/otp_verification_screen.dart`)
- [ ] Onboarding (`lib/features/auth/screens/onboarding_screen.dart`)
- [ ] Store Setup (`lib/features/auth/screens/store_setup_screen.dart`)
- [ ] Forgot Password (`lib/features/auth/screens/forgot_password_screen.dart`)
- [ ] Change Password (`lib/features/auth/screens/change_password_screen.dart`)
- [ ] Biometric Login (`lib/features/auth/screens/biometric_login_screen.dart`)
- [ ] Biometric Setup (`lib/features/auth/screens/biometric_setup_screen.dart`)
- [ ] Profile (`lib/features/auth/screens/profile/profile_screen.dart`)
- [ ] Edit Profile (`lib/features/auth/screens/edit_profile_screen.dart`)
- [ ] Store Selection
- [ ] Employee Management
- [ ] Permission Management
- [ ] Invoice Settings (`lib/features/auth/screens/invoice_settings_screen.dart`)
- [ ] Employee List (`lib/features/auth/screens/employee_list_screen.dart`)
- [ ] Edit Store Info (`lib/features/auth/screens/edit_store_info_screen.dart`)

## Home
- [ ] Dashboard Widgets
- [ ] Quick Access Shortcuts
- [ ] Global Search (`lib/presentation/home/screens/global_search_screen.dart`)
- [ ] Edit Quick Access (`lib/presentation/home/screens/edit_quick_access_screen.dart`)

## Company Management
- [ ] Company List (`lib/features/products/screens/company/company_list_screen.dart`)
- [ ] Company Detail (`lib/features/products/screens/company/company_detail_screen.dart`)
- [ ] Add/Edit Company (`lib/features/products/screens/company/add_edit_company_screen.dart`)
- [ ] Company Picker (`lib/features/products/screens/company/company_picker_screen.dart`)
- [ ] Company Transaction History (`lib/features/products/screens/company/company_transaction_history_screen.dart`)
- [ ] Bulk Product Add (`lib/features/products/screens/company/bulk_product_add_screen.dart`)

## Debt
- [ ] Debt List (`lib/features/debt/screens/debt_list_screen.dart`)
- [ ] Customer Debt Detail (`lib/features/debt/screens/customer_debt_detail_screen.dart`)
- [ ] Add Payment (`lib/features/debt/screens/add_payment_screen.dart`)
- [ ] Adjust Debt (`lib/features/debt/screens/adjust_debt_screen.dart`)
