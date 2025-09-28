-- =============================================================================
-- AGRICULTURAL POS - AUTHENTICATION & MULTI-TENANT SYSTEM MIGRATION
-- =============================================================================
--
-- File: 20240101_auth_multi_tenant_system.sql
-- Purpose: Complete authentication system với multi-tenant architecture
-- Features:
--   - Store-based tenant isolation
--   - Role-based access control (OWNER/MANAGER/CASHIER/INVENTORY_STAFF)
--   - Multi-device session management
--   - Social login support (Google/Facebook/Zalo)
--   - Password reset & OTP system
--   - Audit logging cho security
--   - Row Level Security (RLS) policies
--   - Business compliance (MST, ĐKKD)
--
-- Author: AgriPOS Development Team
-- Date: 2024-01-01
-- Version: 1.0
-- =============================================================================

-- =============================================================================
-- 1. STORES TABLE - THÔNG TIN CỬA HÀNG (TENANT ROOT)
-- =============================================================================

CREATE TABLE stores (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    store_code TEXT UNIQUE NOT NULL, -- abc123 (user-defined, unique identifier)
    store_name TEXT NOT NULL,
    owner_name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    address TEXT,

    -- Business compliance fields (Vietnam specific)
    business_license TEXT, -- Số Đăng Ký Kinh Doanh (ĐKKD)
    tax_code TEXT, -- Mã Số Thuế (MST)

    -- Subscription management
    subscription_type TEXT DEFAULT 'FREE' CHECK (subscription_type IN ('FREE', 'PREMIUM', 'ENTERPRISE')),
    subscription_expires_at TIMESTAMP WITH TIME ZONE,

    -- Status & tracking
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE UNIQUE INDEX idx_stores_store_code ON stores (store_code);
CREATE INDEX idx_stores_active ON stores (is_active);
CREATE INDEX idx_stores_subscription ON stores (subscription_type);

-- =============================================================================
-- 2. USER_PROFILES TABLE - EXTEND SUPABASE AUTH.USERS
-- =============================================================================

-- =============================================================================
-- 2. USER_PROFILES TABLE - EXTEND SUPABASE AUTH.USERS
-- =============================================================================

CREATE TABLE user_profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    avatar_url TEXT,

    -- Role-based access control
    role TEXT NOT NULL CHECK (role IN ('OWNER', 'MANAGER', 'CASHIER', 'INVENTORY_STAFF')) DEFAULT 'CASHIER',
    permissions JSONB DEFAULT '{}', -- Custom permissions for flexible role management

    -- Social login tracking (OAuth integration)
    google_id TEXT,
    facebook_id TEXT,
    zalo_id TEXT,

    -- Status & activity tracking
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_user_profiles_store ON user_profiles (store_id);
CREATE INDEX idx_user_profiles_role ON user_profiles (role);
CREATE INDEX idx_user_profiles_active ON user_profiles (is_active);
CREATE INDEX idx_user_profiles_google ON user_profiles (google_id) WHERE google_id IS NOT NULL;
CREATE INDEX idx_user_profiles_facebook ON user_profiles (facebook_id) WHERE facebook_id IS NOT NULL;
CREATE INDEX idx_user_profiles_zalo ON user_profiles (zalo_id) WHERE zalo_id IS NOT NULL;

-- Unique indexes cho social logins per store
CREATE UNIQUE INDEX idx_user_profiles_google_unique
    ON user_profiles(store_id, google_id)
    WHERE google_id IS NOT NULL;

CREATE UNIQUE INDEX idx_user_profiles_facebook_unique
    ON user_profiles(store_id, facebook_id)
    WHERE facebook_id IS NOT NULL;

CREATE UNIQUE INDEX idx_user_profiles_zalo_unique
    ON user_profiles(store_id, zalo_id)
    WHERE zalo_id IS NOT NULL;

-- Unique constraint-like behavior cho social logins


-- Indexes for performance
-- CREATE INDEX idx_user_profiles_store ON user_profiles (store_id);
--CREATE INDEX idx_user_profiles_role ON user_profiles (role);
--CREATE INDEX idx_user_profiles_active ON user_profiles (is_active);
--CREATE INDEX idx_user_profiles_google ON user_profiles (google_id) WHERE google_id IS NOT NULL;
--CREATE INDEX idx_user_profiles_facebook ON user_profiles (facebook_id) WHERE facebook_id IS NOT NULL;
--CREATE INDEX idx_user_profiles_zalo ON user_profiles (zalo_id) WHERE zalo_id IS NOT NULL; 
--
-- =============================================================================
-- 3. USER_SESSIONS TABLE - MULTI-DEVICE SESSION MANAGEMENT
-- =============================================================================

CREATE TABLE user_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL, -- Unique device identifier
    device_name TEXT, -- "iPhone 13", "Samsung Galaxy S23"
    device_type TEXT CHECK (device_type IN ('MOBILE', 'TABLET', 'DESKTOP')),

    -- Push notifications
    fcm_token TEXT, -- Firebase Cloud Messaging token

    -- Biometric authentication
    is_biometric_enabled BOOLEAN DEFAULT false,

    -- Session tracking
    last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '30 days'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Prevent duplicate sessions per device
    UNIQUE(user_id, device_id)
);

