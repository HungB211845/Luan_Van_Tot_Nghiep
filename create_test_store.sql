-- Create test store for login testing
INSERT INTO stores (
  store_code,
  store_name,
  owner_name,
  phone,
  email,
  address,
  is_active
) VALUES (
  'hungpham',
  'Cửa hàng Nông Nghiệp Hưng Phẩm',
  'Hưng Phẩm',
  '0123456789',
  'hungpham@gmail.com',
  'Hồ Chí Minh',
  true
);

-- Get the store_id for user profile creation
DO $$
DECLARE
    store_uuid UUID;
    user_uuid UUID;
BEGIN
    -- Get the store ID
    SELECT id INTO store_uuid FROM stores WHERE store_code = 'hungpham';

    -- Create a test user in auth.users (simulate the user from login screen)
    -- Note: In real app, this user would be created via signup
    INSERT INTO auth.users (
        id,
        email,
        encrypted_password,
        email_confirmed_at,
        created_at,
        updated_at,
        confirmation_token,
        raw_app_meta_data,
        raw_user_meta_data
    ) VALUES (
        gen_random_uuid(),
        'hungpham@gmail.com',
        crypt('123456', gen_salt('bf')),
        NOW(),
        NOW(),
        NOW(),
        '',
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        ('{"store_id": "' || store_uuid || '"}')::jsonb
    ) ON CONFLICT (email) DO NOTHING
    RETURNING id INTO user_uuid;

    -- If user already exists, get their ID
    IF user_uuid IS NULL THEN
        SELECT id INTO user_uuid FROM auth.users WHERE email = 'hungpham@gmail.com';
    END IF;

    -- Create user profile
    INSERT INTO user_profiles (
        id,
        store_id,
        email,
        full_name,
        phone,
        role,
        is_active
    ) VALUES (
        user_uuid,
        store_uuid,
        'hungpham@gmail.com',
        'Hưng Phẩm',
        '0123456789',
        'OWNER',
        true
    ) ON CONFLICT (id) DO UPDATE SET
        store_id = EXCLUDED.store_id,
        is_active = true;

    RAISE NOTICE 'Test store and user created successfully!';
    RAISE NOTICE 'Store Code: hungpham';
    RAISE NOTICE 'Email: hungpham@gmail.com';
    RAISE NOTICE 'Password: 123456';
END $$;