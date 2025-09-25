
Cây thư mục ví dụ như bây giờ trong /libs hãy quét qua lại một lần nữa để cập nhật

lib/
  core/
    app/
      app_providers.dart
      app_widget.dart
    config/
      supabase_config.dart
    routing/
      app_router.dart
      route_names.dart
  features/
    customers/
      models/
        customer.dart
      providers/
        customer_provider.dart
      screens/
        customers/
          add_customer_screen.dart
          customer_detail_screen.dart
          customer_list_screen.dart
          customer_list_viewmodel.dart
          edit_customer_screen.dart
      services/
        customer_service.dart
    products/
      models/
        product.dart
        product_batch.dart
        seasonal_price.dart
        banned_substance.dart
        company.dart
        fertilizer_attributes.dart
        pesticide_attributes.dart
        seed_attributes.dart
      providers/
        product_provider.dart
      screens/
        products/
          add_product_screen.dart
          edit_product_screen.dart
          product_detail_screen.dart
          product_list_screen.dart
          add_batch_screen.dart
          edit_batch_screen.dart
          add_seasonal_price_screen.dart
          edit_seasonal_price_screen.dart
          batch_history_screen.dart  # Màn lịch sử Lô hàng tái sử dụng (theo productId)
      services/
        product_service.dart
    pos/
      models/
        transaction.dart
        transaction_item.dart
        transaction_item_details.dart
      providers/
        transaction_provider.dart
      screens/
        cart/
          cart_screen.dart
        pos/
          cart_screen.dart
          pos_screen.dart
        transaction/
          transaction_list_screen.dart
          transaction_success_screen.dart
      services/
        transaction_service.dart
      view_models/
        pos_view_model.dart
  presentation/
    home/
      home/
      home_screen.dart
    splash/
      splash_screen.dart
  shared/
    layout/
      main_layout_wrapper.dart
      components/
        responsive_drawer.dart
      managers/
        app_bar_manager.dart
        bottom_nav_manager.dart
        drawer_manager.dart
        fab_manager.dart
      models/
        layout_config.dart
        navigation_item.dart
    services/
      connectivity_service.dart
      database_service.dart
      supabase_service.dart
    widgets/
      connectivity_banner.dart
      custom_button.dart
      loading_widget.dart
  main.dart

# Giải thích

## core/

- ### app/

app_widget.dart: Entry UI cấp cao. Bọc MaterialApp (theme, locale, routing) và gắn DI qua providers app-wide.

app_providers.dart: Khai báo danh sách ChangeNotifierProvider dùng toàn app.

- ### config/

supabase_config.dart: Khởi tạo Supabase và cung cấp SupabaseClient. Nên chuyển secrets ra env.

- ###  routing/

app_router.dart: Trung tâm định tuyến (onGenerateRoute, initialRoute).

route_names.dart: Hằng số tên route, giúp tránh “magic string”.

 ## **Features**/ (theo domain, tách biệt rõ model/service/state/ui) 
 
 ví dụ như 

### customers/

- models/: Kiểu dữ liệu khách hàng.

- services/: Giao tiếp dữ liệu (Supabase) cho khách hàng.

- providers/: State quản lý danh sách/CRUD khách hàng.

- screens/customers/: UI thao tác khách hàng (list, add, edit, detail) + viewmodel riêng cho màn list.

 ### Products/

- models/: Kiểu dữ liệu sản phẩm, lô, giá mùa vụ, công ty, thuộc tính.

- services/: API sản phẩm (CRUD, batch, pricing, báo cáo).

- providers/: State sản phẩm + giỏ hàng (cart) + tính tổng tiền.

- screens/products/: UI quản trị/chi tiết sản phẩm và các lô/giá.


### pos/

- models/: Giao dịch và item giao dịch (raw + enriched details).

- services/: Tạo giao dịch, lấy chi tiết, thống kê bán hàng.

- providers/: State giao dịch (ngoài cart nằm trong ProductProvider).

- view_models/: POSViewModel điều phối logic màn POS/checkout.

