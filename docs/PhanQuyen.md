# Hệ thống phân quyền và quản lý nhân viên

## 0. Trạng thái hiện tại (State of the Codebase)

### ✅ Có sẵn trong codebase

**Database Schema (verified từ migrations và user input):**

```sql
-- Bảng employee_invitations (đầy đủ)
CREATE TABLE employee_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  invited_by_user_id UUID NOT NULL REFERENCES auth.users(id),
  role TEXT NOT NULL CHECK (role IN ('OWNER','MANAGER','CASHIER','INVENTORY_STAFF')),
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','ACCEPTED','EXPIRED','CANCELLED')),
  invitation_token TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(store_id, email)
);

-- Bảng user_profiles (từ essential_auth_schema)
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'CASHIER' CHECK (role IN ('OWNER','MANAGER','CASHIER','INVENTORY_STAFF')),
  permissions JSONB DEFAULT '{}',
  google_id TEXT,
  facebook_id TEXT,
  zalo_id TEXT,
  is_active BOOLEAN DEFAULT true,
  biometric_enabled BOOLEAN DEFAULT false,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
  -- ⚠️ THIẾU: email TEXT (cần thêm để query dễ dàng)
);

-- Bảng user_sessions (có sẵn)
CREATE TABLE user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  device_name TEXT,
  device_type TEXT CHECK (device_type IN ('MOBILE','TABLET','DESKTOP')),
  fcm_token TEXT,
  is_biometric_enabled BOOLEAN DEFAULT false,
  last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days'),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, device_id)
);

-- Bảng password_reset_tokens (có sẵn)
CREATE TABLE password_reset_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  token TEXT NOT NULL,
  token_type TEXT DEFAULT 'PASSWORD_RESET' CHECK (token_type IN ('PASSWORD_RESET','EMAIL_VERIFICATION','PHONE_VERIFICATION')),
  expires_at TIMESTAMPTZ NOT NULL,
  is_used BOOLEAN DEFAULT false,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Flutter Code đã có:**

1. **EmployeeService** (`lib/features/auth/services/employee_service.dart`):
   - `inviteEmployee()` - gửi invitation với token
   - `acceptInvitation()` - nhân viên accept invite và tạo tài khoản qua supabase.auth.signUp()
   - `getStoreEmployees()` - list nhân viên
   - `getPendingInvitations()` - list lời mời chờ
   - `updateEmployeeRole()` - đổi role
   - `deactivateEmployee()` - vô hiệu hóa (soft delete)
   - `cancelInvitation()`, `resendInvitation()` - quản lý invitation

2. **AuthService** (`lib/features/auth/services/auth_service.dart`):
   - `signInWithEmailAndStore()` - đăng nhập với email + password + storeCode
   - `signUpWithEmail()` - đăng ký owner mới (tạo store + user_profile)
   - `enableBiometricWithPassword()` - bật Face ID
   - `assignUserToStore()` - gán user vào store (dùng cho staff invitation)

3. **BaseService** (`lib/shared/services/base_service.dart`):
   - `currentStoreId` getter - lấy từ JWT metadata (`user.appMetadata['store_id']` hoặc `user.userMetadata['store_id']`)
   - `requirePermission()` - placeholder (hiện chưa enforce)
   - `addStoreFilter()` - tự động thêm filter store_id vào query

4. **Permission class** (`lib/features/auth/models/permission.dart`):
   ```dart
   static Map<UserRole, List<String>> defaultPermissions = {
     UserRole.owner: [managePOS, manageInventory, manageCustomers, managePurchaseOrders, viewReports, manageUsers, manageStoreSettings, exportData],
     UserRole.manager: [managePOS, manageInventory, manageCustomers, managePurchaseOrders, viewReports, manageUsers],
     UserRole.cashier: [managePOS, manageCustomers],
     UserRole.inventoryStaff: [manageInventory, managePurchaseOrders, viewReports],
   };
   ```

5. **Models**:
   - `EmployeeInvitation` - đầy đủ với fromJson/toJson
   - `UserProfile` - đầy đủ với role enum, permissions map

6. **UI Screens** (placeholder):
   - `employee_list_screen.dart` - chưa có logic
   - `employee_management_screen.dart` - chưa có logic
   - `EmployeeProvider` - chỉ có skeleton

### ❌ Thiếu và cần làm

**1. Database - Helper Functions & Schema:**
- ⚠️ **THIẾU**: Cột `email TEXT` trong `user_profiles` (cần thêm để query không phụ thuộc vào auth.users)
- ⚠️ **THIẾU**: RPC function `get_user_store_id()` - helper lấy store_id của user hiện tại
- ⚠️ **THIẾU**: RPC function `user_has_role(role TEXT)` - check role của user
- ⚠️ **THIẾU**: RPC function `create_employee_account()` - tạo tài khoản thủ công
- ⚠️ **THIẾU**: RPC function `reset_employee_password()` - reset password
- ⚠️ **THIẾU**: RPC function `toggle_employee_active()` - khóa/mở tài khoản
- ⚠️ **THIẾU**: RPC function `delete_employee_account()` - xóa tài khoản

**2. Flutter Code:**
- ⚠️ **THIẾU**: `EmployeeService.createEmployeeAccount()` - wrap RPC tạo tài khoản thủ công
- ⚠️ **THIẾU**: `EmployeeService.resetEmployeePassword()` - wrap RPC reset password
- ⚠️ **THIẾU**: `EmployeeService.toggleEmployeeActive()` - wrap RPC khóa/mở
- ⚠️ **THIẾU**: `EmployeeService.deleteEmployeeAccount()` - wrap RPC xóa
- ⚠️ **THIẾU**: `EmployeeProvider` implementation - quản lý state danh sách nhân viên
- ⚠️ **THIẾU**: UI screens với form tạo nhân viên, bảng danh sách, action menu

## 1. Mục tiêu của hệ thống tạo tài khoản thủ công

Hiện tại EmployeeService chỉ có luồng **invitation-based** (gửi email → nhân viên accept → tự tạo tài khoản). Nhưng mày muốn thêm luồng **manual creation** (chủ tạo trực tiếp tài khoản + đặt mật khẩu → đưa thông tin cho nhân viên).

**Lợi ích của manual creation:**
- Không cần email service (phù hợp offline hoặc cửa hàng nhỏ)
- OWNER kiểm soát hoàn toàn (tạo, reset password, khóa/mở, xóa)
- Nhân viên không cần "accept" gì cả, chỉ nhận thông tin và đăng nhập
- Phù hợp với mô hình quản lý truyền thống (như giao mật khẩu Windows cho nhân viên văn phòng)

**Flow mới:**
```
OWNER → Nhập (email, mật khẩu, họ tên, vai trò, phone)
      → App gọi RPC create_employee_account()
      → Supabase tạo auth.users + user_profiles (status ACCEPTED ngay)
      → OWNER nhận thông tin đăng nhập → Đưa cho nhân viên (print/chat)
      → Nhân viên dùng app đăng nhập bằng email+password
      → RLS tự động enforce store_id và role permissions
