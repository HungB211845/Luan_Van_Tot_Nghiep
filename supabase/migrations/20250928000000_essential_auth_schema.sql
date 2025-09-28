-- =============================================================================
-- ESSENTIAL AUTHENTICATION SCHEMA
-- =============================================================================
-- Create minimal required tables for authentication testing

-- =============================================================================
-- 1. STORES TABLE
-- =============================================================================
CREATE TABLE stores (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    store_code TEXT UNIQUE NOT NULL,
    store_name TEXT NOT NULL,
    owner_name TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    business_license TEXT,
    tax_code TEXT,
    subscription_type TEXT DEFAULT 'FREE' CHECK (subscription_type IN ('FREE', 'BASIC', 'PREMIUM')),
    subscription_expires_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- 2. USER PROFILES TABLE
-- =============================================================================
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    role TEXT NOT NULL DEFAULT 'STAFF' CHECK (role IN ('OWNER', 'MANAGER', 'STAFF')),
    permissions JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- 3. USER SESSIONS TABLE
-- =============================================================================
CREATE TABLE user_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_name TEXT,
    device_type TEXT,
    last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, device_id)
);

-- =============================================================================
-- 4. ENABLE RLS
-- =============================================================================
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 5. CREATE INDEXES
-- =============================================================================
CREATE INDEX idx_stores_store_code ON stores (store_code);
CREATE INDEX idx_stores_active ON stores (is_active);
CREATE INDEX idx_user_profiles_store_id ON user_profiles (store_id);
CREATE INDEX idx_user_profiles_active ON user_profiles (is_active);
CREATE INDEX idx_user_sessions_user_id ON user_sessions (user_id);

-- =============================================================================
-- 6. INSERT TEST DATA
-- =============================================================================
INSERT INTO stores (
    store_code,
    store_name,
    owner_name,
    is_active,
    subscription_type
) VALUES (
    'hungpham',
    'Cửa hàng test của Hưng Phạm',
    'Hưng Phạm',
    true,
    'FREE'
) ON CONFLICT (store_code) DO UPDATE SET
    store_name = EXCLUDED.store_name,
    owner_name = EXCLUDED.owner_name,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Verify tables created
DO $$
BEGIN
    RAISE NOTICE 'Essential auth schema created successfully!';
    RAISE NOTICE 'Tables: stores, user_profiles, user_sessions';
END $$;