-- Indexes for session management
CREATE INDEX idx_user_sessions_user ON user_sessions (user_id);
CREATE INDEX idx_user_sessions_device ON user_sessions (device_id);
CREATE INDEX idx_user_sessions_expires ON user_sessions (expires_at);
CREATE INDEX idx_user_sessions_active ON user_sessions (last_accessed_at);

-- =============================================================================
-- 4. PASSWORD_RESET_TOKENS TABLE - OTP & PASSWORD RECOVERY
-- =============================================================================

CREATE TABLE password_reset_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email TEXT NOT NULL,
    token TEXT NOT NULL, -- OTP code or reset token
    token_type TEXT CHECK (token_type IN ('PASSWORD_RESET', 'EMAIL_VERIFICATION', 'PHONE_VERIFICATION')) DEFAULT 'PASSWORD_RESET',
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_used BOOLEAN DEFAULT false,
    used_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for token lookup
CREATE INDEX idx_password_reset_email ON password_reset_tokens (email);
CREATE INDEX idx_password_reset_token ON password_reset_tokens (token) WHERE is_used = false;
CREATE INDEX idx_password_reset_expires ON password_reset_tokens (expires_at);

-- =============================================================================
-- 5. AUTH_AUDIT_LOG TABLE - SECURITY & COMPLIANCE LOGGING
-- =============================================================================