```

## 2. Thiết kế Database

### 2.1. Schema updates cần thiết

**Thêm cột email vào user_profiles:**
```sql
-- Migration: 20251024_add_email_to_user_profiles.sql
ALTER TABLE user_profiles
ADD COLUMN email TEXT;

-- Sync email từ auth.users sang user_profiles cho existing users
UPDATE user_profiles up
SET email = (SELECT email FROM auth.users WHERE id = up.id)
WHERE email IS NULL;

-- Tạo unique constraint
ALTER TABLE user_profiles
ADD CONSTRAINT user_profiles_store_email_unique UNIQUE (store_id, email);

-- Index để query nhanh
CREATE INDEX idx_user_profiles_email ON user_profiles (email);
```

**Lý do cần email trong user_profiles:**
- RLS policies có thể check trùng email trong cùng store mà không cần join auth.users
- Query nhanh hơn (không phải cross-schema join)
- Khi user bị xóa trong auth.users, vẫn giữ được lịch sử email trong audit logs

### 2.2. Helper Functions

**Function 1: get_user_store_id()**
```sql
-- Lấy store_id của user hiện tại từ JWT metadata hoặc user_profiles
CREATE OR REPLACE FUNCTION get_user_store_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_id UUID;
BEGIN
  -- Lấy từ JWT metadata trước (ưu tiên app_metadata)
  v_store_id := (auth.jwt() -> 'app_metadata' ->> 'store_id')::UUID;

  IF v_store_id IS NULL THEN
    v_store_id := (auth.jwt() -> 'user_metadata' ->> 'store_id')::UUID;
  END IF;

  -- Fallback: query từ user_profiles
  IF v_store_id IS NULL THEN
    SELECT store_id INTO v_store_id
    FROM user_profiles
    WHERE id = auth.uid()
    LIMIT 1;
  END IF;

  RETURN v_store_id;
