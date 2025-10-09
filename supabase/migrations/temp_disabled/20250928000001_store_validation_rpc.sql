-- =============================================================================
-- STORE VALIDATION RPC FUNCTION
-- =============================================================================
-- Purpose: Create RPC function to bypass RLS for store validation during login
-- This allows unauthenticated users to validate store codes before authentication
-- =============================================================================

-- Create RPC function to validate store for login
CREATE OR REPLACE FUNCTION validate_store_for_login(store_code_param TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER -- This bypasses RLS policies
AS $$
DECLARE
    store_record RECORD;
    result JSON;
BEGIN
    -- Validate input
    IF store_code_param IS NULL OR trim(store_code_param) = '' THEN
        RETURN json_build_object(
            'valid', false,
            'error', 'Store code is required'
        );
    END IF;

    -- Find store by store_code (case-insensitive)
    SELECT * INTO store_record
    FROM stores
    WHERE LOWER(store_code) = LOWER(trim(store_code_param))
    AND is_active = true;

    -- Check if store exists
    IF NOT FOUND THEN
        RETURN json_build_object(
            'valid', false,
            'error', 'Store not found or inactive'
        );
    END IF;

    -- Return store data for authentication flow
    result := json_build_object(
        'valid', true,
        'store_data', json_build_object(
            'id', store_record.id,
            'store_code', store_record.store_code,
            'store_name', store_record.store_name,
            'owner_name', store_record.owner_name,
            'phone', store_record.phone,
            'email', store_record.email,
            'address', store_record.address,
            'business_license', store_record.business_license,
            'tax_code', store_record.tax_code,
            'subscription_type', store_record.subscription_type,
            'subscription_expires_at', store_record.subscription_expires_at,
            'is_active', store_record.is_active,
            'created_at', store_record.created_at,
            'updated_at', store_record.updated_at
        )
    );

    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return failure
        RAISE LOG 'Error in validate_store_for_login: %', SQLERRM;
        RETURN json_build_object(
            'valid', false,
            'error', 'Internal server error'
        );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION validate_store_for_login(TEXT) TO authenticated;

-- Grant execute permission to anonymous users (for login flow)
GRANT EXECUTE ON FUNCTION validate_store_for_login(TEXT) TO anon;

-- Create comment for documentation
COMMENT ON FUNCTION validate_store_for_login(TEXT) IS
'RPC function to validate store existence and status during login flow. Bypasses RLS to allow unauthenticated store validation.';

-- Test the function
DO $$
DECLARE
    test_result JSON;
BEGIN
    -- Test with existing store
    SELECT validate_store_for_login('hungpham') INTO test_result;
    RAISE NOTICE 'Test result for hungpham: %', test_result;

    -- Test with non-existent store
    SELECT validate_store_for_login('nonexistent') INTO test_result;
    RAISE NOTICE 'Test result for nonexistent: %', test_result;
END $$;