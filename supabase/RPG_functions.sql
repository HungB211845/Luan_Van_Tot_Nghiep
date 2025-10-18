--- RPG Function


CREATE OR REPLACE FUNCTION auth.email()
RETURNS text
LANGUAGE sql
STABLE
AS $function$
  select
    coalesce(
        nullif(current_setting('request.jwt.claim.email', true), ''),
        (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
    )::text
$function$;

CREATE OR REPLACE FUNCTION auth.jwt()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $function$
  select
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$function$;

CREATE OR REPLACE FUNCTION auth.role()
RETURNS text
LANGUAGE sql
STABLE
AS $function$
  select
    coalesce(
        nullif(current_setting('request.jwt.claim.role', true), ''),
        (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
    )::text
$function$;

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $function$
  select
    coalesce(
        nullif(current_setting('request.jwt.claim.sub', true), ''),
        (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
    )::uuid
$function$;

CREATE OR REPLACE FUNCTION extensions.armor(bytea)
RETURNS text
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_armor';

CREATE OR REPLACE FUNCTION extensions.armor(bytea, text[], text[])
RETURNS text
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_armor';

CREATE OR REPLACE FUNCTION extensions.dearmor(text)
RETURNS bytea
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_dearmor';

CREATE OR REPLACE FUNCTION extensions.decrypt(bytea, bytea, text)
RETURNS bytea
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_decrypt';

CREATE OR REPLACE FUNCTION extensions.decrypt_iv(bytea, bytea, bytea, text)
RETURNS bytea
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_decrypt_iv';

CREATE OR REPLACE FUNCTION extensions.digest(bytea, text)
RETURNS bytea
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_digest';

CREATE OR REPLACE FUNCTION extensions.digest(text, text)
RETURNS bytea
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_digest';

CREATE OR REPLACE FUNCTION extensions.encrypt(bytea, bytea, text)
RETURNS bytea
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_encrypt';

CREATE OR REPLACE FUNCTION extensions.encrypt_iv(bytea, bytea, bytea, text)
RETURNS bytea
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_encrypt_iv';

CREATE OR REPLACE FUNCTION extensions.gen_random_bytes(integer)
RETURNS bytea
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_random_bytes';

CREATE OR REPLACE FUNCTION extensions.gen_salt(text)
RETURNS text
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_gen_salt';

CREATE OR REPLACE FUNCTION extensions.gen_salt(text, integer)
RETURNS text
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_gen_salt_rounds';

CREATE OR REPLACE FUNCTION extensions.hmac(bytea, bytea, text)
RETURNS bytea
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_hmac';

CREATE OR REPLACE FUNCTION extensions.hmac(text, text, text)
RETURNS bytea
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pg_hmac';

CREATE OR REPLACE FUNCTION extensions.pgp_key_id(bytea)
RETURNS text
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_key_id_w';

CREATE OR REPLACE FUNCTION extensions.pgp_pub_decrypt(bytea, bytea)
RETURNS text
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_pub_decrypt_text';

CREATE OR REPLACE FUNCTION extensions.pgp_pub_decrypt(bytea, bytea, text)
RETURNS text
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_pub_decrypt_text';

CREATE OR REPLACE FUNCTION extensions.pgp_pub_decrypt_bytea(bytea, bytea)
RETURNS bytea
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_pub_decrypt_bytea';

CREATE OR REPLACE FUNCTION extensions.pgp_pub_decrypt_bytea(bytea, bytea, text)
RETURNS bytea
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_pub_decrypt_bytea';

CREATE OR REPLACE FUNCTION extensions.pgp_pub_encrypt(text, bytea)
RETURNS bytea
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_pub_encrypt_text';

CREATE OR REPLACE FUNCTION extensions.pgp_pub_encrypt(text, bytea, text)
RETURNS bytea
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_pub_encrypt_text';

CREATE OR REPLACE FUNCTION extensions.pgp_sym_decrypt(bytea, text)
RETURNS text
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_sym_decrypt_text';

CREATE OR REPLACE FUNCTION extensions.pgp_sym_decrypt(bytea, text, text)
RETURNS text
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_sym_decrypt_text';

CREATE OR REPLACE FUNCTION extensions.pgp_sym_decrypt_bytea(bytea, text)
RETURNS bytea
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_sym_decrypt_bytea';

CREATE OR REPLACE FUNCTION extensions.pgp_sym_decrypt_bytea(bytea, text, text)
RETURNS bytea
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_sym_decrypt_bytea';

CREATE OR REPLACE FUNCTION extensions.pgp_sym_encrypt(text, text)
RETURNS bytea
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_sym_encrypt_text';

CREATE OR REPLACE FUNCTION extensions.pgp_sym_encrypt(text, text, text)
RETURNS bytea
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_sym_encrypt_text';

CREATE OR REPLACE FUNCTION extensions.pgp_sym_encrypt_bytea(bytea, text)
RETURNS bytea
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_sym_encrypt_bytea';

CREATE OR REPLACE FUNCTION extensions.pgp_sym_encrypt_bytea(bytea, text, text)
RETURNS bytea
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', 'pgp_sym_encrypt_bytea';

CREATE OR REPLACE FUNCTION extensions.uuid_generate_v1()
RETURNS uuid
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', 'uuid_generate_v1';

CREATE OR REPLACE FUNCTION extensions.uuid_generate_v1mc()
RETURNS uuid
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', 'uuid_generate_v1mc';

CREATE OR REPLACE FUNCTION extensions.uuid_generate_v3(namespace uuid, name text)
RETURNS uuid
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', 'uuid_generate_v3';

CREATE OR REPLACE FUNCTION extensions.uuid_generate_v4()
RETURNS uuid
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', 'uuid_generate_v4';

CREATE OR REPLACE FUNCTION extensions.uuid_generate_v5(namespace uuid, name text)
RETURNS uuid
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', 'uuid_generate_v5';

CREATE OR REPLACE FUNCTION extensions.uuid_nil()
RETURNS uuid
LANGUAGE c
IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', 'uuid_nil';

CREATE OR REPLACE FUNCTION graphql._internal_resolve(query text, variables jsonb DEFAULT '{}'::jsonb, "operationName" text DEFAULT NULL::text, extensions jsonb DEFAULT NULL::jsonb)
RETURNS jsonb
LANGUAGE c
AS '$libdir/pg_graphql', 'resolve_wrapper';

CREATE OR REPLACE FUNCTION graphql.comment_directive(comment_ text)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $function$
    /*
    comment on column public.account.name is '@graphql.name: myField'
    */
    select
        coalesce(
            (
                regexp_match(
                    comment_,
                    '@graphql\((.+)\)'
                )
            )[1]::jsonb,
            jsonb_build_object()
        )
$function$;

CREATE OR REPLACE FUNCTION graphql.increment_schema_version()
RETURNS event_trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
begin
    perform pg_catalog.nextval('graphql.seq_schema_version');
end;
$function$;

CREATE OR REPLACE FUNCTION graphql.resolve(query text, variables jsonb DEFAULT '{}'::jsonb, "operationName" text DEFAULT NULL::text, extensions jsonb DEFAULT NULL::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
declare
    res jsonb;
    message_text text;
begin
    begin
        select graphql._internal_resolve(
            "query" := "query",
            "variables" := "variables",
            "operationName" := "operationName",
            "extensions" := "extensions"
        ) into res;
        return res;
    exception
        when others then
            get stacked diagnostics message_text = message_text;
            return jsonb_build_object(
                'data', null,
                'errors', jsonb_build_array(jsonb_build_object('message', message_text))
            );
    end;
end;
$function$;

CREATE OR REPLACE FUNCTION pgbouncer.get_auth(p_usename text)
RETURNS TABLE(username text, password text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
begin
    raise debug 'PgBouncer auth request: %', p_usename;
    return query
    select
        rolname::text,
        case when rolvaliduntil < now()
            then null
            else rolpassword::text
        end
    from pg_authid
    where rolname=$1 and rolcanlogin;
end;
$function$;

CREATE OR REPLACE FUNCTION public.adjust_debt_amount(p_debt_id uuid, p_adjustment_amount numeric, p_adjustment_type text, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_debt_record RECORD;
    v_user_store_id UUID;
    v_new_remaining DECIMAL(15,2);
    v_adjustment_id UUID;
BEGIN
    -- Validate user belongs to store
    SELECT store_id INTO v_user_store_id
    FROM user_profiles
    WHERE id = auth.uid() AND is_active = true;

    IF v_user_store_id IS NULL THEN
        RAISE EXCEPTION 'User not found or inactive';
    END IF;

    -- Get debt record
    SELECT * INTO v_debt_record
    FROM debts
    WHERE id = p_debt_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Debt not found';
    END IF;

    IF v_debt_record.store_id != v_user_store_id THEN
        RAISE EXCEPTION 'User does not have access to this debt';
    END IF;

    -- Validate adjustment type
    IF p_adjustment_type NOT IN ('increase', 'decrease', 'write_off') THEN
        RAISE EXCEPTION 'Invalid adjustment type';
    END IF;

    -- Calculate new remaining amount
    CASE p_adjustment_type
        WHEN 'increase' THEN
            v_new_remaining := v_debt_record.remaining_amount + ABS(p_adjustment_amount);
        WHEN 'decrease' THEN
            v_new_remaining := v_debt_record.remaining_amount - ABS(p_adjustment_amount);
        WHEN 'write_off' THEN
            v_new_remaining := 0;
    END CASE;

    -- **CRITICAL VALIDATION: Prevent negative debt**
    IF v_new_remaining < 0 THEN
        RAISE EXCEPTION 'Adjustment would result in negative debt. Current: %, Adjustment: %',
            v_debt_record.remaining_amount, p_adjustment_amount;
    END IF;

    -- Create adjustment record
    INSERT INTO debt_adjustments (
        store_id,
        debt_id,
        customer_id,
        adjustment_amount,
        adjustment_type,
        reason,
        previous_amount,
        new_amount,
        created_by
    ) VALUES (
        v_debt_record.store_id,
        p_debt_id,
        v_debt_record.customer_id,
        p_adjustment_amount,
        p_adjustment_type,
        p_reason,
        v_debt_record.remaining_amount,
        v_new_remaining,
        auth.uid()
    )
    RETURNING id INTO v_adjustment_id;

    -- Update debt
    UPDATE debts
    SET
        remaining_amount = v_new_remaining,
        original_amount = CASE
            WHEN p_adjustment_type = 'increase'
            THEN original_amount + ABS(p_adjustment_amount)
            ELSE original_amount
        END,
        status = CASE
            WHEN v_new_remaining = 0 THEN 'paid'
            WHEN v_new_remaining < original_amount THEN 'partial'
            ELSE status
        END,
        updated_at = NOW()
    WHERE id = p_debt_id;

    RETURN jsonb_build_object(
        'success', true,
        'adjustment_id', v_adjustment_id,
        'previous_amount', v_debt_record.remaining_amount,
        'new_amount', v_new_remaining
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.auto_expire_invitations()
RETURNS integer
LANGUAGE plpgsql
AS $function$
    DECLARE
        expired_count INTEGER;
    BEGIN
        UPDATE employee_invitations
        SET status = 'EXPIRED', updated_at = NOW()
        WHERE status = 'PENDING' AND expires_at < NOW();

        GET DIAGNOSTICS expired_count = ROW_COUNT;
        RETURN expired_count;
    END;
$function$;

CREATE OR REPLACE FUNCTION public.auto_log_auth_events()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.calculate_overdue_interest(p_debt_id uuid, p_daily_interest_rate numeric DEFAULT 0.001)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_debt_record RECORD;
    v_days_overdue INTEGER;
    v_interest_amount DECIMAL(15,2);
BEGIN
    -- Get debt record
    SELECT * INTO v_debt_record
    FROM debts
    WHERE id = p_debt_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Debt not found';
    END IF;

    -- Only calculate for overdue debts with due date
    IF v_debt_record.due_date IS NULL OR v_debt_record.due_date >= CURRENT_DATE THEN
        RETURN 0;
    END IF;

    -- Calculate days overdue
    v_days_overdue := CURRENT_DATE - v_debt_record.due_date;

    IF v_days_overdue <= 0 THEN
        RETURN 0;
    END IF;

    -- Calculate interest: remaining_amount * daily_rate * days
    v_interest_amount := v_debt_record.remaining_amount * p_daily_interest_rate * v_days_overdue;

    RETURN ROUND(v_interest_amount, 2);
END;
$function$;

CREATE OR REPLACE FUNCTION public.can_manage_users()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    RETURN (
        SELECT role IN ('OWNER', 'MANAGER')
        FROM user_profiles
        WHERE id = auth.uid()
        AND is_active = true
        LIMIT 1
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_banned_substances(product_id_param uuid)
RETURNS boolean
LANGUAGE plpgsql
AS $function$
DECLARE
    is_banned BOOLEAN := false;
    product_ingredient TEXT;
BEGIN
    -- Get active ingredient from product attributes
    SELECT attributes->>'active_ingredient' INTO product_ingredient
    FROM products
    WHERE id = product_id_param AND category = 'PESTICIDE';
   
    -- Check if ingredient is banned
    IF product_ingredient IS NOT NULL THEN
        SELECT EXISTS(
            SELECT 1 FROM banned_substances
            WHERE LOWER(active_ingredient_name) = LOWER(product_ingredient)
            AND is_active = true
        ) INTO is_banned;
    END IF;
   
    RETURN is_banned;
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_stock_availability(p_product_id uuid, p_quantity numeric, p_unit_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_conversion_factor NUMERIC;
  v_base_quantity NUMERIC;
  v_available_stock NUMERIC;
BEGIN
  -- Lấy hệ số quy đổi
  SELECT conversion_factor INTO v_conversion_factor
  FROM public.product_units
  WHERE id = p_unit_id;

  IF v_conversion_factor IS NULL THEN
    RETURN false;
  END IF;

  -- Tính số lượng cần theo đơn vị cơ sở
  v_base_quantity := p_quantity * v_conversion_factor;

  -- Lấy tồn kho hiện có
  v_available_stock := public.get_available_stock_base_unit(p_product_id);

  RETURN v_available_stock >= v_base_quantity;
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_store_code_availability(p_store_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.check_user_refresh_tokens()
RETURNS TABLE(user_id uuid, session_count integer, has_valid_refresh_token boolean)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        au.id as user_id,
        0 as session_count,  -- Placeholder since we can't access auth.sessions directly
        false as has_valid_refresh_token -- Will need to check via application
    FROM auth.users au
    WHERE au.deleted_at IS NULL;
END;
$function$;

CREATE OR REPLACE FUNCTION public.cleanup_expired_sessions()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM user_sessions
    WHERE expires_at < NOW();

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$function$;

CREATE OR REPLACE FUNCTION public.companies_normalize_name()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.name := regexp_replace(trim(NEW.name), '\s+', ' ', 'g');
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_batches_from_po(po_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  po_record RECORD;
  item_record RECORD;
  batch_count INTEGER := 0;
  new_batch_number TEXT;
  user_store_id UUID;
  total_received_quantity INTEGER := 0;
BEGIN
  -- 1. Get current user's store_id for security
  SELECT store_id INTO user_store_id
  FROM public.user_profiles
  WHERE id = auth.uid();

  IF user_store_id IS NULL THEN
    RAISE EXCEPTION 'User not associated with any store';
  END IF;

  -- 2. Get PO info with lock để tránh race condition
  SELECT po.*, c.name as supplier_name
  INTO po_record
  FROM public.purchase_orders po
  LEFT JOIN public.companies c ON po.supplier_id = c.id
  WHERE po.id = po_id
    AND po.store_id = user_store_id
  FOR UPDATE OF po; -- FIXED: Chỉ định rõ bảng cần khóa

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purchase Order not found or access denied: %', po_id;
  END IF;

  -- 3. Check PO status - Allow both CONFIRMED and DELIVERED
  IF po_record.status NOT IN ('CONFIRMED', 'DELIVERED') THEN
    RAISE EXCEPTION 'PO must be in CONFIRMED or DELIVERED status to receive items. Current status: %',
    po_record.status;
  END IF;

  -- 4. Loop through PO items to create batches and update prices
  FOR item_record IN
    SELECT poi.*
    FROM public.purchase_order_items poi
    WHERE poi.purchase_order_id = po_id
      AND poi.store_id = user_store_id
      AND poi.quantity > poi.received_quantity
    ORDER BY poi.created_at
  LOOP
    -- Create unique batch number with date
    new_batch_number := COALESCE(po_record.po_number, 'PO') || '-' ||
                      (SELECT COALESCE(SUBSTRING(sku FROM 1 FOR 6), 'PROD')
                       FROM public.products WHERE id = item_record.product_id) || '-' ||
                      to_char(CURRENT_DATE, 'YYMMDD');

    -- Create product batch
    INSERT INTO public.product_batches (
      product_id, batch_number, quantity, cost_price,
      received_date, purchase_order_id, supplier_id, store_id,
      notes, is_available, is_deleted
    ) VALUES (
      item_record.product_id,
      new_batch_number,
      item_record.quantity - item_record.received_quantity,
      item_record.unit_cost,
      COALESCE(po_record.delivery_date::date, CURRENT_DATE),
      po_id,
      po_record.supplier_id,
      user_store_id,
      'Auto-created from PO: ' || COALESCE(po_record.po_number, po_id::text),
      true,
      false
    );

    -- CRITICAL: Update product selling price if provided in PO item
    IF item_record.selling_price IS NOT NULL AND item_record.selling_price > 0 THEN
      -- Update the product's current selling price
      UPDATE public.products
      SET current_selling_price = item_record.selling_price,
          updated_at = NOW()
      WHERE id = item_record.product_id
        AND store_id = user_store_id;

      -- Create price history record for audit trail
      INSERT INTO public.price_history (
        product_id, old_price, new_price,
        changed_at, changed_by, reason, store_id
      ) VALUES (
        item_record.product_id,
        (SELECT current_selling_price FROM public.products WHERE id = item_record.product_id),
        item_record.selling_price,
        NOW(),
        auth.uid(),
        'Updated from PO: ' || COALESCE(po_record.po_number, po_id::text),
        user_store_id
      );
    END IF;

    -- Update the received quantity for the PO item
    UPDATE public.purchase_order_items
    SET received_quantity = item_record.quantity
    WHERE id = item_record.id;

    batch_count := batch_count + 1;
  END LOOP;

  -- 5. Update the overall PO status based on received quantities
  SELECT SUM(received_quantity) INTO total_received_quantity
  FROM public.purchase_order_items
  WHERE purchase_order_id = po_id;

  IF total_received_quantity >= (
    SELECT SUM(quantity)
    FROM public.purchase_order_items
    WHERE purchase_order_id = po_id
  ) THEN
    -- All items fully received - mark as DELIVERED
    UPDATE public.purchase_orders
    SET status = 'DELIVERED',
        delivery_date = COALESCE(delivery_date, CURRENT_DATE),
        updated_at = NOW()
    WHERE id = po_id;
  ELSE
    IF po_record.status = 'DELIVERED' THEN
      UPDATE public.purchase_orders
      SET updated_at = NOW()
      WHERE id = po_id;
    END IF;
  END IF;

  RAISE NOTICE 'Successfully created % batches from PO %', batch_count, COALESCE(po_record.po_number, po_id::text);

  RETURN batch_count;

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error processing PO delivery: %', SQLERRM;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_credit_sale(p_store_id uuid, p_customer_id uuid, p_transaction_id uuid, p_amount numeric, p_due_date date DEFAULT NULL::date, p_notes text DEFAULT NULL::text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_debt_id UUID;
    v_user_store_id UUID;
BEGIN
    -- Validate user belongs to store
    SELECT store_id INTO v_user_store_id
    FROM user_profiles
    WHERE id = auth.uid() AND is_active = true;

    IF v_user_store_id IS NULL THEN
        RAISE EXCEPTION 'User not found or inactive';
    END IF;

    IF v_user_store_id != p_store_id THEN
        RAISE EXCEPTION 'User does not have access to this store';
    END IF;

    -- Validate amount
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Debt amount must be greater than zero';
    END IF;

    -- Create debt record
    INSERT INTO debts (
        store_id,
        customer_id,
        transaction_id,
        original_amount,
        paid_amount,
        remaining_amount,
        status,
        due_date,
        notes
    ) VALUES (
        p_store_id,
        p_customer_id,
        p_transaction_id,
        p_amount,
        0,
        p_amount,
        'pending',
        p_due_date,
        p_notes
    )
    RETURNING id INTO v_debt_id;

    RETURN v_debt_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_manual_debt(p_store_id uuid, p_customer_id uuid, p_amount numeric, p_notes text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  new_debt_id uuid;
BEGIN
  -- Validate input
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Debt amount must be greater than zero.';
  END IF;

  -- Insert the new debt record
  INSERT INTO public.debts (
    store_id,
    customer_id,
    original_amount,
    remaining_amount,
    status,
    notes,
    due_date
  )
  VALUES (
    p_store_id,
    p_customer_id,
    p_amount,
    p_amount,
    'pending', -- Corrected status
    'Ghi nợ thủ công: ' || COALESCE(p_notes, ''),
    current_date + interval '30 days' -- Default due date 30 days from now
  )
  RETURNING id INTO new_debt_id;

  -- Return the new debt ID
  RETURN new_debt_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.export_sales_ledger(p_start_date timestamp with time zone, p_end_date timestamp with time zone)
RETURNS TABLE("Số TT" integer, "Ngày bán" text, "Số hóa đơn" text, "Tên khách hàng" text, "Tên sản phẩm" text, "Đơn vị tính" text, "Số lượng" numeric, "Đơn giá" numeric, "Thành tiền" numeric, "Tổng hóa đơn" numeric, "Ghi chú" text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_store_id UUID;
BEGIN
  -- Get current user's store_id from JWT claims or user metadata
  v_store_id := COALESCE(
    (current_setting('request.jwt.claims', true)::json->'app_metadata'->>'store_id')::uuid,
    (current_setting('request.jwt.claims', true)::json->>'store_id')::uuid,
    (current_setting('request.jwt.claims', true)::json->'user_metadata'->>'store_id')::uuid,
    auth.uid()
  );

  -- Validate store_id
  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated and have a valid store_id';
  END IF;

  -- Return detailed sales ledger data with CORRECT column names
  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY t.created_at, ti.id)::INTEGER AS "Số TT",
    TO_CHAR(t.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY') AS "Ngày bán",
    CONCAT('HD-', LPAD(t.id::text, 6, '0')) AS "Số hóa đơn",
    COALESCE(c.name, 'Khách lẻ') AS "Tên khách hàng",
    p.name AS "Tên sản phẩm",
    -- FIXED: Use attributes JSON for unit with category fallbacks
    COALESCE(
      p.attributes->>'unit',
      CASE p.category
        WHEN 'FERTILIZER' THEN 'Bao'
        WHEN 'PESTICIDE' THEN 'Chai'
        WHEN 'SEED' THEN 'Kg'
        ELSE 'Cái'
      END
    ) AS "Đơn vị tính",
    -- FIX: Cast INTEGER to NUMERIC for type compatibility
    ti.quantity::NUMERIC AS "Số lượng",
    -- FIXED: Use price_at_sale (NOT unit_price), ensure NUMERIC
    ti.price_at_sale::NUMERIC AS "Đơn giá",
    -- FIXED: Use sub_total OR calculate, ensure NUMERIC type
    COALESCE(ti.sub_total, (ti.quantity * ti.price_at_sale))::NUMERIC AS "Thành tiền",
    t.total_amount::NUMERIC AS "Tổng hóa đơn",
    COALESCE(t.notes, '') AS "Ghi chú"
  FROM transactions t
  LEFT JOIN customers c ON t.customer_id = c.id
  INNER JOIN transaction_items ti ON t.id = ti.transaction_id
  INNER JOIN products p ON ti.product_id = p.id
  WHERE t.store_id = v_store_id
    AND t.created_at BETWEEN p_start_date AND p_end_date
  ORDER BY t.created_at ASC, ti.id ASC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.force_user_session_refresh(target_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.generate_otp_code(target_email text, token_type_param text DEFAULT 'PASSWORD_RESET'::text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.generate_po_number()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.po_number IS NULL THEN
    NEW.po_number := 'PO' || TO_CHAR(NEW.order_date, 'YYYYMMDD') || '-' ||
                     LPAD(nextval('po_sequence')::TEXT, 3, '0');
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_available_stock(product_uuid uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  total_stock integer := 0;
  current_store_id uuid;
BEGIN
  -- SECURITY: Get current user's store_id
  SELECT store_id INTO current_store_id
  FROM user_profiles
  WHERE id = auth.uid();

  IF current_store_id IS NULL THEN
    RETURN 0; -- No access without store
  END IF;

  -- SECURITY: Only count stock from user's store
  SELECT COALESCE(SUM(pb.quantity), 0) INTO total_stock
  FROM product_batches pb
  JOIN products p ON pb.product_id = p.id
  WHERE pb.product_id = product_uuid
    AND pb.store_id = current_store_id    -- CRITICAL: Filter by store
    AND p.store_id = current_store_id     -- CRITICAL: Verify product belongs to store
    AND pb.is_available = true
    AND pb.quantity > 0
    AND (pb.expiry_date IS NULL OR pb.expiry_date > CURRENT_DATE);

  RETURN total_stock;
END; $function$;

CREATE OR REPLACE FUNCTION public.get_available_stock_base_unit(p_product_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_stock NUMERIC;
BEGIN
  SELECT COALESCE(SUM(pb.quantity), 0) INTO v_stock
  FROM public.product_batches pb
  WHERE pb.product_id = p_product_id
    AND pb.is_available = true
    AND pb.quantity > 0
    AND pb.store_id IN (
      SELECT store_id
      FROM public.user_profiles
      WHERE id = auth.uid()
    );

  RETURN v_stock;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_average_cost_price(p_product_id uuid)
RETURNS numeric
LANGUAGE plpgsql
AS $function$
DECLARE
    avg_cost NUMERIC;
BEGIN
    SELECT COALESCE(
        SUM(pb.cost_price * pb.quantity) / NULLIF(SUM(pb.quantity), 0),
        0
    ) INTO avg_cost
    FROM product_batches pb
    WHERE pb.product_id = p_product_id
      AND pb.is_deleted = false
      AND pb.quantity > 0;

    RETURN COALESCE(avg_cost, 0);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_batches_from_po(po_id uuid)
RETURNS TABLE(id uuid, batch_number text, product_id uuid, product_name text, quantity integer, cost_price numeric, received_date date, created_at timestamp with time zone)
LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    pb.id,
    pb.batch_number,
    pb.product_id,
    p.name as product_name,
    pb.quantity,
    pb.cost_price,
    pb.received_date,
    pb.created_at
  FROM product_batches pb
  LEFT JOIN products p ON pb.product_id = p.id
  WHERE pb.purchase_order_id = po_id
  ORDER BY pb.created_at ASC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_current_price(product_uuid uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  current_price numeric := 0;
  current_store_id uuid;
BEGIN
  -- SECURITY: Get current user's store_id
  SELECT store_id INTO current_store_id
  FROM user_profiles
  WHERE id = auth.uid();

  IF current_store_id IS NULL THEN
    RETURN 0; -- No access without store
  END IF;

  -- FIXED: Get price from products.current_selling_price column
  SELECT COALESCE(current_selling_price, 0) INTO current_price
  FROM products
  WHERE id = product_uuid
    AND store_id = current_store_id     -- CRITICAL: Filter by store
    AND is_active = true;

  RETURN current_price;
END; $function$;

CREATE OR REPLACE FUNCTION public.get_current_user_store_id()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
AS $function$
    SELECT (auth.jwt() -> 'app_metadata' ->> 'store_id')::uuid;
  $function$;

CREATE OR REPLACE FUNCTION public.get_customer_debt_summary(p_store_id uuid, p_customer_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_user_store_id UUID;
    v_total_original DECIMAL(15,2);
    v_total_paid DECIMAL(15,2);
    v_total_remaining DECIMAL(15,2);
    v_debt_count INTEGER;
    v_oldest_debt_date TIMESTAMP;
BEGIN
    -- Validate user belongs to store
    SELECT store_id INTO v_user_store_id
    FROM user_profiles
    WHERE id = auth.uid() AND is_active = true;

    IF v_user_store_id IS NULL THEN
        RAISE EXCEPTION 'User not found or inactive';
    END IF;

    IF v_user_store_id != p_store_id THEN
        RAISE EXCEPTION 'User does not have access to this store';
    END IF;

    -- Calculate summary
    SELECT
        COALESCE(SUM(original_amount), 0),
        COALESCE(SUM(paid_amount), 0),
        COALESCE(SUM(remaining_amount), 0),
        COUNT(*),
        MIN(created_at)
    INTO
        v_total_original,
        v_total_paid,
        v_total_remaining,
        v_debt_count,
        v_oldest_debt_date
    FROM debts
    WHERE store_id = p_store_id
      AND customer_id = p_customer_id
      AND status != 'cancelled';

    RETURN jsonb_build_object(
        'total_original', v_total_original,
        'total_paid', v_total_paid,
        'total_remaining', v_total_remaining,
        'debt_count', v_debt_count,
        'oldest_debt_date', v_oldest_debt_date
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_customer_statistics(p_customer_id uuid, p_store_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_transaction_count INTEGER;
    v_total_revenue DECIMAL;
    v_outstanding_debt DECIMAL;
    result JSON;
BEGIN
    -- Get transaction count and total revenue
    SELECT
        COUNT(*)::INTEGER,
        COALESCE(SUM(total_amount), 0)::DECIMAL
    INTO
        v_transaction_count,
        v_total_revenue
    FROM transactions
    WHERE customer_id = p_customer_id
    AND store_id = p_store_id;

    -- Get outstanding debt (remaining amount from debts table)
    SELECT
        COALESCE(SUM(remaining_amount), 0)::DECIMAL
    INTO
        v_outstanding_debt
    FROM debts
    WHERE customer_id = p_customer_id
    AND store_id = p_store_id
    AND status IN ('pending', 'partial', 'overdue');

    -- Build result JSON
    result := json_build_object(
        'transaction_count', v_transaction_count,
        'total_revenue', v_total_revenue,
        'outstanding_debt', v_outstanding_debt
    );

    RETURN result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_estimated_count(table_name text, store_id_param uuid DEFAULT NULL::uuid)
RETURNS bigint
LANGUAGE plpgsql
AS $function$
DECLARE
    count_estimate bigint;
BEGIN
    -- For tables with RLS, use statistics for estimation
    IF table_name = 'products' THEN
        SELECT
            (reltuples * (
                SELECT COUNT(*)
                FROM pg_class c2
                WHERE c2.oid = c.oid
            ) / GREATEST(relpages, 1))::bigint
        INTO count_estimate
        FROM pg_class c
        WHERE relname = table_name;

        -- If we have store_id, estimate based on average distribution
        IF store_id_param IS NOT NULL THEN
            count_estimate := count_estimate / (
                SELECT COUNT(DISTINCT store_id) FROM products
            );
        END IF;
    ELSE
        -- Fallback to actual count for smaller tables
        EXECUTE format('SELECT COUNT(*) FROM %I', table_name) INTO count_estimate;
    END IF;

    RETURN COALESCE(count_estimate, 0);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_expiring_batches_report(p_months integer DEFAULT 3)
RETURNS TABLE(id uuid, product_id uuid, product_name text, product_sku text, company_name text, batch_number text, quantity integer, expiry_date date, days_until_expiry integer, cost_price numeric, received_date date, store_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  current_user_store_id uuid;
BEGIN
  -- SECURITY: Get current user's store_id
  SELECT store_id INTO current_user_store_id
  FROM public.user_profiles
  WHERE id = auth.uid();

  IF current_user_store_id IS NULL THEN
    RETURN; -- No access without store
  END IF;

  -- Return expiring batches for user's store only
  RETURN QUERY
  SELECT
    pb.id,
    pb.product_id,
    p.name as product_name,
    p.sku as product_sku,
    c.name as company_name,
    pb.batch_number,
    pb.quantity,
    pb.expiry_date,
    CASE
      WHEN pb.expiry_date IS NULL THEN NULL
      ELSE EXTRACT(days FROM (pb.expiry_date - CURRENT_DATE))::integer
    END as days_until_expiry,
    pb.cost_price,
    pb.received_date,
    pb.store_id
  FROM product_batches pb
  LEFT JOIN products p ON pb.product_id = p.id
  LEFT JOIN companies c ON p.company_id = c.id
  WHERE pb.is_available = true
    AND pb.quantity > 0
    AND pb.expiry_date IS NOT NULL
    AND pb.expiry_date <= CURRENT_DATE + (p_months || ' months')::interval
    AND pb.store_id = current_user_store_id  -- SECURITY: Filter by store
    AND p.store_id = current_user_store_id   -- SECURITY: Verify product belongs to store
  ORDER BY pb.expiry_date ASC;
END; $function$;

CREATE OR REPLACE FUNCTION public.get_gross_profit_percentage(p_product_id uuid)
RETURNS numeric
LANGUAGE plpgsql
AS $function$
DECLARE
    selling_price NUMERIC;
    avg_cost NUMERIC;
    profit_percentage NUMERIC;
BEGIN
    -- Get current selling price
    SELECT current_selling_price INTO selling_price
    FROM products
    WHERE id = p_product_id;

    -- Get average cost price
    SELECT get_average_cost_price(p_product_id) INTO avg_cost;

    -- Calculate profit percentage
    IF avg_cost > 0 THEN
        profit_percentage := ((selling_price - avg_cost) / avg_cost) * 100;
    ELSE
        profit_percentage := 0;
    END IF;

    RETURN ROUND(profit_percentage, 2);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_inventory_analytics_lists()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    current_user_store_id uuid;
    top_value_products jsonb;
    fast_turnover_products jsonb;
    slow_turnover_products jsonb;
BEGIN
    -- Get current user's store ID
    SELECT store_id INTO current_user_store_id
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF current_user_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    -- Top 5 products by inventory value (quantity * cost_price)
    SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO top_value_products
    FROM (
        SELECT
            p.id as product_id,
            p.name as product_name,
            p.sku,
            SUM(pb.quantity * pb.cost_price) as inventory_value,
            SUM(pb.quantity) as current_stock
        FROM product_batches pb
        JOIN products p ON pb.product_id = p.id
        WHERE pb.store_id = current_user_store_id
          AND p.store_id = current_user_store_id
          AND pb.is_available = true
          AND pb.quantity > 0
        GROUP BY p.id, p.name, p.sku
        ORDER BY inventory_value DESC
        LIMIT 5
    ) t;

    -- Top 5 products by turnover ratio (sales / average stock) in last 30 days
    SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO fast_turnover_products
    FROM (
        SELECT
            p.id as product_id,
            p.name as product_name,
            p.sku,
            SUM(ti.quantity) as total_sold,
            AVG(pb.quantity) as avg_stock,
            CASE
                WHEN AVG(pb.quantity) > 0 THEN SUM(ti.quantity) / AVG(pb.quantity)
                ELSE 0
            END as turnover_ratio
        FROM products p
        JOIN product_batches pb ON p.id = pb.product_id
        LEFT JOIN transaction_items ti ON p.id = ti.product_id
            AND ti.created_at >= NOW() - interval '30 days'
            AND ti.store_id = current_user_store_id
        WHERE p.store_id = current_user_store_id
          AND pb.store_id = current_user_store_id
          AND pb.is_available = true
          AND p.is_active = true
        GROUP BY p.id, p.name, p.sku
        HAVING SUM(ti.quantity) > 0
           AND AVG(pb.quantity) > 0
        ORDER BY turnover_ratio DESC
        LIMIT 5
    ) t;

    -- Bottom 5 products by turnover ratio (slowest movers with stock)
    SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO slow_turnover_products
    FROM (
        SELECT
            p.id as product_id,
            p.name as product_name,
            p.sku,
            COALESCE(SUM(ti.quantity), 0) as total_sold,
            AVG(pb.quantity) as avg_stock,
            CASE
                WHEN AVG(pb.quantity) > 0 THEN COALESCE(SUM(ti.quantity), 0) / AVG(pb.quantity)
                ELSE 0
            END as turnover_ratio
        FROM products p
        JOIN product_batches pb ON p.id = pb.product_id
        LEFT JOIN transaction_items ti ON p.id = ti.product_id
            AND ti.created_at >= NOW() - interval '30 days'
            AND ti.store_id = current_user_store_id
        WHERE p.store_id = current_user_store_id
          AND pb.store_id = current_user_store_id
          AND pb.is_available = true
          AND p.is_active = true
        GROUP BY p.id, p.name, p.sku
        HAVING AVG(pb.quantity) > 0
        ORDER BY turnover_ratio ASC
        LIMIT 5
    ) t;

    RETURN jsonb_build_object(
        'top_value_products', top_value_products,
        'fast_turnover_products', fast_turnover_products,
        'slow_turnover_products', slow_turnover_products
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_inventory_summary()
RETURNS TABLE(total_inventory_value numeric, total_selling_value numeric, potential_profit numeric, profit_margin numeric, total_items bigint, total_batches bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    current_user_store_id uuid;
BEGIN
    -- Get current user's store ID
    SELECT store_id INTO current_user_store_id
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF current_user_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    RETURN QUERY
    SELECT
        COALESCE(SUM(pb.quantity * pb.cost_price), 0) as total_inventory_value,
        COALESCE(SUM(pb.quantity * p.current_selling_price), 0) as total_selling_value,
        COALESCE(SUM(pb.quantity * (p.current_selling_price - pb.cost_price)), 0) as potential_profit,
        CASE
            WHEN SUM(pb.quantity * p.current_selling_price) > 0
            THEN (SUM(pb.quantity * (p.current_selling_price - pb.cost_price)) / SUM(pb.quantity * p.current_selling_price)) * 100
            ELSE 0
        END as profit_margin,
        COALESCE(SUM(pb.quantity), 0) as total_items,
        COUNT(pb.id) as total_batches
    FROM product_batches pb
    JOIN products p ON pb.product_id = p.id
    WHERE pb.store_id = current_user_store_id
      AND pb.is_available = true
      AND pb.quantity > 0;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_product_units(p_product_id uuid)
RETURNS TABLE(id uuid, product_id uuid, unit_name text, conversion_factor numeric, unit_price numeric, is_default_selling_unit boolean, is_active boolean, store_id uuid, created_at timestamp with time zone, updated_at timestamp with time zone)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    pu.id,
    pu.product_id,
    pu.unit_name,
    pu.conversion_factor,
    pu.unit_price,
    pu.is_default_selling_unit,
    pu.is_active,
    pu.store_id,
    pu.created_at,
    pu.updated_at
  FROM public.product_units pu
  WHERE pu.product_id = p_product_id
    AND pu.is_active = true
    AND pu.store_id IN (
      SELECT user_profiles.store_id
      FROM public.user_profiles
      WHERE user_profiles.id = auth.uid()
    )
  ORDER BY pu.is_default_selling_unit DESC, pu.unit_name ASC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_revenue_summary(start_date date, end_date date)
RETURNS TABLE(total_revenue numeric, total_transactions bigint, cash_revenue numeric, debt_revenue numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(total_amount), 0) as total_revenue,
        COUNT(id) as total_transactions,
        COALESCE(SUM(CASE WHEN payment_method = 'CASH' THEN total_amount ELSE 0 END), 0) as cash_revenue,
        COALESCE(SUM(CASE WHEN payment_method = 'DEBT' THEN total_amount ELSE 0 END), 0) as debt_revenue
    FROM public.transactions
    WHERE
        created_at >= start_date AND created_at < end_date + interval '1 day'
        AND store_id = get_current_user_store_id();
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_revenue_summary_with_comparison(p_start_date date, p_end_date date)
RETURNS TABLE(current_total_revenue numeric, current_total_profit numeric, current_total_transactions bigint, previous_total_revenue numeric, previous_total_profit numeric, previous_total_transactions bigint, revenue_change_percentage numeric, profit_change_percentage numeric, transactions_change_percentage numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    current_start_date date := p_start_date;
    current_end_date date := p_end_date;
    previous_start_date date;
    previous_end_date date;
    current_revenue NUMERIC;
    current_profit NUMERIC;
    current_transactions BIGINT;
    previous_revenue NUMERIC;
    previous_profit NUMERIC;
    previous_transactions BIGINT;
    user_store_id UUID;
BEGIN
    user_store_id := (current_setting('request.jwt.claims', true)::jsonb->'app_metadata'->>'store_id')::uuid;

    -- Calculate the date range for the previous period
    previous_end_date := current_start_date - INTERVAL '1 day';
    previous_start_date := previous_end_date - (current_end_date - current_start_date);

    -- Current period data
    SELECT
        COALESCE(SUM(total_amount), 0),
        COALESCE(SUM(total_profit), 0),
        COUNT(*)
    INTO
        current_revenue,
        current_profit,
        current_transactions
    FROM
        public.transactions
    WHERE
        store_id = user_store_id
        AND created_at >= current_start_date
        AND created_at < (current_end_date + INTERVAL '1 day');

    -- Previous period data
    SELECT
        COALESCE(SUM(total_amount), 0),
        COALESCE(SUM(total_profit), 0),
        COUNT(*)
    INTO
        previous_revenue,
        previous_profit,
        previous_transactions
    FROM
        public.transactions
    WHERE
        store_id = user_store_id
        AND created_at >= previous_start_date
        AND created_at < (previous_end_date + INTERVAL '1 day');

    -- Calculate percentage changes
    revenue_change_percentage := CASE
        WHEN previous_revenue > 0 THEN ((current_revenue - previous_revenue) / previous_revenue) * 100
        ELSE 0
    END;

    profit_change_percentage := CASE
        WHEN previous_profit > 0 THEN ((current_profit - previous_profit) / previous_profit) * 100
        ELSE 0
    END;

    transactions_change_percentage := CASE
        WHEN previous_transactions > 0 THEN ((current_transactions - previous_transactions)::NUMERIC / previous_transactions) * 100
        ELSE 0
    END;

    RETURN QUERY SELECT
        current_revenue,
        current_profit,
        current_transactions,
        previous_revenue,
        previous_profit,
        previous_transactions,
        revenue_change_percentage,
        profit_change_percentage,
        transactions_change_percentage;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_revenue_trend(p_start_date date, p_end_date date, p_period_type text)
RETURNS TABLE(report_date date, current_period_revenue numeric, previous_period_revenue numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_store_id UUID;
  v_current_start_date DATE;
  v_current_end_date DATE;
  v_previous_start_date DATE;
  v_previous_end_date DATE;
  v_interval_unit TEXT;
  v_interval_value INTEGER;
BEGIN
  v_store_id := (current_setting('request.jwt.claims', true)::jsonb->'app_metadata'->>'store_id')::uuid;
  v_current_start_date := p_start_date;
  v_current_end_date := p_end_date;

  -- Determine previous period dates
  IF p_period_type = 'week' THEN
    v_previous_start_date := v_current_start_date - INTERVAL '7 days';
    v_previous_end_date := v_current_end_date - INTERVAL '7 days';
    v_interval_unit := 'day';
    v_interval_value := 1;
  ELSIF p_period_type = 'month' THEN
    v_previous_start_date := v_current_start_date - INTERVAL '1 month';
    v_previous_end_date := v_current_end_date - INTERVAL '1 month';
    v_interval_unit := 'day';
    v_interval_value := 1;
  ELSIF p_period_type = 'quarter' THEN
    v_previous_start_date := v_current_start_date - INTERVAL '3 months';
    v_previous_end_date := v_current_end_date - INTERVAL '3 months';
    v_interval_unit := 'week';
    v_interval_value := 1;
  ELSIF p_period_type = 'year' THEN
    v_previous_start_date := v_current_start_date - INTERVAL '1 year';
    v_previous_end_date := v_current_end_date - INTERVAL '1 year';
    v_interval_unit := 'month';
    v_interval_value := 1;
  ELSE
    RAISE EXCEPTION 'Invalid period type. Must be one of: week, month, quarter, year';
  END IF;

  RETURN QUERY
  WITH date_series AS (
    SELECT generate_series(
      v_current_start_date::timestamp,
      v_current_end_date::timestamp,
      (v_interval_value || ' ' || v_interval_unit)::interval
    )::date AS report_date
  ),
  current_period_data AS (
    SELECT
      date_trunc(v_interval_unit, created_at)::date AS report_date,
      SUM(total_amount) AS revenue
    FROM transactions
    WHERE
      store_id = v_store_id AND
      created_at >= v_current_start_date AND
      created_at < (v_current_end_date + INTERVAL '1 day')
    GROUP BY 1
  ),
  previous_period_data AS (
    SELECT
      (date_trunc(v_interval_unit, created_at)::date +
        (v_current_start_date - v_previous_start_date)) AS report_date,
      SUM(total_amount) AS revenue
    FROM transactions
    WHERE
      store_id = v_store_id AND
      created_at >= v_previous_start_date AND
      created_at < (v_previous_end_date + INTERVAL '1 day')
    GROUP BY 1
  )
  SELECT
    ds.report_date,
    COALESCE(cpd.revenue, 0) AS current_period_revenue,
    COALESCE(ppd.revenue, 0) AS previous_period_revenue
  FROM date_series ds
  LEFT JOIN current_period_data cpd ON ds.report_date = cpd.report_date
  LEFT JOIN previous_period_data ppd ON ds.report_date = ppd.report_date
  ORDER BY ds.report_date;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_sales_ledger_for_export(p_start_date timestamp with time zone, p_end_date timestamp with time zone)
RETURNS TABLE(transaction_id uuid, created_at timestamp with time zone, customer_name text, total_amount numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_store_id UUID;
BEGIN
  -- Get current user's store_id
  v_store_id := (current_setting('request.jwt.claims', true)::json->'app_metadata'->>'store_id')::uuid;

  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated and have a valid store_id';
  END IF;

  -- Return detailed sales ledger data
  RETURN QUERY
  SELECT
    t.id AS transaction_id,
    t.created_at,
    COALESCE(c.name, 'Khách lẻ') AS customer_name,
    t.total_amount
  FROM transactions t
  LEFT JOIN customers c ON t.customer_id = c.id
  WHERE t.store_id = v_store_id
    AND t.created_at BETWEEN p_start_date AND p_end_date
  ORDER BY t.created_at DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_tax_summary(p_start_date timestamp with time zone, p_end_date timestamp with time zone)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_store_id UUID;
  v_total_revenue NUMERIC;
  v_total_vat NUMERIC;
  v_vat_rate NUMERIC;
  result JSON;
BEGIN
  -- Get current user's store_id
  v_store_id := (current_setting('request.jwt.claims', true)::json->'app_metadata'->>'store_id')::uuid;

  -- Get store's VAT rate
  SELECT vat_rate INTO v_vat_rate
  FROM stores
  WHERE id = v_store_id;

  IF v_vat_rate IS NULL THEN
    v_vat_rate := 0; -- Default to 0 if not set
  END IF;

  -- Calculate total revenue and VAT for the period
  SELECT
    COALESCE(SUM(total_amount), 0),
    COALESCE(SUM(total_amount * v_vat_rate), 0)
  INTO
    v_total_revenue,
    v_total_vat
  FROM transactions
  WHERE store_id = v_store_id
    AND created_at BETWEEN p_start_date AND p_end_date;

  -- Build the result JSON
  result := json_build_object(
      'start_date', p_start_date,
      'end_date', p_end_date,
      'total_revenue', v_total_revenue,
      'vat_rate', v_vat_rate,
      'total_vat', v_total_vat
  );

  RETURN result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_top_performing_products(p_start_date date, p_end_date date, p_limit integer)
RETURNS TABLE(product_id uuid, product_name text, total_quantity numeric, total_revenue numeric, total_profit numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        ti.product_id,
        p.name AS product_name,
        SUM(ti.quantity) AS total_quantity,
        SUM(ti.sub_total) AS total_revenue,
        SUM(ti.sub_total - (ti.quantity * pb.cost_price)) AS total_profit
    FROM public.transaction_items ti
    JOIN public.products p ON ti.product_id = p.id
    JOIN public.product_batches pb ON ti.batch_id = pb.id
    WHERE
        ti.created_at >= p_start_date AND ti.created_at < p_end_date + interval '1 day'
        AND ti.store_id = get_current_user_store_id()
    GROUP BY
        ti.product_id,
        p.name
    ORDER BY
        total_revenue DESC
    LIMIT
        p_limit;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_user_store_id()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN (
    SELECT store_id
    FROM public.user_profiles
    WHERE id = auth.uid()
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_store_owner()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN (
    SELECT role = 'OWNER'
    FROM public.user_profiles
    WHERE id = auth.uid()
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.log_auth_event(event_type text, event_data jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.auth_logs (event_type, user_id, event_data)
  VALUES (event_type, auth.uid(), event_data);
END;
$function$;

CREATE OR REPLACE FUNCTION public.log_slow_query(p_query_text text, p_execution_time_ms integer)
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO public.slow_queries (query_text, execution_time_ms)
  VALUES (p_query_text, p_execution_time_ms);
END;
$function$;

CREATE OR REPLACE FUNCTION public.migrate_existing_data_to_stores()
RETURNS text
LANGUAGE plpgsql
AS $function$
DECLARE
  v_store_id UUID;
  v_user_id UUID;
BEGIN
  -- Create a default store if one doesn't exist
  IF NOT EXISTS (SELECT 1 FROM public.stores) THEN
    INSERT INTO public.stores (name) VALUES ('Default Store') RETURNING id INTO v_store_id;
  ELSE
    SELECT id INTO v_store_id FROM public.stores LIMIT 1;
  END IF;

  -- Get the current user's ID
  v_user_id := auth.uid();

  -- Update user_profiles to link all users to this store
  UPDATE public.user_profiles SET store_id = v_store_id WHERE store_id IS NULL;

  -- Update other tables that now require a store_id
  UPDATE public.products SET store_id = v_store_id WHERE store_id IS NULL;
  UPDATE public.product_batches SET store_id = v_store_id WHERE store_id IS NULL;
  UPDATE public.customers SET store_id = v_store_id WHERE store_id IS NULL;
  UPDATE public.transactions SET store_id = v_store_id WHERE store_id IS NULL;
  UPDATE public.transaction_items SET store_id = v_store_id WHERE store_id IS NULL;
  UPDATE public.debts SET store_id = v_store_id WHERE store_id IS NULL;
  UPDATE public.payments SET store_id = v_store_id WHERE store_id IS NULL;
  UPDATE public.suppliers SET store_id = v_store_id WHERE store_id IS NULL;
  UPDATE public.purchase_orders SET store_id = v_store_id WHERE store_id IS NULL;
  UPDATE public.purchase_order_items SET store_id = v_store_id WHERE store_id IS NULL;
  UPDATE public.employee_invitations SET store_id = v_store_id WHERE store_id IS NULL;
  UPDATE public.audits SET store_id = v_store_id WHERE store_id IS NULL;

  RETURN 'Data migration to default store completed successfully.';
END;
$function$;

CREATE OR REPLACE FUNCTION public.process_customer_payment(p_store_id uuid, p_customer_id uuid, p_payment_amount numeric, p_payment_method text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_user_store_id UUID;
  v_debt_record RECORD;
  v_remaining_payment NUMERIC := p_payment_amount;
  v_payment_id UUID;
  v_payments_applied JSONB := '[]'::jsonb;
BEGIN
  -- Validate user belongs to the store
  SELECT store_id INTO v_user_store_id
  FROM user_profiles
  WHERE id = auth.uid() AND is_active = true;

  IF v_user_store_id IS NULL OR v_user_store_id != p_store_id THEN
    RAISE EXCEPTION 'User not found, inactive, or does not belong to the specified store';
  END IF;

  -- Validate payment amount
  IF p_payment_amount <= 0 THEN
    RAISE EXCEPTION 'Payment amount must be positive';
  END IF;

  -- Insert the main payment record first
  INSERT INTO public.payments (
    store_id,
    customer_id,
    amount,
    payment_method,
    created_by
  ) VALUES (
    p_store_id,
    p_customer_id,
    p_payment_amount,
    p_payment_method,
    auth.uid()
  )
  RETURNING id INTO v_payment_id;

  -- Loop through outstanding debts for the customer in the given store
  FOR v_debt_record IN
    SELECT id, remaining_amount
    FROM debts
    WHERE customer_id = p_customer_id
      AND store_id = p_store_id
      AND status IN ('pending', 'partial', 'overdue')
    ORDER BY due_date ASC, created_at ASC
  LOOP
    IF v_remaining_payment <= 0 THEN
      EXIT; -- Exit loop if payment is fully applied
    END IF;

    DECLARE
      v_amount_to_apply NUMERIC;
    BEGIN
      -- Determine how much of the payment to apply to this debt
      v_amount_to_apply := LEAST(v_remaining_payment, v_debt_record.remaining_amount);

      -- Update debt record
      UPDATE debts
      SET
        paid_amount = paid_amount + v_amount_to_apply,
        remaining_amount = remaining_amount - v_amount_to_apply,
        status = CASE
          WHEN (remaining_amount - v_amount_to_apply) <= 0 THEN 'paid'
          ELSE 'partial'
        END,
        updated_at = NOW()
      WHERE id = v_debt_record.id;

      -- Create a record in debt_payments to link the payment to the debt
      INSERT INTO public.debt_payments (
        debt_id,
        payment_id,
        amount_applied,
        store_id,
        customer_id
      ) VALUES (
        v_debt_record.id,
        v_payment_id,
        v_amount_to_apply,
        p_store_id,
        p_customer_id
      );

      -- Add to the list of applied payments for the return value
      v_payments_applied := v_payments_applied || jsonb_build_object(
        'debt_id', v_debt_record.id,
        'amount_applied', v_amount_to_apply
      );

      -- Decrease the remaining payment amount
      v_remaining_payment := v_remaining_payment - v_amount_to_apply;
    END;
  END LOOP;

  -- Handle overpayment by crediting the customer's account
  IF v_remaining_payment > 0 THEN
    UPDATE public.customers
    SET credit_balance = credit_balance + v_remaining_payment
    WHERE id = p_customer_id AND store_id = p_store_id;

    -- Optionally, log this overpayment for auditing
    -- INSERT INTO payment_logs (...)
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'payment_id', v_payment_id,
    'total_paid', p_payment_amount,
    'remaining_credit', v_remaining_payment,
    'payments_applied', v_payments_applied
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_daily_revenue_summary()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
  REFRESH MATERIALIZED VIEW public.daily_revenue_summary;
END;
$function$;

CREATE OR REPLACE FUNCTION public.search_purchase_orders(p_search_text text DEFAULT NULL::text, p_status text DEFAULT NULL::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_sort_by text DEFAULT 'created_at'::text, p_sort_order text DEFAULT 'desc'::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 10)
RETURNS SETOF purchase_orders_with_details
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_store_id UUID;
  v_offset INTEGER;
BEGIN
  -- Get current user's store_id
  SELECT store_id INTO v_store_id
  FROM public.user_profiles
  WHERE id = auth.uid();

  IF v_store_id IS NULL THEN
    RETURN; -- Or raise an exception, depending on desired behavior
  END IF;

  v_offset := (p_page - 1) * p_page_size;

  RETURN QUERY
  EXECUTE format(
    $query$
      SELECT
        po.id,
        po.store_id,
        po.supplier_id,
        s.name as supplier_name,
        po.po_number,
        po.order_date,
        po.delivery_date,
        po.status,
        po.notes,
        po.total_amount,
        po.created_at,
        po.updated_at,
        (SELECT
          COALESCE(json_agg(
            json_build_object(
              'id', poi.id,
              'product_id', p.id,
              'product_name', p.name,
              'product_sku', p.sku,
              'quantity', poi.quantity,
              'unit_cost', poi.unit_cost,
              'total_cost', poi.total_cost,
              'received_quantity', poi.received_quantity,
              'selling_price', poi.selling_price
            )
          ), '[]'::json)
         FROM public.purchase_order_items poi
         JOIN public.products p ON poi.product_id = p.id
         WHERE poi.purchase_order_id = po.id) as items
      FROM public.purchase_orders po
      LEFT JOIN public.companies s ON po.supplier_id = s.id
      WHERE po.store_id = %L
        AND (p_search_text IS NULL OR po.po_number ILIKE '%%' || p_search_text || '%%' OR s.name ILIKE '%%' || p_search_text || '%%')
        AND (p_status IS NULL OR po.status = p_status)
        AND (p_start_date IS NULL OR po.order_date >= p_start_date)
        AND (p_end_date IS NULL OR po.order_date <= p_end_date)
      ORDER BY
        CASE WHEN %L = 'desc' THEN
          CASE %L
            WHEN 'order_date' THEN po.order_date
            WHEN 'total_amount' THEN po.total_amount
            ELSE po.created_at
          END
        END DESC,
        CASE WHEN %L = 'asc' THEN
          CASE %L
            WHEN 'order_date' THEN po.order_date
            WHEN 'total_amount' THEN po.total_amount
            ELSE po.created_at
          END
        END ASC
      LIMIT %L OFFSET %L;
    $query$,
    v_store_id, p_search_text, p_status, p_start_date, p_end_date, p_sort_order, p_sort_by, p_sort_order, p_sort_by, p_page_size, v_offset
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.search_transactions(p_search_text text DEFAULT NULL::text, p_payment_method text DEFAULT NULL::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_sort_by text DEFAULT 'created_at'::text, p_sort_order text DEFAULT 'desc'::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 10)
RETURNS TABLE(id uuid, created_at timestamp with time zone, store_id uuid, customer_id uuid, total_amount numeric, payment_method text, is_debt boolean, transaction_id text, invoice_number text, customer_name text, total_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_store_id UUID;
    v_offset INTEGER;
BEGIN
    -- Get the current user's store_id
    v_store_id := get_current_user_store_id();

    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    v_offset := (p_page - 1) * p_page_size;

    RETURN QUERY
    WITH filtered_transactions AS (
        SELECT
            t.id,
            t.created_at,
            t.store_id,
            t.customer_id,
            t.total_amount,
            t.payment_method,
            t.is_debt,
            'HD-' || LPAD(t.sequence_number::text, 6, '0') as transaction_id,
            t.invoice_number,
            c.name as customer_name
        FROM public.transactions t
        LEFT JOIN public.customers c ON t.customer_id = c.id
        WHERE
            t.store_id = v_store_id
            AND (p_search_text IS NULL OR
                 c.name ILIKE '%' || p_search_text || '%' OR
                 p.name ILIKE '%' || p_search_text || '%' OR
                 p.sku ILIKE '%' || p_search_text || '%'
            )
            AND (p_payment_method IS NULL OR t.payment_method = p_payment_method)
            AND (p_start_date IS NULL OR t.created_at::date >= p_start_date)
            AND (p_end_date IS NULL OR t.created_at::date <= p_end_date)
        -- Added join for product search
        LEFT JOIN public.transaction_items ti ON t.id = ti.transaction_id
        LEFT JOIN public.products p ON ti.product_id = p.id
    ),
    counted_transactions AS (
        SELECT *, COUNT(*) OVER() as total_count
        FROM (SELECT DISTINCT * FROM filtered_transactions) as unique_transactions
    )
    SELECT
        ct.id,
        ct.created_at,
        ct.store_id,
        ct.customer_id,
        ct.total_amount,
        ct.payment_method,
        ct.is_debt,
        ct.transaction_id,
        ct.invoice_number,
        ct.customer_name,
        ct.total_count
    FROM counted_transactions ct
    ORDER BY
        CASE WHEN p_sort_by = 'created_at' AND p_sort_order = 'asc' THEN ct.created_at END ASC,
        CASE WHEN p_sort_by = 'created_at' AND p_sort_order = 'desc' THEN ct.created_at END DESC,
        CASE WHEN p_sort_by = 'total_amount' AND p_sort_order = 'asc' THEN ct.total_amount END ASC,
        CASE WHEN p_sort_by = 'total_amount' AND p_sort_order = 'desc' THEN ct.total_amount END DESC
    LIMIT p_page_size
    OFFSET v_offset;
END;
$function$;

CREATE OR REPLACE FUNCTION public.search_transactions_with_items(p_search_text text DEFAULT NULL::text, p_payment_method text DEFAULT NULL::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_sort_by text DEFAULT 'created_at'::text, p_sort_order text DEFAULT 'desc'::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 10)
RETURNS TABLE(id uuid, created_at timestamp with time zone, store_id uuid, customer_id uuid, total_amount numeric, payment_method text, is_debt boolean, transaction_id text, invoice_number text, customer_name text, total_count bigint, items jsonb)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_store_id UUID;
    v_offset INTEGER;
BEGIN
    -- Get the current user's store_id
    v_store_id := get_current_user_store_id();

    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    v_offset := (p_page - 1) * p_page_size;

    RETURN QUERY
    WITH filtered_transactions AS (
        SELECT
            t.id,
            t.created_at,
            t.store_id,
            t.customer_id,
            t.total_amount,
            t.payment_method,
            t.is_debt,
            'HD-' || LPAD(t.sequence_number::text, 6, '0') as transaction_id_str,
            t.invoice_number,
            c.name as customer_name
        FROM public.transactions t
        LEFT JOIN public.customers c ON t.customer_id = c.id
        LEFT JOIN public.transaction_items ti ON t.id = ti.transaction_id
        LEFT JOIN public.products p ON ti.product_id = p.id
        WHERE
            t.store_id = v_store_id
            AND (p_search_text IS NULL OR
                 c.name ILIKE '%' || p_search_text || '%' OR
                 p.name ILIKE '%' || p_search_text || '%' OR
                 p.sku ILIKE '%' || p_search_text || '%'
            )
            AND (p_payment_method IS NULL OR t.payment_method = p_payment_method)
            AND (p_start_date IS NULL OR t.created_at::date >= p_start_date)
            AND (p_end_date IS NULL OR t.created_at::date <= p_end_date)
        GROUP BY t.id, c.name
    ),
    counted_transactions AS (
        SELECT *, COUNT(*) OVER() as total_count FROM filtered_transactions
    ),
    paginated_transactions AS (
      SELECT * FROM counted_transactions
      ORDER BY
          CASE WHEN p_sort_by = 'created_at' AND p_sort_order = 'asc' THEN created_at END ASC,
          CASE WHEN p_sort_by = 'created_at' AND p_sort_order = 'desc' THEN created_at END DESC,
          CASE WHEN p_sort_by = 'total_amount' AND p_sort_order = 'asc' THEN total_amount END ASC,
          CASE WHEN p_sort_by = 'total_amount' AND p_sort_order = 'desc' THEN total_amount END DESC
      LIMIT p_page_size
      OFFSET v_offset
    )
    SELECT
        pt.id,
        pt.created_at,
        pt.store_id,
        pt.customer_id,
        pt.total_amount,
        pt.payment_method,
        pt.is_debt,
        pt.transaction_id_str as transaction_id,
        pt.invoice_number,
        pt.customer_name,
        pt.total_count,
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'product_name', p.name,
                    'quantity', ti.quantity,
                    'unit_price', ti.unit_price,
                    'sub_total', ti.sub_total
                )
            )
            FROM public.transaction_items ti
            JOIN public.products p ON ti.product_id = p.id
            WHERE ti.transaction_id = pt.id
        ) as items
    FROM paginated_transactions pt;
END;
$function$;

CREATE OR REPLACE FUNCTION public.search_transactions_with_units(p_search_text text DEFAULT ''::text, p_payment_method text DEFAULT NULL::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_sort_by text DEFAULT 'created_at'::text, p_sort_order text DEFAULT 'desc'::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 10)
RETURNS TABLE(transaction_id uuid, customer_name text, total_amount numeric, transaction_date timestamp with time zone, payment_method text, items json)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  user_store_id UUID;
BEGIN
  -- Get the store ID of the current user
  SELECT store_id INTO user_store_id FROM public.user_profiles WHERE id = auth.uid();

  -- If the user is not associated with a store, return nothing
  IF user_store_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH transaction_base AS (
    SELECT
      t.id as transaction_id,
      COALESCE(c.name, 'Khách lẻ') as customer_name,
      t.total_amount,
      t.created_at as transaction_date,
      t.payment_method,
      t.store_id
    FROM public.transactions t
    LEFT JOIN public.customers c ON t.customer_id = c.id
    WHERE t.store_id = user_store_id
      AND (p_start_date IS NULL OR t.created_at::date >= p_start_date)
      AND (p_end_date IS NULL OR t.created_at::date <= p_end_date)
      AND (p_payment_method IS NULL OR t.payment_method = p_payment_method)
      AND (
        p_search_text IS NULL OR
        t.id::text ILIKE '%' || p_search_text || '%' OR
        COALESCE(c.name, '') ILIKE '%' || p_search_text || '%' OR
        COALESCE(c.phone_number, '') ILIKE '%' || p_search_text || '%' OR
        EXISTS (
          SELECT 1
          FROM public.transaction_items ti
          JOIN public.products p ON ti.product_id = p.id
          WHERE ti.transaction_id = t.id AND (
            p.name ILIKE '%' || p_search_text || '%' OR
            p.sku ILIKE '%' || p_search_text || '%'
          )
        )
      )
  ),
  transaction_items_agg AS (
    SELECT
      ti.transaction_id,
      json_agg(
        json_build_object(
          'product_name', p.name,
          'quantity', ti.quantity,
          'unit_name', pu.unit_name,
          'price_at_sale', ti.price_at_sale,
          'sub_total', ti.sub_total
        )
      ) as items
    FROM public.transaction_items ti
    JOIN public.products p ON ti.product_id = p.id
    LEFT JOIN public.product_units pu ON ti.unit_id = pu.id
    WHERE ti.transaction_id IN (SELECT tb.transaction_id FROM transaction_base)
    GROUP BY ti.transaction_id
  )
  SELECT
    tb.transaction_id,
    tb.customer_name,
    tb.total_amount,
    tb.transaction_date,
    tb.payment_method,
    tia.items
  FROM transaction_base tb
  JOIN transaction_items_agg tia ON tb.transaction_id = tia.transaction_id
  ORDER BY
    CASE WHEN p_sort_by = 'transaction_date' AND p_sort_order = 'asc' THEN tb.transaction_date END ASC,
    CASE WHEN p_sort_by = 'transaction_date' AND p_sort_order = 'desc' THEN tb.transaction_date END DESC,
    CASE WHEN p_sort_by = 'total_amount' AND p_sort_order = 'asc' THEN tb.total_amount END ASC,
    CASE WHEN p_sort_by = 'total_amount' AND p_sort_order = 'desc' THEN tb.total_amount END DESC
  LIMIT p_page_size
  OFFSET (p_page - 1) * p_page_size;
END;
$function$;

CREATE OR REPLACE FUNCTION public.store_biometric_context(p_user_id uuid, p_device_id text, p_challenge text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_store_id UUID;
  v_user_profile RECORD;
BEGIN
  -- Validate user
  SELECT * INTO v_user_profile
  FROM public.user_profiles
  WHERE id = p_user_id AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found or inactive';
  END IF;

  -- Store device and challenge
  INSERT INTO public.user_sessions (user_id, device_id, challenge, status)
  VALUES (p_user_id, p_device_id, p_challenge, 'PENDING')
  ON CONFLICT (user_id, device_id) DO UPDATE
  SET challenge = p_challenge, status = 'PENDING', created_at = NOW(), expires_at = NOW() + INTERVAL '5 minutes';

  -- Return store_id
  RETURN v_user_profile.store_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_inventory_fifo_batch(items_json jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  item JSONB;
  v_product_id UUID;
  v_quantity_to_deduct NUMERIC;
  v_unit_id UUID;
  v_conversion_factor NUMERIC;
  v_base_quantity_to_deduct NUMERIC;
  v_total_deducted NUMERIC := 0;
  v_total_cost_of_goods_sold NUMERIC := 0;
  batch_record RECORD;
  user_store_id UUID;
  product_name_text TEXT;
  total_available_stock NUMERIC;
  results JSONB[] := ARRAY[]::JSONB[];
BEGIN
  -- 1. Check user authorization
  user_store_id := (current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'store_id')::uuid;
  IF user_store_id IS NULL THEN
    RAISE EXCEPTION 'User does not have an assigned store.';
  END IF;

  -- 2. Loop through each item in the JSON array
  FOR item IN SELECT * FROM jsonb_array_elements(items_json)
  LOOP
    -- 3. Extract item details
    v_product_id := (item->>'product_id')::UUID;
    v_quantity_to_deduct := (item->>'quantity')::NUMERIC;
    v_unit_id := (item->>'unit_id')::UUID;
    v_total_deducted := 0;

    -- 4. Get product name for error messages
    SELECT name INTO product_name_text FROM products WHERE id = v_product_id;

    -- 5. Get unit conversion factor
    SELECT conversion_factor INTO v_conversion_factor FROM product_units WHERE id = v_unit_id;
    IF v_conversion_factor IS NULL THEN
        RAISE EXCEPTION 'Invalid unit ID: % for product %', v_unit_id, product_name_text;
    END IF;
    v_base_quantity_to_deduct := v_quantity_to_deduct * v_conversion_factor;

    -- 6. Check for sufficient stock in base units
    SELECT SUM(quantity) INTO total_available_stock
    FROM product_batches
    WHERE product_id = v_product_id
      AND store_id = user_store_id
      AND is_available = true
      AND quantity > 0;

    IF COALESCE(total_available_stock, 0) < v_base_quantity_to_deduct THEN
        RAISE EXCEPTION 'Insufficient stock for product % (ID: %). Required: %, Available: %',
                        product_name_text, v_product_id, v_base_quantity_to_deduct, total_available_stock;
    END IF;

    -- 7. Deduct from batches using FIFO
    FOR batch_record IN
        SELECT id, quantity, cost_price
        FROM product_batches
        WHERE product_id = v_product_id
          AND store_id = user_store_id
          AND is_available = true
          AND quantity > 0
        ORDER BY received_date ASC, created_at ASC
    LOOP
      IF v_base_quantity_to_deduct <= 0 THEN
        EXIT; -- Exit if the required quantity has been fulfilled
      END IF;

      DECLARE
        deduct_amount NUMERIC;
      BEGIN
        deduct_amount := LEAST(v_base_quantity_to_deduct, batch_record.quantity);

        UPDATE product_batches
        SET quantity = quantity - deduct_amount
        WHERE id = batch_record.id;

        v_base_quantity_to_deduct := v_base_quantity_to_deduct - deduct_amount;
        v_total_deducted := v_total_deducted + deduct_amount;
        v_total_cost_of_goods_sold := v_total_cost_of_goods_sold + (deduct_amount * batch_record.cost_price);

        -- Add batch deduction info to results
        results := array_append(results, jsonb_build_object(
            'product_id', v_product_id,
            'batch_id', batch_record.id,
            'deducted_quantity', deduct_amount,
            'cost_price', batch_record.cost_price
        ));
      END;
    END LOOP;

    -- 8. Final check for any discrepancy (should not happen if stock check is correct)
    IF v_base_quantity_to_deduct > 0 THEN
      RAISE EXCEPTION 'Inventory update failed for product % (ID: %). Could not deduct the full quantity.', product_name_text, v_product_id;
    END IF;

  END LOOP;

  -- 9. Return detailed result
  RETURN jsonb_build_object(
    'success', true,
    'total_cost_of_goods_sold', v_total_cost_of_goods_sold,
    'deducted_items', to_jsonb(results)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_po_totals()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_total_amount NUMERIC;
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    SELECT COALESCE(SUM(total_cost), 0)
    INTO v_total_amount
    FROM public.purchase_order_items
    WHERE purchase_order_id = NEW.purchase_order_id;

    UPDATE public.purchase_orders
    SET total_amount = v_total_amount,
        updated_at = NOW()
    WHERE id = NEW.purchase_order_id;

    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT COALESCE(SUM(total_cost), 0)
    INTO v_total_amount
    FROM public.purchase_order_items
    WHERE purchase_order_id = OLD.purchase_order_id;

    UPDATE public.purchase_orders
    SET total_amount = v_total_amount,
        updated_at = NOW()
    WHERE id = OLD.purchase_order_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_product_search_vector()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.fts := setweight(to_tsvector('simple', coalesce(NEW.name, '')), 'A') ||
               setweight(to_tsvector('simple', coalesce(NEW.sku, '')), 'A') ||
               setweight(to_tsvector('simple', coalesce(NEW.description, '')), 'B') ||
               setweight(to_tsvector('simple', coalesce((NEW.attributes->>'brand'), '')), 'B') ||
               setweight(to_tsvector('simple', coalesce((NEW.attributes->>'active_ingredient'), '')), 'C');
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_product_selling_price(p_product_id uuid, p_new_price numeric, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID;
    v_store_id UUID;
    v_old_price NUMERIC;
BEGIN
    -- Get the current user's ID and store ID
    v_user_id := auth.uid();
    SELECT store_id INTO v_store_id
    FROM public.user_profiles
    WHERE id = v_user_id;

    -- Check if user is associated with a store
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'User is not associated with any store.';
    END IF;

    -- Get the current price of the product
    SELECT current_selling_price INTO v_old_price
    FROM public.products
    WHERE id = p_product_id AND store_id = v_store_id;

    -- If the product does not exist or does not belong to the user's store
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found or you do not have permission to modify it.';
    END IF;

    -- Update the product's selling price
    UPDATE public.products
    SET current_selling_price = p_new_price,
        updated_at = now()
    WHERE id = p_product_id
      AND store_id = v_store_id;

    -- Insert a record into the price history
    INSERT INTO public.price_history (
        product_id,
        old_price,
        new_price,
        changed_by,
        reason,
        store_id
    )
    VALUES (
        p_product_id,
        v_old_price,
        p_new_price,
        v_user_id,
        p_reason,
        v_store_id
    );

END;
$function$;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
   NEW.updated_at = now();
   RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.user_has_role(required_role text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN (
    SELECT role = required_role
    FROM public.user_profiles
    WHERE id = auth.uid()
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.validate_app_refresh_token(p_user_id uuid, p_device_id text, p_refresh_token text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  session_record RECORD;
  result JSON;
  token_validity_duration INTERVAL := '30 days'; -- How long refresh tokens are valid
BEGIN
  -- Find the most recent valid session for this user and device
  SELECT * INTO session_record
  FROM public.user_sessions
  WHERE user_id = p_user_id
    AND device_id = p_device_id
    AND refresh_token = p_refresh_token
    AND expires_at > NOW()
    AND revoked_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1;

  -- If no valid session is found, return an error
  IF NOT FOUND THEN
    result := json_build_object(
      'is_valid', false,
      'message', 'Invalid or expired refresh token'
    );
    RETURN result;
  END IF;

  -- If a valid session is found, update its expiry and return success
  UPDATE public.user_sessions
  SET expires_at = NOW() + token_validity_duration
  WHERE id = session_record.id;

  result := json_build_object(
    'is_valid', true,
    'session_id', session_record.id,
    'user_id', session_record.user_id,
    'new_expires_at', NOW() + token_validity_duration
  );
  RETURN result;
END;
$function$;

CREATE OR REPLACE FUNCTION extensions.pg_stat_statements(showtext boolean, OUT userid oid, OUT dbid oid, OUT toplevel boolean, OUT queryid bigint, OUT query text, OUT plans bigint, OUT total_plan_time double precision, OUT min_plan_time double precision, OUT max_plan_time double precision, OUT mean_plan_time double precision, OUT stddev_plan_time double precision, OUT calls bigint, OUT total_exec_time double precision, OUT min_exec_time double precision, OUT max_exec_time double precision, OUT mean_exec_time double precision, OUT stddev_exec_time double precision, OUT rows bigint, OUT shared_blks_hit bigint, OUT shared_blks_read bigint, OUT shared_blks_dirtied bigint, OUT shared_blks_written bigint, OUT local_blks_hit bigint, OUT local_blks_read bigint, OUT local_blks_dirtied bigint, OUT local_blks_written bigint, OUT temp_blks_read bigint, OUT temp_blks_written bigint, OUT shared_blk_read_time double precision, OUT shared_blk_write_time double precision, OUT local_blk_read_time double precision, OUT local_blk_write_time double precision, OUT temp_blk_read_time double precision, OUT temp_blk_write_time double precision, OUT wal_records bigint, OUT wal_fpi bigint, OUT wal_bytes numeric, OUT jit_functions bigint, OUT jit_generation_time double precision, OUT jit_inlining_count bigint, OUT jit_inlining_time double precision, OUT jit_optimization_count bigint, OUT jit_optimization_time double precision, OUT jit_emission_count bigint, OUT jit_emission_time double precision, OUT jit_deform_count bigint, OUT jit_deform_time double precision, OUT stats_since timestamp with time zone, OUT minmax_stats_since timestamp with time zone)
RETURNS SETOF record
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/pg_stat_statements', 'pg_stat_statements_1_11';

CREATE OR REPLACE FUNCTION extensions.pg_stat_statements_info(OUT dealloc bigint, OUT stats_reset timestamp with time zone)
RETURNS record
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/pg_stat_statements', 'pg_stat_statements_info';

CREATE OR REPLACE FUNCTION extensions.pg_stat_statements_reset(userid oid DEFAULT 0, dbid oid DEFAULT 0, queryid bigint DEFAULT 0, minmax_only boolean DEFAULT false)
RETURNS timestamp with time zone
LANGUAGE c
PARALLEL SAFE STRICT
AS '$libdir/pg_stat_statements', 'pg_stat_statements_reset_1_11';

CREATE OR REPLACE FUNCTION public.validate_jwt_format(token text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $function$
BEGIN
  RETURN token ~ '^[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*$';
END;
$function$;

CREATE OR REPLACE FUNCTION public.validate_store_for_login(store_code_param text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_store_id UUID;
  v_is_active BOOLEAN;
  v_message TEXT;
  v_user_id UUID;
  result JSON;
BEGIN
  -- 1. Get user_id from the session
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No authenticated user found.';
  END IF;

  -- 2. Find the store by its code
  SELECT id, is_active INTO v_store_id, v_is_active
  FROM public.stores
  WHERE store_code = store_code_param;

  -- 3. Check if the store exists
  IF v_store_id IS NULL THEN
    result := json_build_object(
      'is_valid', false,
      'message', 'Mã cửa hàng không tồn tại'
    );
    RETURN result;
  END IF;

  -- 4. Check if the store is active
  IF NOT v_is_active THEN
    result := json_build_object(
      'is_valid', false,
      'message', 'Cửa hàng này đã bị khoá'
    );
    RETURN result;
  END IF;

  -- 5. Check if the user is associated with this store
  IF NOT EXISTS (
    SELECT 1
    FROM public.user_profiles
    WHERE user_profiles.id = v_user_id AND user_profiles.store_id = v_store_id
  ) THEN
    result := json_build_object(
      'is_valid', false,
      'message', 'Bạn không có quyền truy cập vào cửa hàng này'
    );
    RETURN result;
  END IF;

  -- 6. All checks passed
  result := json_build_object(
    'is_valid', true,
    'message', 'Xác thực thành công'
  );
  RETURN result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.verify_otp_code(target_email text, input_token text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  token_record RECORD;
BEGIN
  -- Find the latest valid token for the email
  SELECT * INTO token_record
  FROM password_reset_tokens
  WHERE email = target_email
    AND token = input_token
    AND expires_at > NOW()
    AND used_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    -- Mark the token as used
    UPDATE password_reset_tokens
    SET used_at = NOW()
    WHERE id = token_record.id;
    RETURN true;
  ELSE
    RETURN false;
  END IF;
END;
$function$;