END;
$$;
```

**Function 2: user_has_role()**
```sql
-- Check xem user hiện tại có role này không
CREATE OR REPLACE FUNCTION user_has_role(check_role TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT role INTO v_role
  FROM user_profiles
  WHERE id = auth.uid();

  RETURN v_role = check_role;
END;
$$;
```

**Function 3: get_default_permissions()**
```sql
-- Trả về default permissions cho một role (map từ Permission.defaultPermissions)
CREATE OR REPLACE FUNCTION get_default_permissions(p_role TEXT)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE p_role
    WHEN 'OWNER' THEN '{"manage_pos":true,"manage_inventory":true,"manage_customers":true,"manage_purchase_orders":true,"view_reports":true,"manage_users":true,"manage_store_settings":true,"export_data":true}'::JSONB
    WHEN 'MANAGER' THEN '{"manage_pos":true,"manage_inventory":true,"manage_customers":true,"manage_purchase_orders":true,"view_reports":true,"manage_users":true}'::JSONB
    WHEN 'CASHIER' THEN '{"manage_pos":true,"manage_customers":true}'::JSONB
    WHEN 'INVENTORY_STAFF' THEN '{"manage_inventory":true,"manage_purchase_orders":true,"view_reports":true}'::JSONB
    ELSE '{}'::JSONB
  END;
END;
$$;
```

### 2.3. RPC Function: create_employee_account()

**Đây là hàm chính để OWNER tạo tài khoản nhân viên thủ công.**

```sql
-- Migration: 20251024_create_employee_account_rpc.sql
CREATE OR REPLACE FUNCTION create_employee_account(
  p_email TEXT,
  p_password TEXT,
  p_full_name TEXT,
  p_role TEXT,
  p_phone TEXT DEFAULT NULL,
  p_permissions JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_store_id UUID;
  v_role TEXT;
  v_permissions JSONB;
  v_user_id UUID;
  v_new_user auth.users%ROWTYPE;
BEGIN
  -- 1. Kiểm tra quyền: chỉ OWNER hoặc MANAGER được phép
  IF NOT (user_has_role('OWNER') OR user_has_role('MANAGER')) THEN
    RAISE EXCEPTION 'Bạn không có quyền tạo tài khoản nhân viên';
  END IF;

  -- 2. Lấy store_id của user hiện tại
  v_store_id := get_user_store_id();
  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'Không xác định được cửa hàng của bạn';
  END IF;

  -- 3. Validate role
  v_role := UPPER(p_role);
  IF v_role NOT IN ('OWNER','MANAGER','CASHIER','INVENTORY_STAFF') THEN
    RAISE EXCEPTION 'Vai trò không hợp lệ: %', p_role;
  END IF;

  -- 4. Check email đã tồn tại trong store này chưa
  IF EXISTS (
    SELECT 1 FROM user_profiles
    WHERE store_id = v_store_id
    AND email = LOWER(p_email)
  ) THEN
    RAISE EXCEPTION 'Email % đã được sử dụng trong cửa hàng này', p_email;
  END IF;

  -- 5. Check email đã tồn tại trong auth.users chưa (global)
  IF EXISTS (
    SELECT 1 FROM auth.users WHERE email = LOWER(p_email)
  ) THEN
    RAISE EXCEPTION 'Email % đã được đăng ký trong hệ thống', p_email;
  END IF;

  -- 6. Tạo user trong auth.users (dùng admin API)
  -- Note: auth.admin_create_user() có thể không tồn tại trong một số Supabase version
  -- Fallback: dùng supabase.auth.admin.createUser() từ Edge Function
  -- Hoặc dùng service_role key từ backend

  -- Temporary workaround: Insert trực tiếp vào auth.users (KHÔNG KHUYẾN KHÍCH)
  -- Production: Dùng Edge Function với service_role key
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    LOWER(p_email),
    crypt(p_password, gen_salt('bf')), -- Mã hóa password
    NOW(), -- Email confirmed ngay
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
  )
  RETURNING * INTO v_new_user;

  v_user_id := v_new_user.id;

  -- 7. Lấy default permissions nếu không truyền vào
  v_permissions := COALESCE(p_permissions, get_default_permissions(v_role));

  -- 8. Tạo user_profiles
  INSERT INTO user_profiles (
    id,
    store_id,
    email,
    full_name,
    phone,
    role,
    permissions,
    is_active
  ) VALUES (
    v_user_id,
    v_store_id,
    LOWER(p_email),
    p_full_name,
    p_phone,
    v_role,
    v_permissions,
    TRUE
  );

  -- 9. Cập nhật user metadata để RLS hoạt động
  UPDATE auth.users
  SET raw_app_meta_data =
    COALESCE(raw_app_meta_data, '{}'::jsonb) ||
    jsonb_build_object('store_id', v_store_id::text)
  WHERE id = v_user_id;

  -- 10. Ghi nhận vào employee_invitations với status ACCEPTED (để tracking lịch sử)
  INSERT INTO employee_invitations (
    store_id,
    email,
    full_name,
    invited_by_user_id,
    role,
    phone,
    status,
    invitation_token,
    expires_at,
    accepted_at
  ) VALUES (
    v_store_id,
    LOWER(p_email),
    p_full_name,
    auth.uid(),
    v_role,
    p_phone,
    'ACCEPTED',
    encode(gen_random_bytes(32), 'hex'), -- Random token (không dùng nhưng cần cho constraint)
    NOW() + INTERVAL '1 day', -- Expires không quan trọng vì đã ACCEPTED
    NOW()
  )
  ON CONFLICT (store_id, email) DO UPDATE
  SET status = 'ACCEPTED',
      updated_at = NOW(),
      accepted_at = NOW(),
      invited_by_user_id = auth.uid();

  -- 11. Trả về thông tin
  RETURN jsonb_build_object(
    'success', TRUE,
    'user_id', v_user_id,
    'email', LOWER(p_email),
    'full_name', p_full_name,
    'role', v_role,
    'message', 'Tài khoản đã được tạo thành công'
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Lỗi tạo tài khoản: %', SQLERRM;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION create_employee_account TO authenticated;
```

**⚠️ LƯU Ý QUAN TRỌNG:**

Hàm trên dùng `INSERT INTO auth.users` trực tiếp là **HACK** và **KHÔNG KHUYẾN KHÍCH** trong production vì:
1. Bỏ qua validation của Supabase Auth
2. Có thể gây conflict với Auth internals
3. Password hashing có thể không khớp với Supabase's expected format

**GIẢI PHÁP PRODUCTION-READY:**

Tạo Edge Function với service_role key:

```typescript
// supabase/functions/create-employee/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { email, password, full_name, role, phone } = await req.json()

  // Authenticate caller
  const authHeader = req.headers.get('Authorization')!
  const token = authHeader.replace('Bearer ', '')

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } }
  )

  // Verify caller has permission
  const { data: profile } = await supabase
    .from('user_profiles')
    .select('role')
    .eq('id', (await supabase.auth.getUser()).data.user?.id)
    .single()

  if (!['OWNER', 'MANAGER'].includes(profile?.role)) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 403 })
  }

  // Create user with service_role
  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  const { data: newUser, error } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name, role }
  })

  if (error) throw error

  // Rest of logic...

  return new Response(JSON.stringify({ success: true, user: newUser }), {
    headers: { "Content-Type": "application/json" },
  })
})
```

Trong Flutter, gọi Edge Function thay vì RPC:
```dart
final response = await supabase.functions.invoke('create-employee', body: {...});
```

### 2.4. RPC Functions quản lý khác

**reset_employee_password():**
```sql
CREATE OR REPLACE FUNCTION reset_employee_password(
  p_user_id UUID,
  p_new_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_target_store_id UUID;
  v_my_store_id UUID;
  v_target_role TEXT;
BEGIN
  -- Check quyền
  IF NOT (user_has_role('OWNER') OR user_has_role('MANAGER')) THEN
    RAISE EXCEPTION 'Không có quyền reset mật khẩu';
  END IF;

  -- Lấy store_id của mình
  v_my_store_id := get_user_store_id();

  -- Lấy thông tin target user
  SELECT store_id, role INTO v_target_store_id, v_target_role
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_target_store_id IS NULL THEN
    RAISE EXCEPTION 'Không tìm thấy nhân viên';
  END IF;

  -- Check cùng store
  IF v_target_store_id != v_my_store_id THEN
    RAISE EXCEPTION 'Không thể reset mật khẩu của nhân viên cửa hàng khác';
  END IF;

  -- Không cho MANAGER reset mật khẩu OWNER
  IF user_has_role('MANAGER') AND v_target_role = 'OWNER' THEN
    RAISE EXCEPTION 'Không thể reset mật khẩu của chủ cửa hàng';
  END IF;

  -- Reset password (dùng admin API hoặc Edge Function)
  -- Temporary hack:
  UPDATE auth.users
  SET encrypted_password = crypt(p_new_password, gen_salt('bf')),
      updated_at = NOW()
  WHERE id = p_user_id;

  -- Mark existing reset tokens as used
  UPDATE password_reset_tokens
  SET is_used = TRUE, used_at = NOW()
  WHERE email = (SELECT email FROM auth.users WHERE id = p_user_id)
  AND is_used = FALSE;

  RETURN jsonb_build_object(
    'success', TRUE,
    'message', 'Mật khẩu đã được reset'
  );
END;
$$;
```

**toggle_employee_active():**
```sql
CREATE OR REPLACE FUNCTION toggle_employee_active(
  p_user_id UUID,
  p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_target_store_id UUID;
  v_my_store_id UUID;
  v_target_role TEXT;
BEGIN
  -- Check quyền
  IF NOT (user_has_role('OWNER') OR user_has_role('MANAGER')) THEN
    RAISE EXCEPTION 'Không có quyền thay đổi trạng thái nhân viên';
  END IF;

  v_my_store_id := get_user_store_id();

  SELECT store_id, role INTO v_target_store_id, v_target_role
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_target_store_id != v_my_store_id THEN
    RAISE EXCEPTION 'Không thể thay đổi trạng thái nhân viên cửa hàng khác';
  END IF;

  IF v_target_role = 'OWNER' THEN
    RAISE EXCEPTION 'Không thể vô hiệu hóa tài khoản chủ cửa hàng';
  END IF;

  -- Update user_profiles
  UPDATE user_profiles
  SET is_active = p_is_active,
      updated_at = NOW()
  WHERE id = p_user_id;

  -- Ban/unban trong auth.users (nếu có admin API)
  UPDATE auth.users
  SET banned_until = CASE
    WHEN p_is_active THEN NULL
    ELSE NOW() + INTERVAL '100 years'
  END
  WHERE id = p_user_id;

  -- Revoke active sessions nếu deactivate
  IF NOT p_is_active THEN
    DELETE FROM user_sessions WHERE user_id = p_user_id;
  END IF;

  RETURN jsonb_build_object(
    'success', TRUE,
    'is_active', p_is_active
  );
END;
$$;
```

**delete_employee_account():**
```sql
CREATE OR REPLACE FUNCTION delete_employee_account(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_target_store_id UUID;
  v_my_store_id UUID;
  v_target_role TEXT;
BEGIN
  -- Check quyền
  IF NOT user_has_role('OWNER') THEN
    RAISE EXCEPTION 'Chỉ chủ cửa hàng mới có quyền xóa tài khoản';
  END IF;

  v_my_store_id := get_user_store_id();

  SELECT store_id, role INTO v_target_store_id, v_target_role
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_target_store_id != v_my_store_id THEN
    RAISE EXCEPTION 'Không thể xóa tài khoản nhân viên cửa hàng khác';
  END IF;

  IF v_target_role = 'OWNER' THEN
    RAISE EXCEPTION 'Không thể xóa tài khoản chủ cửa hàng';
  END IF;

  -- Delete from auth.users (cascade sẽ xóa user_profiles, user_sessions)
  DELETE FROM auth.users WHERE id = p_user_id;

  -- Soft delete trong employee_invitations (giữ lịch sử)
  UPDATE employee_invitations
  SET status = 'CANCELLED',
      updated_at = NOW()
  WHERE email = (SELECT email FROM user_profiles WHERE id = p_user_id);

  RETURN jsonb_build_object(
    'success', TRUE,
    'message', 'Tài khoản đã được xóa'
  );
END;
$$;
```

## 3. Triển khai Flutter

### 3.1. Cập nhật EmployeeService

Thêm các methods mới vào `lib/features/auth/services/employee_service.dart`:

```dart
/// Tạo tài khoản nhân viên thủ công (không qua invitation)
Future<UserProfile> createEmployeeAccount({
  required String email,
  required String password,
  required String fullName,
  required UserRole role,
  String? phone,
  Map<String, bool>? customPermissions,
}) async {
  requirePermission(Permission.manageUsers);

  try {
    final response = await supabase.rpc('create_employee_account', params: {
      'p_email': email,
      'p_password': password,
      'p_full_name': fullName,
      'p_role': role.value,
      'p_phone': phone,
      'p_permissions': customPermissions != null
        ? jsonEncode(customPermissions)
        : null,
    });

    if (response == null || response['success'] != true) {
      throw Exception(response?['message'] ?? 'Không thể tạo tài khoản');
    }

    // Fetch lại user profile vừa tạo
    final userId = response['user_id'] as String;
    final profileData = await supabase
      .from('user_profiles')
      .select('*')
      .eq('id', userId)
      .single();

    return UserProfile.fromJson(profileData);
  } catch (e) {
    throw Exception('Lỗi tạo tài khoản: $e');
  }
}

/// Reset mật khẩu cho nhân viên
Future<void> resetEmployeePassword({
  required String userId,
  required String newPassword,
}) async {
  requirePermission(Permission.manageUsers);

  final response = await supabase.rpc('reset_employee_password', params: {
    'p_user_id': userId,
    'p_new_password': newPassword,
  });

  if (response == null || response['success'] != true) {
    throw Exception(response?['message'] ?? 'Không thể reset mật khẩu');
  }
}

/// Khóa/mở tài khoản nhân viên
Future<void> toggleEmployeeActive({
  required String userId,
  required bool isActive,
}) async {
  requirePermission(Permission.manageUsers);

  final response = await supabase.rpc('toggle_employee_active', params: {
    'p_user_id': userId,
    'p_is_active': isActive,
  });

  if (response == null || response['success'] != true) {
    throw Exception(response?['message'] ?? 'Không thể thay đổi trạng thái');
  }
}

/// Xóa tài khoản nhân viên (hard delete)
Future<void> deleteEmployeeAccount(String userId) async {
  requirePermission(Permission.manageUsers);

  final response = await supabase.rpc('delete_employee_account', params: {
    'p_user_id': userId,
  });

  if (response == null || response['success'] != true) {
    throw Exception(response?['message'] ?? 'Không thể xóa tài khoản');
  }
}
```

### 3.2. Implement EmployeeProvider

Update `lib/features/auth/providers/employee_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import '../services/employee_service.dart';
import '../models/user_profile.dart';
import '../models/employee_invitation.dart';

enum EmployeeStatus { loading, loaded, error }

class EmployeeProvider extends ChangeNotifier {
  final EmployeeService _service = EmployeeService();

  List<UserProfile> _employees = [];
  List<EmployeeInvitation> _pendingInvitations = [];
  EmployeeStatus _status = EmployeeStatus.loading;
  String? _errorMessage;

  List<UserProfile> get employees => _employees;
  List<EmployeeInvitation> get pendingInvitations => _pendingInvitations;
  EmployeeStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == EmployeeStatus.loading;

  /// Load danh sách nhân viên và lời mời
  Future<void> loadEmployees() async {
    _status = EmployeeStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _employees = await _service.getStoreEmployees();
      _pendingInvitations = await _service.getPendingInvitations();
      _status = EmployeeStatus.loaded;
    } catch (e) {
      _status = EmployeeStatus.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  /// Tạo nhân viên mới (manual creation)
  Future<UserProfile> createEmployee({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    final newEmployee = await _service.createEmployeeAccount(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
      phone: phone,
    );

    // Optimistic update
    _employees.insert(0, newEmployee);
    notifyListeners();

    return newEmployee;
  }

  /// Reset mật khẩu
  Future<void> resetPassword(String userId, String newPassword) async {
    await _service.resetEmployeePassword(
      userId: userId,
      newPassword: newPassword,
    );
  }

  /// Khóa/mở tài khoản
  Future<void> toggleActive(String userId, bool isActive) async {
    await _service.toggleEmployeeActive(
      userId: userId,
      isActive: isActive,
    );

    // Update local state
    final index = _employees.indexWhere((e) => e.id == userId);
    if (index != -1) {
      // Note: UserProfile is immutable, cần copyWith
      // Giả sử có copyWith method (cần thêm vào UserProfile class)
      // _employees[index] = _employees[index].copyWith(isActive: isActive);
      await loadEmployees(); // Reload để đơn giản
    }
  }

  /// Xóa nhân viên
  Future<void> deleteEmployee(String userId) async {
    await _service.deleteEmployeeAccount(userId);

    // Remove from local state
    _employees.removeWhere((e) => e.id == userId);
    notifyListeners();
  }
}
```

### 3.3. UI Implementation

**Form tạo nhân viên** (`lib/features/auth/screens/create_employee_screen.dart`):

```dart
class CreateEmployeeScreen extends StatefulWidget {
  @override
  _CreateEmployeeScreenState createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<CreateEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  UserRole _selectedRole = UserRole.cashier;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Thêm nhân viên')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v?.isEmpty ?? true ? 'Nhập email' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Mật khẩu'),
              obscureText: true,
              validator: (v) => (v?.length ?? 0) < 6 ? 'Mật khẩu tối thiểu 6 ký tự' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _fullNameController,
              decoration: InputDecoration(labelText: 'Họ tên'),
              validator: (v) => v?.isEmpty ?? true ? 'Nhập họ tên' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: 'Số điện thoại (không bắt buộc)'),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<UserRole>(
              value: _selectedRole,
              decoration: InputDecoration(labelText: 'Vai trò'),
              items: [
                DropdownMenuItem(value: UserRole.cashier, child: Text('Thu ngân')),
                DropdownMenuItem(value: UserRole.inventoryStaff, child: Text('Nhân viên kho')),
                DropdownMenuItem(value: UserRole.manager, child: Text('Quản lý')),
              ],
              onChanged: (v) => setState(() => _selectedRole = v!),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleCreate,
              child: _isLoading
                ? CircularProgressIndicator()
                : Text('Tạo tài khoản'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<EmployeeProvider>();
      final newEmployee = await provider.createEmployee(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        role: _selectedRole,
        phone: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
      );

      // Show success dialog với thông tin đăng nhập
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Tạo tài khoản thành công'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${newEmployee.email}'),
              Text('Mật khẩu: ${_passwordController.text}'),
              SizedBox(height: 8),
              Text('Vui lòng ghi lại và đưa cho nhân viên',
                style: TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Back to list
              },
              child: Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
```

**Danh sách nhân viên với actions** (`lib/features/auth/screens/employee_list_screen.dart`):

```dart
class EmployeeListScreen extends StatefulWidget {
  @override
  _EmployeeListScreenState createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().loadEmployees();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Quản lý nhân viên')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CreateEmployeeScreen()),
        ),
        child: Icon(Icons.add),
      ),
      body: Consumer<EmployeeProvider>(
        builder: (ctx, provider, _) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (provider.status == EmployeeStatus.error) {
            return Center(child: Text('Lỗi: ${provider.errorMessage}'));
          }

          return ListView.builder(
            itemCount: provider.employees.length,
            itemBuilder: (ctx, i) {
              final employee = provider.employees[i];
              return ListTile(
                leading: CircleAvatar(child: Text(employee.fullName[0])),
                title: Text(employee.fullName),
                subtitle: Text('${employee.role.value} - ${employee.email}'),
                trailing: PopupMenuButton(
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'reset_password',
                      child: Text('Reset mật khẩu'),
                    ),
                    PopupMenuItem(
                      value: 'toggle_active',
                      child: Text(employee.isActive ? 'Vô hiệu hóa' : 'Kích hoạt'),
                    ),
                    if (employee.role != UserRole.owner)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Xóa', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                  onSelected: (value) => _handleAction(value as String, employee),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleAction(String action, UserProfile employee) async {
    final provider = context.read<EmployeeProvider>();

    switch (action) {
      case 'reset_password':
        final newPassword = await _showPasswordDialog();
        if (newPassword != null) {
          await provider.resetPassword(employee.id, newPassword);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Mật khẩu mới: $newPassword')),
          );
        }
        break;

      case 'toggle_active':
        await provider.toggleActive(employee.id, !employee.isActive);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(employee.isActive ? 'Đã vô hiệu hóa' : 'Đã kích hoạt')),
        );
        break;

      case 'delete':
        final confirm = await _showConfirmDialog('Xóa tài khoản ${employee.fullName}?');
        if (confirm == true) {
          await provider.deleteEmployee(employee.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã xóa tài khoản')),
          );
        }
        break;
    }
  }

  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nhập mật khẩu mới'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(hintText: 'Mật khẩu mới'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xác nhận'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Xác nhận', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
```

## 4. Testing & QA

### 4.1. Unit Tests

Test `EmployeeService.createEmployeeAccount()`:

```dart
// test/features/auth/services/employee_service_test.dart
void main() {
  group('EmployeeService.createEmployeeAccount', () {
    test('should create employee with valid data', () async {
      // Mock Supabase client
      // Assert RPC called with correct params
      // Verify UserProfile returned
    });

    test('should throw on duplicate email', () async {
      // Mock RPC error response
      // Assert exception thrown
    });

    test('should throw on invalid role', () async {
      // Test with invalid role
      // Assert validation error
    });
  });
}
```

### 4.2. Integration Tests

**Test scenario:**
1. OWNER đăng nhập
2. Tạo CASHIER với email `test@example.com`
3. Đăng xuất OWNER
4. Đăng nhập bằng tài khoản CASHIER vừa tạo
5. Verify CASHIER chỉ thấy dữ liệu của store_id đúng
6. OWNER reset password CASHIER
7. CASHIER đăng nhập lại với mật khẩu cũ → fail
8. CASHIER đăng nhập với mật khẩu mới → success
9. OWNER vô hiệu hóa CASHIER
10. CASHIER đăng nhập → fail (account banned)

### 4.3. Manual QA Checklist

- [ ] Tạo nhân viên với email trùng trong cùng store → lỗi
- [ ] Tạo nhân viên với email trùng ở store khác → thành công
- [ ] MANAGER tạo nhân viên → thành công
- [ ] CASHIER tạo nhân viên → lỗi permission
- [ ] Reset mật khẩu → đăng nhập cũ fail, mới success
- [ ] Vô hiệu hóa → session hiện tại bị revoke ngay
- [ ] Kích hoạt lại → đăng nhập bình thường
- [ ] Xóa tài khoản → biến mất khỏi danh sách
- [ ] MANAGER reset password OWNER → lỗi
- [ ] MANAGER xóa OWNER → lỗi
- [ ] RLS isolation: nhân viên store A không thấy dữ liệu store B

## 5. Bảo mật & Best Practices

### 5.1. Security Considerations

**Service Role Key Protection:**
- KHÔNG BAO GIỜ embed `SUPABASE_SERVICE_ROLE_KEY` trong Flutter app
- Dùng Edge Functions để wrap admin operations
- Rotate service_role key định kỳ (3-6 tháng)

**Password Policy:**
- Enforce minimum 8 characters
- Khuyến nghị: chữ hoa, chữ thường, số, ký tự đặc biệt
- Buộc đổi mật khẩu lần đầu đăng nhập (thêm flag `must_change_password` trong user_profiles)

**Audit Logging:**
- Log mọi thao tác admin (tạo, reset, khóa, xóa) vào bảng `audit_logs`
- Lưu: action, actor_id, target_user_id, timestamp, ip_address

**Rate Limiting:**
- Giới hạn số lần tạo tài khoản: 10 accounts/hour/store
- Giới hạn reset password: 5 times/hour/user

### 5.2. Production Deployment Checklist

- [ ] Viết migration files cho tất cả schema changes
- [ ] Deploy Edge Functions cho admin operations
- [ ] Setup monitoring cho RPC function performance
- [ ] Enable audit logging
- [ ] Configure rate limiting
- [ ] Write documentation cho OWNER
- [ ] Prepare training materials
- [ ] Setup alerting cho suspicious activities

## 6. Timeline & Milestones

### Phase 1: Database Setup (1 day)
- [ ] Migration: thêm cột email vào user_profiles
- [ ] Migration: tạo helper functions (get_user_store_id, user_has_role, get_default_permissions)
- [ ] Migration: tạo RPC create_employee_account (hoặc Edge Function)
- [ ] Migration: tạo RPC reset_employee_password
- [ ] Migration: tạo RPC toggle_employee_active
- [ ] Migration: tạo RPC delete_employee_account
- [ ] Test SQL functions trên Supabase SQL Editor

### Phase 2: Service Layer (1 day)
- [ ] Implement EmployeeService.createEmployeeAccount()
- [ ] Implement EmployeeService.resetEmployeePassword()
- [ ] Implement EmployeeService.toggleEmployeeActive()
- [ ] Implement EmployeeService.deleteEmployeeAccount()
- [ ] Write unit tests cho service methods

### Phase 3: State Management (0.5 day)
- [ ] Implement EmployeeProvider với full functionality
- [ ] Add loading/error states
- [ ] Implement optimistic updates

### Phase 4: UI Implementation (1 day)
- [ ] CreateEmployeeScreen với validation
- [ ] EmployeeListScreen với action menu
- [ ] Reset password dialog
- [ ] Confirmation dialogs
- [ ] Success/error feedback (SnackBar, AlertDialog)

### Phase 5: Testing & QA (1 day)
- [ ] Run unit tests
- [ ] Run integration tests
- [ ] Manual QA với checklist
- [ ] Security audit
- [ ] Performance testing

### Phase 6: Documentation & Deployment (0.5 day)
- [ ] Write user documentation cho OWNER
- [ ] Write technical documentation
- [ ] Deploy to staging
- [ ] Deploy to production
- [ ] Monitor logs

**Total: 5 days**

## 7. Hướng phát triển sau này

### Short-term (1-2 tháng)
- [ ] Thêm bulk import employees từ CSV/Excel
- [ ] Export danh sách nhân viên ra PDF
- [ ] In thẻ nhân viên với QR code chứa thông tin đăng nhập (encrypted)
- [ ] Email notification khi tài khoản được tạo/reset (optional)

### Long-term (3-6 tháng)
- [ ] Audit log viewer trong app (cho OWNER xem lịch sử thay đổi)
- [ ] Role-based permissions editor (custom permissions per user)
- [ ] 2FA cho OWNER/MANAGER (TOTP hoặc SMS)
- [ ] Session management (xem thiết bị đang đăng nhập, kick session)
- [ ] Scheduled reports (gửi báo cáo hiệu suất nhân viên hàng tuần)

## 8. Tài liệu tham khảo

- Supabase Auth Admin API: https://supabase.com/docs/reference/javascript/auth-admin-createuser
- PostgreSQL Row Level Security: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- Flutter Provider package: https://pub.dev/packages/provider
- AgriPOS CLAUDE.md: `/Users/p/Desktop/LVTN/agricultural_pos/CLAUDE.md`

---

**Lưu ý cuối:** Đây là plan chi tiết dựa trên codebase hiện tại. Trong quá trình implement có thể phát sinh thêm issues (ví dụ: Supabase version không support auth.admin_create_user, cần dùng Edge Function). Hãy linh hoạt điều chỉnh nhưng giữ nguyên kiến trúc tổng thể.
