```mermaid
---
title: AgriPOS - Sơ đồ Use Case toàn hệ thống
---
use-case "Người dùng" as User

package "Quản lý Tài khoản & Cửa hàng" {
  User -- (Đăng ký tài khoản)
  User -- (Đăng nhập)
  (Đăng nhập) ..> (Đăng nhập bằng FaceID/Vân tay) : <<extend>>
  (Đăng nhập) ..> (Quên mật khẩu) : <<extend>>
  User -- (Đăng xuất)
  User -- (Đổi cửa hàng)
  
  (Đăng ký tài khoản) ..> (Tạo cửa hàng mới) : <<include>>
  (Đăng nhập) ..> (Chọn cửa hàng làm việc) : <<include>>

  User -- (Quản lý nhân viên)
  (Quản lý nhân viên) ..> (Mời nhân viên mới) : <<include>>
  (Quản lý nhân viên) ..> (Phân quyền nhân viên) : <<include>>
  (Quản lý nhân viên) ..> (Vô hiệu hóa nhân viên) : <<include>>

  User -- (Cấu hình cửa hàng)
  (Cấu hình cửa hàng) ..> (Cấu hình thông tin thuế) : <<include>>
  (Cấu hình cửa hàng) ..> (Cấu hình mẫu hóa đơn) : <<include>>
}

package "Quản lý Sản phẩm & Kho" {
  User -- (Quản lý Sản phẩm)
  (Quản lý Sản phẩm) ..> (Thêm / Sửa / Xóa sản phẩm) : <<include>>
  (Quản lý Sản phẩm) ..> (Tìm kiếm sản phẩm) : <<include>>
  (Thêm / Sửa / Xóa sản phẩm) ..> (Cấu hình Đơn vị tính - UoM) : <<include>>
  (Thêm / Sửa / Xóa sản phẩm) ..> (Cập nhật giá bán) : <<include>>

  User -- (Quản lý Nhà cung cấp)
  (Quản lý Nhà cung cấp) ..> (Thêm / Sửa / Xóa NCC) : <<include>>

  User -- (Quản lý Nhập hàng)
  (Quản lý Nhập hàng) ..> (Tạo đơn nhập hàng - PO) : <<include>>
  (Tạo đơn nhập hàng - PO) ..> (Thêm sản phẩm vào đơn) : <<include>>
  (Quản lý Nhập hàng) ..> (Xác nhận nhận hàng từ PO) : <<include>>
  (Xác nhận nhận hàng từ PO) ..> (Tự động tạo lô hàng) : <<include>>
  (Tự động tạo lô hàng) ..> (Cập nhật tồn kho) : <<include>>
  (Tự động tạo lô hàng) ..> (Cập nhật giá vốn) : <<include>>

  User -- (Kiểm kê kho)
  (Kiểm kê kho) ..> (Xem danh sách lô hàng) : <<include>>
  (Kiểm kê kho) ..> (Điều chỉnh số lượng tồn kho) : <<extend>>
  (Kiểm kê kho) ..> (Hủy lô hàng) : <<extend>>
}

package "Bán hàng (POS)" {
  User -- (Tạo Giao dịch Bán hàng)
  (Tạo Giao dịch Bán hàng) ..> (Thêm sản phẩm vào giỏ) : <<include>>
  (Tạo Giao dịch Bán hàng) ..> (Quét mã vạch sản phẩm) : <<extend>>
  (Tạo Giao dịch Bán hàng) ..> (Chọn khách hàng) : <<include>>
  (Tạo Giao dịch Bán hàng) ..> (Cập nhật tồn kho) : <<include>>
  (Tạo Giao dịch Bán hàng) ..> (Thanh toán) : <<include>>
  (Thanh toán) ..> (Thanh toán tiền mặt) : <<extend>>
  (Thanh toán) ..> (Ghi nợ) : <<extend>>
  (Ghi nợ) ..> (Tạo phiếu công nợ) : <<include>>
  
  User -- (Quản lý Giao dịch)
  (Quản lý Giao dịch) ..> (Tìm kiếm giao dịch cũ) : <<include>>
  (Quản lý Giao dịch) ..> (Xem chi tiết giao dịch) : <<include>>
  (Quản lý Giao dịch) ..> (In lại hóa đơn) : <<extend>>
}

package "Quản lý Khách hàng & Công nợ" {
  User -- (Quản lý Khách hàng)
  (Quản lý Khách hàng) ..> (Thêm / Sửa / Xóa khách hàng) : <<include>>
  (Quản lý Khách hàng) ..> (Xem lịch sử giao dịch) : <<include>>
  (Quản lý Khách hàng) ..> (Xem thống kê khách hàng) : <<include>>

  User -- (Quản lý Công nợ)
  (Quản lý Công nợ) ..> (Xem danh sách công nợ) : <<include>>
  (Quản lý Công nợ) ..> (Ghi nhận thanh toán nợ) : <<include>>
  (Quản lý Công nợ) ..> (Tạo nợ thủ công) : <<extend>>
  (Quản lý Công nợ) ..> (Điều chỉnh công nợ) : <<extend>>
}

package "Báo cáo & Thống kê" {
  User -- (Xem Báo cáo)
  (Xem Báo cáo) ..> (Báo cáo Doanh thu) : <<include>>
  (Xem Báo cáo) ..> (Báo cáo Tồn kho) : <<include>>
  (Xem Báo cáo) ..> (Báo cáo Thuế) : <<include>>
  (Xem Báo cáo) ..> (Báo cáo Công nợ) : <<include>>

  User -- (Xuất file)
  (Xuất file) ..> (Xuất file Excel) : <<include>>
  (Xuất file) ..> (In file PDF) : <<include>>
}
```
