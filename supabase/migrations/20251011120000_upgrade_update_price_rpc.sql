DROP FUNCTION IF EXISTS public.update_product_selling_price(uuid, numeric, text);

CREATE OR REPLACE FUNCTION public.update_product_selling_price(
  p_product_id UUID,
  p_new_price NUMERIC,
  p_reason TEXT
)
RETURNS void -- Vẫn là void, vì Dart không cần nhận lại gì
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_store_id uuid;
    v_old_price numeric;
    v_current_user_id uuid;
    v_default_unit RECORD; -- Biến để giữ thông tin đơn vị mặc định
BEGIN
    -- BƯỚC 1: XÁC THỰC USER VÀ STORE (Code của mày - Giữ nguyên)
    v_current_user_id := auth.uid();
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated';
    END IF;

    SELECT store_id INTO v_current_store_id
    FROM public.user_profiles
    WHERE id = v_current_user_id;

    IF v_current_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    -- BƯỚC 2: LẤY GIÁ CŨ VÀ GHI LỊCH SỬ (Code của mày - Giữ nguyên)
    SELECT current_selling_price INTO v_old_price
    FROM public.products
    WHERE id = p_product_id AND store_id = v_current_store_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found or access denied';
    END IF;

    INSERT INTO public.price_history(
        product_id, new_price, old_price,
        changed_by, reason, store_id
    ) VALUES (
        p_product_id, p_new_price, v_old_price,
        v_current_user_id, p_reason, v_current_store_id
    );

    -- BƯỚC 3: CẬP NHẬT GIÁ BÁN CHÍNH (Code của mày - Giữ nguyên)
    UPDATE public.products
    SET current_selling_price = p_new_price, updated_at = NOW()
    WHERE id = p_product_id AND store_id = v_current_store_id;

    -- BƯỚC 4: 🔥 TỰ ĐỘNG TÍNH TOÁN VÀ ĐỒNG BỘ GIÁ CHO CÁC ĐƠN VỊ TÍNH (PHẦN THÊM VÀO)
    -- Lấy đơn vị mặc định (ví dụ: Bao) để làm cơ sở tính toán
    SELECT id, conversion_factor INTO v_default_unit
    FROM public.product_units
    WHERE product_id = p_product_id 
      AND store_id = v_current_store_id
      AND is_default_selling_unit = true
    LIMIT 1;

    -- Nếu tìm thấy đơn vị mặc định và hệ số quy đổi của nó hợp lệ
    IF v_default_unit IS NOT NULL AND v_default_unit.conversion_factor > 0 THEN
        -- Cập nhật giá cho TẤT CẢ các unit của sản phẩm này trong CÙNG MỘT LỆNH UPDATE
        UPDATE public.product_units
        SET 
            -- Giá của mỗi unit = (Giá mới của Bao / Hệ số của Bao) * Hệ số của unit hiện tại
            -- Ví dụ: (550.000 / 50) * 1 = 11.000 cho unit 'kg'
            -- Ví dụ: (550.000 / 50) * 50 = 550.000 cho unit 'Bao'
            unit_price = (p_new_price / v_default_unit.conversion_factor) * conversion_factor,
            updated_at = NOW()
        WHERE product_id = p_product_id AND store_id = v_current_store_id;
    END IF;

END;
$$;