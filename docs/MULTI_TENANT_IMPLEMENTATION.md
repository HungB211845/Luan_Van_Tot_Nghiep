# Multi-Tenant Implementation Guide

## Overview
AgriPOS now implements a complete multi-tenant architecture with store-based isolation. Each store operates independently with its own data, users, and access controls.

## Architecture

### Store Isolation Model
```
Store A (UUID-A):
├── Owner (1 người)
├── Staff (n người) - MANAGER/CASHIER/INVENTORY_STAFF
├── Products (chỉ thuộc Store A)
├── Customers (chỉ thuộc Store A)
├── Suppliers (chỉ thuộc Store A)
└── Transactions (chỉ thuộc Store A)

Store B (UUID-B):
├── Owner (1 người khác)
├── Staff (n người khác)
└── Data hoàn toàn tách biệt
```

## Database Schema

### Core Tables
- `stores` - Store information
- `user_profiles` - User profiles with store_id and roles
- `store_invitations` - Staff invitation system

### Business Tables with store_id
All business tables include `store_id` for isolation:
- `products`, `companies`, `customers`
- `transactions`, `transaction_items`
- `purchase_orders`, `purchase_order_items`
- `product_batches`, `seasonal_prices`

### RLS Policies
Row Level Security enforces data isolation using `get_current_user_store_id()` function:

```sql
-- Example policy for products table
CREATE POLICY products_select_own
ON public.products FOR SELECT
TO authenticated
USING (store_id = get_current_user_store_id());
```

## Authentication Flow

### 1. User Signup/Login
```dart
// AuthService automatically sets store_id in JWT claims
final result = await authService.signUpWithEmail(
  email: email,
  password: password,
  storeCode: storeCode,
  storeName: storeName,
  fullName: fullName,
);
```

### 2. JWT Claims Integration
```dart
// store_id is set in app_metadata for RLS policies
await _supabase.auth.admin.updateUserById(
  userId,
  attributes: AdminUserAttributes(
    appMetadata: {'store_id': storeId},
  ),
);
```

### 3. BaseService Auto-Filtering
```dart
// All business services extend BaseService
class ProductService extends BaseService {
  Future<List<Product>> getProducts() async {
    // addStoreFilter automatically adds store_id filter
    final response = await addStoreFilter(_supabase
        .from('products')
        .select('*'));
    // Returns only products for current user's store
  }
}
```

## Store Management

### Owner Functions
- Create new store during signup
- Invite staff members via email
- Assign roles: MANAGER, CASHIER, INVENTORY_STAFF
- Manage staff permissions
- Remove staff from store

### Staff Invitation Workflow
1. Owner sends invitation via email
2. Invitation stored in `store_invitations` table with expiry
3. New user signs up and invitation auto-assigns to store
4. Existing user gets store access immediately

### Permission System
```dart
// Role-based permissions
enum UserRole { OWNER, MANAGER, CASHIER, INVENTORY_STAFF }

// Permission checking
if (await storeService.hasPermission('manage_products')) {
  // User can manage products
}

// Granular permissions in user_profiles.permissions JSON
{
  "manage_products": true,
  "view_reports": false,
  "process_refunds": true
}
```

## Code Integration

### 1. BaseService Usage
```dart
abstract class BaseService {
  String? get currentStoreId; // Reads from JWT claims
  PostgrestFilterBuilder<T> addStoreFilter<T>(query); // Auto-adds store_id
  Map<String, dynamic> addStoreId(data); // Auto-adds store_id to inserts
}
```

### 2. Model Constructors
All models now require `storeId`:
```dart
final product = Product(
  name: 'Phân bón NPK',
  category: ProductCategory.FERTILIZER,
  storeId: BaseService.getDefaultStoreId(), // Auto-populated
);
```

### 3. Auth State Sync
```dart
// main.dart automatically syncs auth state with BaseService
void _setupAuthStateListener() {
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final user = data.session?.user;
    if (user != null) {
      String? storeId = user.appMetadata?['store_id'] as String?;
      BaseService.setCurrentUserStoreId(storeId);
    }
  });
}
```

