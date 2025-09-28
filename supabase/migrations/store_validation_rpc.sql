-- Create RPC function to validate store for login (bypass RLS)

CREATE OR REPLACE FUNCTION validate_store_for_login(store_code_param TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER -- Run with elevated privileges to bypass RLS
AS $$
DECLARE
  store_record RECORD;
  result JSON;
BEGIN
  -- Find active store with the given store_code
  SELECT * INTO store_record 
  FROM stores 
  WHERE store_code = store_code_param 
    AND is_active = true
  LIMIT 1;
  
  -- Return validation result
  IF FOUND THEN
    result := json_build_object(
      'valid', true,
      'store_data', row_to_json(store_record)
    );
  ELSE
    result := json_build_object(
      'valid', false,
      'store_data', null
    );
  END IF;
  
  RETURN result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION validate_store_for_login(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION validate_store_for_login(TEXT) TO anon;