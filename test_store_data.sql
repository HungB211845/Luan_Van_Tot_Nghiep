-- Insert test store data for login testing
INSERT INTO stores (
  id,
  store_code, 
  store_name, 
  owner_name,
  email,
  phone,
  subscription_type,
  is_active,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  'hungpham',
  'Cửa hàng test của Hưng Phạm',
  'Hưng Phạm', 
  'test@example.com',
  '0123456789',
  'FREE',
  true,
  NOW(),
  NOW()
) ON CONFLICT (store_code) DO UPDATE SET
  store_name = EXCLUDED.store_name,
  owner_name = EXCLUDED.owner_name,
  email = EXCLUDED.email,
  phone = EXCLUDED.phone,
  updated_at = NOW();

-- Check if store exists
SELECT * FROM stores WHERE store_code = 'hungpham';