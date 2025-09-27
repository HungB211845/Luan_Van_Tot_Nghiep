# 🧪 Manual Testing Guide - Multi-Tenant System

## Mục tiêu
Kiểm tra hệ thống multi-tenant hoạt động đúng với data isolation hoàn chỉnh.

## 📋 Test Checklist

### 1. 🔐 Authentication & JWT Claims

#### Test 1.1: Login và verify JWT
```bash
# Bước 1: Login với user thật
# Bước 2: Check JWT claims trong browser dev tools
# Bước 3: Verify app_metadata chứa store_id
```

**Expected Result:**
- JWT token chứa `app_metadata.store_id`
- BaseService.currentStoreId trả về đúng store_id
- AuthProvider set store context thành công

#### Test 1.2: Multiple users, different stores
```bash
# Tạo 2 users thuộc 2 stores khác nhau
# Login lần lượt và verify data isolation
```

### 2. 🏗️ RLS Policies Verification

#### Test 2.1: Company Data Isolation
```sql
-- Trong Supabase SQL Editor, test trực tiếp:
SELECT * FROM companies; -- Should only show current user's store
SELECT * FROM products;  -- Should only show current user's store
SELECT * FROM customers; -- Should only show current user's store
```

**Expected Result:**
- Mỗi query chỉ trả về data của store hiện tại
- Không thể thấy data của stores khác

#### Test 2.2: Insert/Update Restrictions
```sql
-- Test insert vào store khác (should fail)
INSERT INTO companies (name, store_id) VALUES ('Test', 'other-store-id');

-- Test update record của store khác (should fail)  
UPDATE companies SET name = 'Hacked' WHERE store_id = 'other-store-id';
```

**Expected Result:**
- Insert/Update vào store khác bị chặn
- Chỉ có thể thao tác với data của store hiện tại

### 3. 🔒 Application Level Tests

#### Test 3.1: Company Management
```dart
// Trong app:
// 1. Tạo company mới
// 2. Verify chỉ hiển thị companies của store hiện tại
// 3. Test duplicate name check (chỉ trong store)
// 4. Test edit/delete chỉ hoạt động với companies của store
```

#### Test 3.2: Product Management
```dart
// 1. Tạo product mới
// 2. Verify product list chỉ hiện của store hiện tại
// 3. Test search chỉ tìm trong store
// 4. Test inventory operations
```

#### Test 3.3: Customer Management
```dart
// 1. Tạo customer mới
// 2. Verify customer list isolation
// 3. Test customer search within store
```

#### Test 3.4: Transaction/POS
```dart
// 1. Tạo transaction
// 2. Verify transaction history chỉ của store
// 3. Test reports chỉ tính data của store
```

### 4. 🛡️ Provider Guards

#### Test 4.1: Store Context Missing
```dart
// Simulate missing store context:
// 1. Clear BaseService.currentUserStoreId
// 2. Try to create company -> should fail with error
// 3. Try to load data -> should fail with error
```

#### Test 4.2: Duplicate Name Validation
```dart
// 1. Tạo company "ABC" trong Store 1
// 2. Tạo company "ABC" trong Store 2 -> should succeed (different stores)
// 3. Tạo company "ABC" lại trong Store 1 -> should fail (same store)
```

### 5. 📊 Database Function Tests

#### Test 5.1: RLS Function
```sql
-- Test function directly
SELECT get_current_user_store_id();
-- Should return current user's store_id
```

#### Test 5.2: RPC Functions
```sql
-- Test các RPC functions có respect store context
SELECT * FROM get_available_stock('product-id');
SELECT * FROM get_expiring_batches_report(1);
```

## 🎯 Success Criteria

### ✅ Authentication
- [ ] JWT chứa store_id trong app_metadata
- [ ] BaseService đọc store_id từ JWT thành công
- [ ] AuthProvider set context đúng

### ✅ Data Isolation
- [ ] Mỗi store chỉ thấy data của mình
- [ ] Không thể access data của stores khác
- [ ] RLS policies hoạt động đúng ở DB level

### ✅ Application Security
- [ ] Provider guards chặn operations khi thiếu store context
- [ ] Duplicate validation chỉ trong phạm vi store
- [ ] All CRUD operations respect store boundaries

### ✅ User Experience
- [ ] App hoạt động bình thường với real auth
- [ ] Performance không bị ảnh hưởng
- [ ] Error messages thân thiện

## 🚨 Common Issues & Solutions

### Issue 1: JWT không chứa store_id
**Solution:** Check AuthService._updateUserMetadata() hoạt động đúng

### Issue 2: RLS policies không hoạt động
**Solution:** Verify function get_current_user_store_id() exists và return đúng

### Issue 3: BaseService không đọc được store_id
**Solution:** Check JWT claims structure và fallback logic

### Issue 4: Provider guards không hoạt động
**Solution:** Verify providers dùng đúng BaseService.currentUserStoreId

## 📝 Test Results Template

```
Date: ___________
Tester: ___________

Authentication Tests:
[ ] JWT Claims ✅/❌
[ ] BaseService Integration ✅/❌
[ ] Multiple Users ✅/❌

RLS Tests:
[ ] Company Isolation ✅/❌  
[ ] Product Isolation ✅/❌
[ ] Customer Isolation ✅/❌
[ ] Insert/Update Restrictions ✅/❌

Application Tests:
[ ] Company Management ✅/❌
[ ] Product Management ✅/❌
[ ] Customer Management ✅/❌
[ ] POS/Transactions ✅/❌

Provider Guards:
[ ] Store Context Missing ✅/❌
[ ] Duplicate Validation ✅/❌

Database Functions:
[ ] get_current_user_store_id() ✅/❌
[ ] RPC Functions ✅/❌

Overall Result: ✅ PASS / ❌ FAIL
Notes: ________________
```

## 🔧 Debug Commands

```sql
-- Check current user context
SELECT auth.uid(), auth.jwt();

-- Check store_id in JWT
SELECT auth.jwt() -> 'app_metadata' ->> 'store_id';

-- Test RLS function
SELECT get_current_user_store_id();

-- Check table policies
SELECT * FROM pg_policies WHERE tablename = 'companies';
```

```dart
// Debug trong app
print('Current User: ${Supabase.instance.client.auth.currentUser?.id}');
print('Store ID from JWT: ${Supabase.instance.client.auth.currentUser?.appMetadata?['store_id']}');
print('BaseService Store ID: ${BaseService.currentUserStoreId}');
```
