-- Fix RLS policies for multi-tenant login
-- Problem: Current RLS prevents unauthenticated store lookup for login

BEGIN;

-- ==============================================================================
-- FIX STORES TABLE RLS FOR MULTI-TENANT LOGIN
-- ==============================================================================

-- Drop existing restrictive policies
DROP POLICY IF EXISTS stores_select_own ON public.stores;

-- Create new policy: Allow selecting active stores for login validation
-- This allows unauthenticated users to verify store_code during login
CREATE POLICY stores_select_for_login 
ON public.stores 
FOR SELECT 
TO public  -- Allow public access for login validation
USING (is_active = true);

-- Keep insert policy for authenticated users only  
-- (existing stores_insert_authenticated policy remains)

-- Keep update policy for store owners only
-- (existing stores_update_own policy remains)

-- ==============================================================================
-- FIX USER_PROFILES TABLE RLS FOR STORE MEMBERSHIP VERIFICATION
-- ==============================================================================

-- Drop existing restrictive policies
DROP POLICY IF EXISTS user_profiles_select_self ON public.user_profiles;

-- Create new policies for multi-tenant access:

-- Policy 1: Users can select their own profile (existing functionality)
CREATE POLICY user_profiles_select_self 
ON public.user_profiles 
FOR SELECT 
TO authenticated 
USING (id = auth.uid());

-- Policy 2: Allow selecting profiles within same store for store management
CREATE POLICY user_profiles_select_same_store 
ON public.user_profiles 
FOR SELECT 
TO authenticated 
USING (
  store_id IN (
    SELECT store_id 
    FROM user_profiles 
    WHERE id = auth.uid() 
    AND is_active = true
  )
);

-- Keep other policies as-is for security
-- (existing user_profiles_insert_self and user_profiles_update_self remain)

-- ==============================================================================
-- CREATE TEST DATA FOR LOGIN TESTING
-- ==============================================================================

-- Insert test store (bypass RLS with direct admin insert)
INSERT INTO stores (
  id,
  store_code, 
  store_name, 
  owner_name,
  email,
  phone,
  subscription_type,
  is_active,
  created_by,
  created_at,
  updated_at
) VALUES (
  '550e8400-e29b-41d4-a716-446655440001', -- Fixed UUID for consistency
  'hungpham',
  'Cửa hàng test của Hưng Phạm',
  'Hưng Phạm', 
  'test@example.com',
  '0123456789',
  'FREE',
  true,
  '0578be5b-c052-4783-a38f-018e598ebbab', -- Admin user ID
  NOW(),
  NOW()
) ON CONFLICT (store_code) DO UPDATE SET
  store_name = EXCLUDED.store_name,
  owner_name = EXCLUDED.owner_name,
  email = EXCLUDED.email,
  phone = EXCLUDED.phone,
  updated_at = NOW();

COMMIT;

-- Verify the changes
SELECT 'Stores table:' as info;
SELECT store_code, store_name, is_active FROM stores WHERE store_code = 'hungpham';

SELECT 'RLS policies on stores:' as info; 
SELECT schemaname, tablename, policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'stores';