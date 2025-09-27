Tạo Database Schema cho dbdiagram.io
Nhiệm vụ
Phân tích codebase và tạo schema cho dbdiagram.io với format chuẩn, đầy đủ relationships.

Bước thực hiện
1. Thu thập thông tin bảng
Quét models/: Lấy class names, field names, data types, constraints
Quét services/: Xác nhận table names và columns từ SQL queries
Ghi chú: Ưu tiên metadata từ database schema nếu có sẵn
2. Xác định relationships
Tìm foreign keys: Cột có pattern *_id (ví dụ: product_id, user_id, store_id)
Cross-reference: So sánh với tên bảng để xác định mối quan hệ (ví dụ: product_id → products table)
Phân tích code: Tìm .join(), .eq(), .foreignKey() trong services để confirm relationships
Ưu tiên: Foreign key constraints từ database metadata
3. Format output chuẩn
CÚ PHÁP DBDIAGRAM.IO:

Table table_name {
  column_name data_type [constraints]
}
CONSTRAINTS:

[pk]: Primary key
[unique]: Unique constraint
[not null]: Not null constraint
[ref: > table.column]: Foreign key (One-to-Many)
[ref: - table.column]: One-to-One relationship
[ref: < table.column]: Many-to-One relationship
DATA TYPES thường gặp:

uuid, int, text, varchar(n), decimal, boolean, timestamp, jsonb
Output Requirements
QUAN TRỌNG - Tuân thủ format sau:

KHÔNG bao bọc trong "Database" wrapper
Comment dùng "//" thay vì "--"
Inline references trong table definition
Additional explicit Refs ở cuối nếu cần thiết
Một dòng trống giữa các table
Template:

Table users {
  id uuid [pk]
  email text [unique, not null]
  created_at timestamp
}

Table posts {
  id uuid [pk]
  title text [not null]
  user_id uuid [not null, ref: > users.id]
  created_at timestamp
}

// Additional relationships if needed
Ref: posts.user_id > users.id
Yêu cầu đặc biệt
Xác định chính xác relationship direction: Many-to-One (>), One-to-Many (<), One-to-One (-)
Bao gồm tất cả constraints: primary keys, foreign keys, unique, not null
Sử dụng đúng data types: ưu tiên PostgreSQL/Supabase types
Thêm comments cho các trường phức tạp hoặc business logic đặc biệt
Output
Tạo schema hoàn chỉnh theo format dbdiagram.io, có thể paste trực tiếp vào dbdiagram.io và generate ERD diagram thành công.

