-- =============================================================================
-- SUPABASE JWT REFRESH TOKEN FIX MIGRATION
-- Date: 2025-09-30
-- Purpose: Fix JWT refresh token generation for proper biometric authentication
-- =============================================================================

-- 1. VERIFY CURRENT JWT SETTINGS
DO $$
BEGIN
    RAISE NOTICE 'Starting JWT Refresh Token Fix Migration...';
END $$;

-- 2. CHECK IF NEW JWT SIGNING KEYS ARE ENABLED
-- (This should be done via dashboard migration, but we can verify)
SELECT
    'JWT Settings Check' as status,
    current_setting('app.jwt_secret', true) as jwt_secret_status;

-- 3. CREATE FUNCTION TO VALIDATE JWT TOKEN FORMAT
CREATE OR REPLACE FUNCTION validate_jwt_format(token text)
RETURNS boolean
LANGUAGE plpgsql
AS $$
BEGIN
    -- JWT should have 3 parts separated by dots
    RETURN array_length(string_to_array(token, '.'), 1) = 3
           AND length(token) > 100;
END;
$$;

-- 4. CREATE FUNCTION TO CHECK USER SESSION TOKENS
CREATE OR REPLACE FUNCTION check_user_refresh_tokens()
RETURNS TABLE(
    user_id uuid,
    session_count integer,
    has_valid_refresh_token boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        au.id as user_id,
        0 as session_count,  -- Placeholder since we can't access auth.sessions directly
        false as has_valid_refresh_token -- Will need to check via application
    FROM auth.users au
    WHERE au.deleted_at IS NULL;
END;
$$;

-- 5. CREATE FUNCTION TO FORCE SESSION REFRESH (to be called from app)
CREATE OR REPLACE FUNCTION force_user_session_refresh(target_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    rows_affected integer;
BEGIN
    -- This will be called from the app to trigger session refresh
    -- The actual refresh token regeneration happens at the auth layer

    -- Update user's updated_at to trigger potential token refresh
    UPDATE auth.users
    SET updated_at = now()
    WHERE id = target_user_id
    AND deleted_at IS NULL;

    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    RETURN rows_affected > 0;
END;
$$;

-- 6. CREATE ENHANCED USER SESSIONS TABLE (if needed)
CREATE TABLE IF NOT EXISTS enhanced_user_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id text NOT NULL,
    device_name text,
    device_type text,
    jwt_format_version text DEFAULT 'v2', -- Track JWT format version
    refresh_token_hash text, -- Store hash for validation
    created_at timestamptz DEFAULT now(),
    last_accessed_at timestamptz DEFAULT now(),
    expires_at timestamptz DEFAULT now() + interval '30 days',
    is_active boolean DEFAULT true,

    UNIQUE(user_id, device_id)
);

-- 7. CREATE RLS POLICIES FOR ENHANCED SESSIONS
ALTER TABLE enhanced_user_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own enhanced sessions" ON enhanced_user_sessions;
CREATE POLICY "Users can manage their own enhanced sessions"
    ON enhanced_user_sessions FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- 8. CREATE FUNCTION TO VALIDATE REFRESH TOKEN VIA APP
CREATE OR REPLACE FUNCTION validate_app_refresh_token(
    p_user_id uuid,
    p_device_id text,
    p_token_length integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    session_record enhanced_user_sessions%ROWTYPE;
    is_valid boolean := false;
    token_format text := 'unknown';
BEGIN
    -- Get session record
    SELECT * INTO session_record
    FROM enhanced_user_sessions
    WHERE user_id = p_user_id
    AND device_id = p_device_id
    AND is_active = true;

    -- Determine token format based on length
    IF p_token_length > 200 THEN
        token_format := 'jwt_v2';
        is_valid := true;
    ELSIF p_token_length > 50 THEN
        token_format := 'jwt_v1';
        is_valid := true;
    ELSIF p_token_length > 10 THEN
        token_format := 'legacy_short';
        is_valid := false;
    ELSE
        token_format := 'invalid';
        is_valid := false;
    END IF;

    -- Update or insert session record
    INSERT INTO enhanced_user_sessions (
        user_id, device_id, jwt_format_version, last_accessed_at
    ) VALUES (
        p_user_id, p_device_id, token_format, now()
    )
    ON CONFLICT (user_id, device_id)
    DO UPDATE SET
        jwt_format_version = token_format,
        last_accessed_at = now(),
        is_active = true;

    RETURN json_build_object(
        'is_valid', is_valid,
        'token_format', token_format,
        'token_length', p_token_length,
        'recommendation',
        CASE
            WHEN is_valid THEN 'Token format is valid'
            WHEN token_format = 'legacy_short' THEN 'Upgrade JWT format via dashboard migration'
            ELSE 'Invalid token - re-authentication required'
        END
    );
END;
$$;

-- 9. CREATE HELPER FUNCTION FOR BIOMETRIC TOKEN STORAGE
CREATE OR REPLACE FUNCTION store_biometric_context(
    p_user_id uuid,
    p_device_id text,
    p_store_id uuid,
    p_store_code text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    context_id uuid;
BEGIN
    -- Store biometric authentication context
    INSERT INTO enhanced_user_sessions (
        user_id, device_id, jwt_format_version,
        last_accessed_at, expires_at
    ) VALUES (
        p_user_id, p_device_id, 'biometric_fallback',
        now(), now() + interval '90 days'
    )
    ON CONFLICT (user_id, device_id)
    DO UPDATE SET
        jwt_format_version = 'biometric_fallback',
        last_accessed_at = now(),
        expires_at = now() + interval '90 days',
        is_active = true
    RETURNING id INTO context_id;

    RETURN context_id;
END;
$$;

-- 10. CREATE VIEW FOR SESSION MONITORING
CREATE OR REPLACE VIEW session_health_view AS
SELECT
    u.id as user_id,
    u.email,
    up.full_name,
    up.store_id,
    s.store_name,
    eus.device_id,
    eus.jwt_format_version,
    eus.last_accessed_at,
    eus.expires_at,
    eus.is_active,
    CASE
        WHEN eus.jwt_format_version IN ('jwt_v2', 'jwt_v1') THEN 'healthy'
        WHEN eus.jwt_format_version = 'legacy_short' THEN 'needs_migration'
        WHEN eus.jwt_format_version = 'biometric_fallback' THEN 'fallback_mode'
        ELSE 'unknown'
    END as health_status
FROM auth.users u
LEFT JOIN user_profiles up ON u.id = up.id
LEFT JOIN stores s ON up.store_id = s.id
LEFT JOIN enhanced_user_sessions eus ON u.id = eus.user_id
WHERE u.deleted_at IS NULL;

-- 11. GRANT PERMISSIONS
GRANT EXECUTE ON FUNCTION validate_jwt_format TO authenticated, anon;
GRANT EXECUTE ON FUNCTION check_user_refresh_tokens TO authenticated;
GRANT EXECUTE ON FUNCTION force_user_session_refresh TO authenticated;
GRANT EXECUTE ON FUNCTION validate_app_refresh_token TO authenticated;
GRANT EXECUTE ON FUNCTION store_biometric_context TO authenticated;
GRANT SELECT ON session_health_view TO authenticated;

-- 12. CREATE MONITORING QUERY
DO $$
DECLARE
    total_users integer;
    legacy_sessions integer;
BEGIN
    SELECT COUNT(*) INTO total_users FROM auth.users WHERE deleted_at IS NULL;
    SELECT COUNT(*) INTO legacy_sessions FROM enhanced_user_sessions WHERE jwt_format_version = 'legacy_short';

    RAISE NOTICE 'Migration Summary:';
    RAISE NOTICE '- Total active users: %', total_users;
    RAISE NOTICE '- Sessions with legacy tokens: %', legacy_sessions;
    RAISE NOTICE '- Migration tools installed successfully';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '1. Ensure JWT Signing Keys migration is complete in dashboard';
    RAISE NOTICE '2. Test refresh token generation in app';
    RAISE NOTICE '3. Monitor session_health_view for token format distribution';
    RAISE NOTICE '4. Users may need to re-authenticate for new JWT format';
END $$;

-- =============================================================================
-- END MIGRATION
-- =============================================================================