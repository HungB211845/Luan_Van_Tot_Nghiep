-- Create test user for login testing
-- This should be run AFTER creating the user in Supabase Auth

-- First, create the user in Supabase Auth dashboard with:
-- Email: test@example.com
-- Password: 123456
-- Then use the generated user ID below

-- Example user ID (replace with actual ID from Supabase Auth)
-- This is just a placeholder - you need to get the real UUID from auth.users

DO $$
DECLARE
  test_user_id UUID;
  test_store_id UUID;
BEGIN
  -- Get the store ID
  SELECT id INTO test_store_id FROM stores WHERE store_code = 'hungpham';
  
  IF test_store_id IS NULL THEN
    RAISE EXCEPTION 'Store hungpham not found. Run fix_multi_tenant_rls.sql first.';
  END IF;
  
  -- Check if user exists in auth.users (you need to create this manually)
  -- For testing, we'll assume user ID exists: 
  -- This is a placeholder - replace with real user ID from auth.users
  test_user_id := '123e4567-e89b-12d3-a456-426614174000'; -- REPLACE THIS!
  
  -- Insert user profile
  INSERT INTO user_profiles (
    id,
    store_id,
    full_name,
    phone,
    role,
    permissions,
    is_active,
    created_at,
    updated_at
  ) VALUES (
    test_user_id,
    test_store_id,
    'Test User',
    '0123456789',
    'OWNER',
    '{"manage_pos": true, "manage_inventory": true, "manage_users": true}',
    true,
    NOW(),
    NOW()
  ) ON CONFLICT (id) DO UPDATE SET
    store_id = EXCLUDED.store_id,
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role,
    permissions = EXCLUDED.permissions,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();
    
  RAISE NOTICE 'Test user profile created for store: %', test_store_id;
END $$;

-- Verify setup
SELECT 
  up.id,
  up.full_name,
  up.role,
  s.store_code,
  s.store_name
FROM user_profiles up
JOIN stores s ON up.store_id = s.id
WHERE s.store_code = 'hungpham';