- screens/: POS (bán hàng), giỏ hàng, danh sách/hoàn tất giao dịch.


 ### presentation/


- home/home_screen.dart: Trang chủ ở tầng trình bày (không gắn domain). Dùng MainLayoutWrapper (thường AppLayouts.home), render nội dung tổng quan, nút đi tới features.

- splash/splash_screen.dart: Màn khởi động (logo/init), có thể kiểm tra cấu hình, session, chuyển route tiếp theo.
### /shared/

### /layout 

 **main_layout_wrapper.dart**: “UI shell” bọc mọi screen.

- Chọn layout theo breakpoint: mobile/tablet/desktop.

- Lắp ráp AppBar, Body (padding 16), Drawer/Side panel/Sidebar, BottomNav, FAB.

- Nhận cấu hình từ LayoutConfig để bật/tắt thành phần, tiêu đề, actions, tabs, v.v. 

components/responsive_drawer.dart: Drawer/NavigationRail “thích ứng”.

- < 600px: Drawer (slide-in).

- ≥ breakpoint: NavigationRail (có thể extended), badge count, header/footer tùy chọn.

/managers


- app_bar_manager.dart: Xây AppBar theo AppBarType (simple/search/actions/tabbed). Hỗ trợ tabs, actions, back button, màu.

- bottom_nav_manager.dart: BottomNavigationBar (<=3 items) hoặc thanh mở rộng (>3 items), badge, state controller.

- drawer_manager.dart: Tạo Drawer/Side panel/Sidebar desktop; render item, header/footer mặc định, điều hướng Navigator.pushNamed.

- fab_manager.dart: Tạo FAB theo FABType (standard/extended/mini) và SpeedDial/animated FAB.


/models

- layout_config.dart: Định nghĩa LayoutConfig (layoutType, appBarType, title, nav items, FAB config, drawer flags, tabs, màu sắc). Có các preset AppLayouts.

- navigation_item.dart: Mô tả item điều hướng (icon, label, route, badge, enabled, activeIcon, color), helper render tile.


### /services

- connectivity_service.dart: Kiểm tra trạng thái mạng; có thể phát stream/bật banner.

- database_service.dart: Tiện ích DB dùng chung (transaction helpers, retry, mapping) nếu cần.

- supabase_service.dart: Gateway chung tới SupabaseClient (tránh gọi rải rác), nơi đặt helper query/RPC tái sử dụng.

### /widgets

- connectivity_banner.dart: Banner báo mất kết nối/kết nối lại, cắm vào top của layout.

- custom_button.dart: Nút styled thống nhất (màu, kích thước, icon).

- loading_widget.dart: Loader/skeleton/spinner chuẩn, dùng xuyên app.

### Cách các phần shared phối hợp

- Screen cung cấp LayoutConfig → MainLayoutWrapper gọi managers để dựng AppBar/Drawer/BottomNav/FAB phù hợp breakpoint.

- Điều hướng: navigationItems → DrawerManager/BottomNavManager render → gọi named routes.

- Trạng thái kết nối: connectivity_service + connectivity_banner hiển thị trong layout hoặc body.

### Tóm tắt tương tác

- presentation screen → bọc bởi MainLayoutWrapper(config) → managers dựng AppBar/Drawer/BottomNav/FAB theo LayoutConfig và kích thước màn hình.

- shared/services cung cấp hạ tầng dùng chung (Supabase, connectivity).

- shared/widgets cung cấp UI components tái sử dụng, nhất quán. 
## main.dart

- Khởi chạy: WidgetsFlutterBinding.ensureInitialized(), SupabaseConfig.initialize(), runApp(AppWidget()). Siêu mỏng, đúng chuẩn.



### Quy trình chuẩn để thêm mới/chỉnh sửa một feature

- 1) Làm rõ yêu cầu

- Xác định use cases, luồng UI, quyền truy cập, trạng thái rỗng/lỗi/loading.

- Định nghĩa dữ liệu vào/ra, ràng buộc nghiệp vụ, validation.

