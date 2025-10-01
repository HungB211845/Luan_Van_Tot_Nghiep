-- =====================================================
-- RPC: check_store_code_availability
-- Purpose: Check if a store code is available for signup
-- Security: SECURITY DEFINER to bypass RLS
-- =====================================================

CREATE OR REPLACE FUNCTION check_store_code_availability(p_store_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER -- Bypass RLS to check store code
AS $$
DECLARE
  existing_store_count INTEGER;
  result JSON;
BEGIN
  -- Count stores with this code
  SELECT COUNT(*) INTO existing_store_count
  FROM stores
  WHERE store_code = p_store_code;

  -- Return availability result
  IF existing_store_count = 0 THEN
    result := json_build_object(
      'isAvailable', true,
      'message', 'Mã cửa hàng khả dụng'
    );
  ELSE
    result := json_build_object(
      'isAvailable', false,
      'message', 'Mã này đã được sử dụng'
    );
  END IF;

  RETURN result;
END;
$$;

-- Grant execute permission to anon users (for signup)
GRANT EXECUTE ON FUNCTION check_store_code_availability(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION check_store_code_availability(TEXT) TO authenticated;

-- Add comment
COMMENT ON FUNCTION check_store_code_availability(TEXT) IS 'Check if a store code is available for new store registration. Returns JSON with isAvailable boolean and message string.';