CREATE TABLE auth_audit_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    store_id UUID REFERENCES stores(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL, -- 'LOGIN', 'LOGOUT', 'PASSWORD_CHANGE', 'FAILED_LOGIN', 'ACCOUNT_LOCKED'
    ip_address INET,
    user_agent TEXT,
    device_info JSONB,
    metadata JSONB, -- Additional event-specific data
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for audit queries
CREATE INDEX idx_auth_audit_user ON auth_audit_log (user_id);
CREATE INDEX idx_auth_audit_store ON auth_audit_log (store_id);
CREATE INDEX idx_auth_audit_event ON auth_audit_log (event_type);
CREATE INDEX idx_auth_audit_created ON auth_audit_log (created_at DESC);
CREATE INDEX idx_auth_audit_ip ON auth_audit_log (ip_address);

-- =============================================================================
-- 6. ADD STORE_ID TO EXISTING BUSINESS TABLES
-- =============================================================================

-- Add store_id column to existing business tables for multi-tenant isolation
ALTER TABLE products ADD COLUMN store_id UUID REFERENCES stores(id) ON DELETE CASCADE;
ALTER TABLE customers ADD COLUMN store_id UUID REFERENCES stores(id) ON DELETE CASCADE;
ALTER TABLE transactions ADD COLUMN store_id UUID REFERENCES stores(id) ON DELETE CASCADE;
ALTER TABLE transaction_items ADD COLUMN store_id UUID REFERENCES stores(id) ON DELETE CASCADE;
ALTER TABLE purchase_orders ADD COLUMN store_id UUID REFERENCES stores(id) ON DELETE CASCADE;
ALTER TABLE purchase_order_items ADD COLUMN store_id UUID REFERENCES stores(id) ON DELETE CASCADE;
ALTER TABLE companies ADD COLUMN store_id UUID REFERENCES stores(id) ON DELETE CASCADE;
ALTER TABLE product_batches ADD COLUMN store_id UUID REFERENCES stores(id) ON DELETE CASCADE;
ALTER TABLE seasonal_prices ADD COLUMN store_id UUID REFERENCES stores(id) ON DELETE CASCADE;

-- Create performance indexes for store_id lookups
CREATE INDEX idx_products_store ON products(store_id);
CREATE INDEX idx_customers_store ON customers(store_id);
CREATE INDEX idx_transactions_store ON transactions(store_id);
CREATE INDEX idx_transaction_items_store ON transaction_items(store_id);
CREATE INDEX idx_purchase_orders_store ON purchase_orders(store_id);
CREATE INDEX idx_purchase_order_items_store ON purchase_order_items(store_id);
CREATE INDEX idx_companies_store ON companies(store_id);
CREATE INDEX idx_product_batches_store ON product_batches(store_id);
CREATE INDEX idx_seasonal_prices_store ON seasonal_prices(store_id);

-- =============================================================================
-- 7. HELPER FUNCTIONS FOR RLS & BUSINESS LOGIC
-- =============================================================================

-- Function to get current authenticated user's store_id
CREATE OR REPLACE FUNCTION get_user_store_id()
RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT store_id
        FROM user_profiles
        WHERE id = auth.uid()
        AND is_active = true
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if current user is store owner
CREATE OR REPLACE FUNCTION is_store_owner()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        SELECT role = 'OWNER'
        FROM user_profiles
        WHERE id = auth.uid()
        AND is_active = true
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if current user has specific role
CREATE OR REPLACE FUNCTION user_has_role(required_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        SELECT role = required_role
        FROM user_profiles
        WHERE id = auth.uid()
        AND is_active = true
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has management permissions
CREATE OR REPLACE FUNCTION can_manage_users()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        SELECT role IN ('OWNER', 'MANAGER')
        FROM user_profiles
        WHERE id = auth.uid()
        AND is_active = true
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate OTP code
CREATE OR REPLACE FUNCTION generate_otp_code(
    target_email TEXT,
    token_type_param TEXT DEFAULT 'PASSWORD_RESET'
)
RETURNS TEXT AS $$
DECLARE
    otp_code TEXT;
BEGIN
    -- Generate 6-digit OTP
    otp_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');

    -- Insert OTP record
    INSERT INTO password_reset_tokens (email, token, token_type, expires_at)
    VALUES (
        target_email,
        otp_code,
        token_type_param,
        NOW() + INTERVAL '10 minutes'
    );

    RETURN otp_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify OTP code
CREATE OR REPLACE FUNCTION verify_otp_code(
    target_email TEXT,
    input_token TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    is_valid BOOLEAN := false;
BEGIN
    UPDATE password_reset_tokens
    SET is_used = true, used_at = NOW()
    WHERE email = target_email
    AND token = input_token
    AND expires_at > NOW()
    AND is_used = false
    RETURNING true INTO is_valid;

    RETURN COALESCE(is_valid, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log authentication events
CREATE OR REPLACE FUNCTION log_auth_event(
    event_type_param TEXT,
    metadata_param JSONB DEFAULT '{}'
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO auth_audit_log (user_id, store_id, event_type, metadata)
    VALUES (
        auth.uid(),
        get_user_store_id(),
        event_type_param,
        metadata_param
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM user_sessions
    WHERE expires_at < NOW();

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE password_reset_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth_audit_log ENABLE ROW LEVEL SECURITY;

-- Enable RLS on existing business tables
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE seasonal_prices ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 9. RLS POLICIES FOR AUTH TABLES
-- =============================================================================

-- STORES table policies
CREATE POLICY "Users can view their own store" ON stores
    FOR SELECT USING (id = get_user_store_id());

CREATE POLICY "Store owners can update store info" ON stores
    FOR UPDATE USING (
        id = get_user_store_id()
        AND is_store_owner() = true
    );

-- USER_PROFILES table policies
CREATE POLICY "Users can view profiles in same store" ON user_profiles
    FOR SELECT USING (store_id = get_user_store_id());

CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE USING (id = auth.uid());

CREATE POLICY "Managers can manage users in same store" ON user_profiles
    FOR ALL USING (
        store_id = get_user_store_id()
        AND can_manage_users() = true
    );

CREATE POLICY "Allow user profile creation during registration" ON user_profiles
    FOR INSERT WITH CHECK (true); -- Will be restricted by application logic

-- USER_SESSIONS table policies
CREATE POLICY "Users can view own sessions" ON user_sessions
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can manage own sessions" ON user_sessions
    FOR ALL USING (user_id = auth.uid());

-- PASSWORD_RESET_TOKENS table policies (public access for password reset)
CREATE POLICY "Allow password reset token operations" ON password_reset_tokens
    FOR ALL USING (true); -- Controlled by application logic and token expiry

-- AUTH_AUDIT_LOG table policies
CREATE POLICY "Users can view own audit logs" ON auth_audit_log
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Store owners can view store audit logs" ON auth_audit_log
    FOR SELECT USING (
        store_id = get_user_store_id()
        AND is_store_owner() = true
    );

-- =============================================================================
-- 10. RLS POLICIES FOR BUSINESS TABLES (MULTI-TENANT ISOLATION)
-- =============================================================================

-- Generic multi-tenant isolation policy for all business tables
CREATE POLICY "Multi-tenant isolation" ON products
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "Multi-tenant isolation" ON customers
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "Multi-tenant isolation" ON transactions
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "Multi-tenant isolation" ON transaction_items
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "Multi-tenant isolation" ON purchase_orders
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "Multi-tenant isolation" ON purchase_order_items
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "Multi-tenant isolation" ON companies
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "Multi-tenant isolation" ON product_batches
    FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "Multi-tenant isolation" ON seasonal_prices
    FOR ALL USING (store_id = get_user_store_id());

-- =============================================================================
-- 11. TRIGGERS FOR AUTOMATION
-- =============================================================================

-- Trigger function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update triggers to tables with updated_at column
CREATE TRIGGER update_stores_updated_at
    BEFORE UPDATE ON stores
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger to automatically log authentication events
CREATE OR REPLACE FUNCTION auto_log_auth_events()
RETURNS TRIGGER AS $$
BEGIN
    -- Log user profile changes
    IF TG_TABLE_NAME = 'user_profiles' THEN
        IF TG_OP = 'INSERT' THEN
            PERFORM log_auth_event('USER_CREATED',
                jsonb_build_object('user_id', NEW.id, 'role', NEW.role));
        ELSIF TG_OP = 'UPDATE' AND OLD.is_active != NEW.is_active THEN
            PERFORM log_auth_event(
                CASE WHEN NEW.is_active THEN 'USER_ACTIVATED' ELSE 'USER_DEACTIVATED' END,
                jsonb_build_object('user_id', NEW.id)
            );
        END IF;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_auto_log_user_events
    AFTER INSERT OR UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION auto_log_auth_events();

-- =============================================================================
-- 12. INITIAL DATA SETUP
-- =============================================================================

-- Insert default store for existing data migration
INSERT INTO stores (store_code, store_name, owner_name, is_active)
VALUES ('DEFAULT001', 'Cửa hàng mặc định', 'Administrator', true)
ON CONFLICT (store_code) DO NOTHING;

-- Update existing business tables with default store_id
DO $$
DECLARE
    default_store_id UUID;
BEGIN
    -- Get default store ID
    SELECT id INTO default_store_id
    FROM stores
    WHERE store_code = 'DEFAULT001';

    -- Update existing records if they don't have store_id
    IF default_store_id IS NOT NULL THEN
        UPDATE products SET store_id = default_store_id WHERE store_id IS NULL;
        UPDATE customers SET store_id = default_store_id WHERE store_id IS NULL;
        UPDATE transactions SET store_id = default_store_id WHERE store_id IS NULL;
        UPDATE transaction_items SET store_id = default_store_id WHERE store_id IS NULL;
        UPDATE purchase_orders SET store_id = default_store_id WHERE store_id IS NULL;
        UPDATE purchase_order_items SET store_id = default_store_id WHERE store_id IS NULL;
        UPDATE companies SET store_id = default_store_id WHERE store_id IS NULL;
        UPDATE product_batches SET store_id = default_store_id WHERE store_id IS NULL;
        UPDATE seasonal_prices SET store_id = default_store_id WHERE store_id IS NULL;
    END IF;
END $$;

-- Trigger function để update search_vector cho products
CREATE OR REPLACE FUNCTION update_product_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('simple', COALESCE(NEW.name, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.sku, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.description, '')), 'B') ||
        setweight(to_tsvector('simple', COALESCE(NEW.attributes::text, '')), 'C');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Make store_id NOT NULL after data migration
ALTER TABLE products ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE customers ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE transactions ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE transaction_items ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE purchase_orders ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE purchase_order_items ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE companies ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE product_batches ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE seasonal_prices ALTER COLUMN store_id SET NOT NULL;

-- =============================================================================
-- 13. PERMISSIONS FOR APPLICATION ROLE
-- =============================================================================

-- Grant necessary permissions to authenticated role for API access
GRANT SELECT, INSERT, UPDATE, DELETE ON stores TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON password_reset_tokens TO authenticated;
GRANT SELECT, INSERT ON auth_audit_log TO authenticated;

-- Grant execute permissions for functions
GRANT EXECUTE ON FUNCTION get_user_store_id() TO authenticated;
GRANT EXECUTE ON FUNCTION is_store_owner() TO authenticated;
GRANT EXECUTE ON FUNCTION user_has_role(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION can_manage_users() TO authenticated;
GRANT EXECUTE ON FUNCTION generate_otp_code(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_otp_code(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION log_auth_event(TEXT, JSONB) TO authenticated;

-- =============================================================================
-- MIGRATION COMPLETED SUCCESSFULLY
-- =============================================================================

-- Insert migration log
INSERT INTO auth_audit_log (event_type, metadata)
VALUES ('SYSTEM_MIGRATION', jsonb_build_object(
    'migration', '20240101_auth_multi_tenant_system.sql',
    'version', '1.0',
    'completed_at', NOW()
));

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Migration completed successfully: Authentication & Multi-tenant System v1.0';
    RAISE NOTICE 'Tables created: stores, user_profiles, user_sessions, password_reset_tokens, auth_audit_log';
    RAISE NOTICE 'RLS policies enabled for multi-tenant data isolation';
    RAISE NOTICE 'Helper functions created for authentication and authorization';
    RAISE NOTICE 'Existing business tables updated with store_id for multi-tenancy';
END $$;



-- Check tables created

SELECT table_name FROM information_schema.tables

WHERE table_schema = 'public' AND table_name IN
('stores', 'user_profiles', 'user_sessions', 'password_reset_tokens',

'auth_audit_log');

  

-- Check RLS enabled
 SELECT tablename, rowsecurity FROM pg_tables

WHERE schemaname = 'public' AND rowsecurity = true;

  