## Migration Guide

### Running Migrations
1. `supabase/migrations/20240101_auth_multi_tenant_system.sql` - Core auth schema
2. `supabase/migrations/2025-09-27_rls_policies_all.sql` - RLS policies + helper function
3. `supabase/migrations/2025-09-27_store_invitations.sql` - Staff invitation system

### Database Functions
```sql
-- Helper function for RLS policies
CREATE OR REPLACE FUNCTION get_current_user_store_id()
RETURNS uuid AS $$
  SELECT (auth.jwt() -> 'app_metadata' ->> 'store_id')::uuid;
$$ LANGUAGE sql SECURITY DEFINER;
```

## Testing Multi-Tenant Isolation

### 1. Create Multiple Stores
```dart
// Store A
final storeA = await authService.signUpWithEmail(
  email: 'owner-a@example.com',
  storeCode: 'STORE-A',
  storeName: 'Cửa hàng A',
);

// Store B
final storeB = await authService.signUpWithEmail(
  email: 'owner-b@example.com',
  storeCode: 'STORE-B',
  storeName: 'Cửa hàng B',
);
```

### 2. Verify Data Isolation
- Login as Store A owner → only see Store A data
- Login as Store B owner → only see Store B data
- Staff members only see their assigned store's data

### 3. Test Staff Permissions
```dart
// Invite staff to Store A
await storeService.inviteStaffToStore(
  storeId: storeA.id,
  email: 'staff@example.com',
  role: UserRole.CASHIER,
  permissions: {'process_sales': true, 'manage_inventory': false},
);
```

## Security Features

### 1. Row Level Security (RLS)
- All tables have RLS enabled
- Policies enforce store_id filtering
- No way to access other stores' data

### 2. JWT Claims Validation
- store_id stored in app_metadata
- Verified by Supabase on every request
- Cannot be tampered with by client

### 3. Permission Enforcement
- Role-based access control
- Granular permissions per user
- Owner can manage all store functions
- Staff limited by assigned permissions

## Backwards Compatibility

During migration period, the system supports both modes:
- **Real Auth Mode**: Uses JWT claims from authenticated users
- **Migration Mode**: Falls back to default store ID

```dart
String getValidStoreId() {
  final storeId = currentStoreId; // From JWT claims
  if (storeId != null) return storeId;

  return getDefaultStoreId(); // Fallback for migration
}
```

## Best Practices

### 1. Always Use BaseService
```dart
// Good ✅
class ProductService extends BaseService {
  Future<List<Product>> getProducts() async {
    return addStoreFilter(_supabase.from('products').select('*'));
  }
}

// Bad ❌ - No store filtering
_supabase.from('products').select('*')
```

### 2. Handle Auth State Changes
```dart
// Listen to auth changes and update UI accordingly
Supabase.instance.client.auth.onAuthStateChange.listen((data) {
  if (data.session == null) {
    // User logged out - navigate to login
    Navigator.pushReplacementNamed(context, '/login');
  }
});
```

### 3. Validate Permissions
```dart
// Check permissions before sensitive operations
if (await storeService.hasPermission('delete_products')) {
  await productService.deleteProduct(productId);
} else {
  throw Exception('Insufficient permissions');
}
```

## Troubleshooting

### Common Issues

1. **RLS Policy Blocks Access**
   - Ensure user has store_id in JWT claims
   - Check `get_current_user_store_id()` returns valid UUID

2. **Data Not Isolated**
   - Verify RLS is enabled on table
   - Check policy uses correct store_id filtering

3. **Permission Denied**
   - Confirm user role has required permissions
   - Check user_profiles.is_active = true

### Debug Commands
```sql
-- Check current user's store_id
SELECT get_current_user_store_id();

-- View user JWT claims
SELECT auth.jwt();

-- Check user profile
SELECT * FROM user_profiles WHERE id = auth.uid();
```