- 2) Thiết kế dữ liệu và API

- Supabase:

- Tạo/sửa bảng, view, policy (RLS), RPC nếu cần.

- Cập nhật migration/script và tài liệu lược đồ.

- Model:

- Tạo/sửa model trong features/<domain>/models/.

- Quy ước field, enum, mapping nullable/non-null.

3) Viết Service (data layer)

- Tạo/sửa features/<domain>/services/<domain>_service.dart.

- Chỉ dùng SupabaseConfig.client hoặc shared/services/supabase_service.dart (1 entry duy nhất).

- Chuẩn hóa lỗi (throw Exception/Failure), không để UI logic ở đây.


 4) State management (Provider/ViewModel)

- Nếu theo Provider: thêm/chỉnh features/<domain>/providers/<domain>_provider.dart.

- Nếu màn phức tạp: thêm view_models/ (vẫn ChangeNotifier) để gom orchestration.

- Đảm bảo:

- State rõ ràng: loading/success/error.

- Selector/getters phục vụ UI.

- Không chặn UI quá mức; tách tác vụ nền nếu phù hợp.

 5) UI (Screen + Layout)

- Thêm/chỉnh screen trong features/<domain>/screens/....

- Bọc bằng MainLayout (nếu dùng): core/app/main_layout.dart để đồng nhất Scaffold/AppBar/padding.

- Loading/error/empty states: dùng shared/widgets/loading_widget.dart, snackbar, banner.

 6) Routing

- Khai báo route trong core/routing/route_names.dart.

- Map route trong core/routing/app_router.dart.

- Điều hướng bằng named routes (tránh MaterialPageRoute rải rác).

 7) DI/Providers

- Đăng ký provider mới (nếu app-wide) trong core/app/app_providers.dart.

- Với scope nhỏ, cân nhắc ChangeNotifierProvider.value ngay tại subtree màn hình.

 8) Validation & UX

- Viết validator trong ViewModel hoặc helper.

- Kiểm tra trạng thái rỗng, form invalid, edge cases (network chậm, không có quyền, không có dữ liệu).

9) i18n & Theme

- Text: chuẩn bị sẵn cho đa ngôn ngữ (hiện đang hardcoded vi → định hướng extract string sau).

- Màu/sizing sử dụng theme từ AppWidget khi có thể.

 10) Log/Analytics (nếu cần)

- Log sự kiện chính (tạo/sửa/xóa).

- Log lỗi có ngữ cảnh (service + provider).

 11) Test nhanh & chất lượng

- Thêm unit test tối thiểu cho service mapping/logic.

- Widget test smoke screen (nếu kịp).

- Chạy:

- flutter analyze

- flutter test

- flutter run -d ios (hoặc thiết bị mục tiêu)

 12) Tài liệu & dọn dẹp

- Cập nhật README.md/docs: route mới, model mới, hành vi mới.

- Xóa hoặc di trú code di sản (nếu thay thế).

- Đảm bảo không còn import tương đối sai; ưu tiên package import.

# Khi “chỉnh sửa” một feature hiện có

- Rà lại: model → service → provider/viewmodel → screen → route → DI.

- Kiểm tra ảnh hưởng ngược (backward compatibility) ở service và model.

- Viết migration (Supabase) và test dữ liệu chuyển tiếp.

- Đảm bảo màn hình khác dùng chung provider không bị side-effect.

# Checklist thực thi nhanh (áp dụng cho dự án này)

- Models: features/<domain>/models/.

- Services: features/<domain>/services/ (chỉ dùng một cổng Supabase).

- Providers/ViewModels: features/<domain>/providers/ và view_models/ (đăng ký tại core/app/app_providers.dart nếu global).

- UI Screens: features/<domain>/screens/... (bọc MainLayout).

- Routing: thêm vào core/routing/route_names.dart + app_router.dart.

- Shared: factor widget/dịch vụ dùng chung vào shared/.

- Env/Config: tuyệt đối không hardcode secrets; dùng Dart define/.env khi triển khai.


