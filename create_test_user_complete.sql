-- Create test user and link to store
-- This should be run to create a complete test setup

DO $$
DECLARE
    test_user_id UUID;
    test_store_id UUID;
    created_user_id UUID;
BEGIN
    -- Get the store ID for hungpham
    SELECT id INTO test_store_id FROM stores WHERE store_code = 'hungpham';

    IF test_store_id IS NULL THEN
        RAISE EXCEPTION 'Store hungpham not found. Make sure stores table is populated.';
    END IF;

    RAISE NOTICE 'Found store ID: %', test_store_id;

    -- Create user in auth.users manually
    -- In a real scenario, this would be done via Supabase Auth signup
    -- For testing, we'll create a mock user
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
        raw_app_meta_data,
        raw_user_meta_data
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(),
        'authenticated',
        'authenticated',
        'test@example.com',
        crypt('123456', gen_salt('bf')), -- Hash the password
        NOW(),
        NOW(),
        NOW(),
        encode(gen_random_bytes(32), 'hex'),
        '{"provider":"email","providers":["email"]}',
        '{}'
    )
    ON CONFLICT (email) DO UPDATE SET
        encrypted_password = EXCLUDED.encrypted_password,
        updated_at = NOW()
    RETURNING id INTO created_user_id;

    RAISE NOTICE 'Created/Updated user with ID: %', created_user_id;

    -- Create user profile linking to the store
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
        created_user_id,
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

    RAISE NOTICE 'Created user profile for store: %', test_store_id;
    RAISE NOTICE 'Test credentials: Store Code: hungpham, Email: test@example.com, Password: 123456';
END $$;

-- Verify the setup
SELECT
    u.email,
    up.full_name,
    up.role,
    s.store_code,
    s.store_name,
    up.is_active
FROM auth.users u
JOIN user_profiles up ON u.id = up.id
JOIN stores s ON up.store_id = s.id
WHERE u.email = 'test@example.com';