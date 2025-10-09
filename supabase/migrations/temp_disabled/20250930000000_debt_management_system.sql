-- =============================================================================
-- DEBT MANAGEMENT SYSTEM - MULTI-TENANT WITH RLS
-- Migration created: 2025-09-30
-- =============================================================================

-- =============================================================================
-- 1. CREATE TABLES
-- =============================================================================

-- 1.1 debts table - Main debt records
CREATE TABLE IF NOT EXISTS debts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,

    original_amount DECIMAL(15,2) NOT NULL CHECK (original_amount >= 0),
    paid_amount DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
    remaining_amount DECIMAL(15,2) NOT NULL CHECK (remaining_amount >= 0),

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'partial', 'paid', 'overdue', 'cancelled')),

    due_date DATE,
    notes TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Constraints
    CONSTRAINT remaining_amount_valid
        CHECK (remaining_amount = original_amount - paid_amount),
    CONSTRAINT paid_amount_not_exceed_original
        CHECK (paid_amount <= original_amount)
);

-- 1.2 debt_payments table - Payment records
CREATE TABLE IF NOT EXISTS debt_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    debt_id UUID NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,

    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    payment_method TEXT NOT NULL DEFAULT 'CASH'
        CHECK (payment_method IN ('CASH', 'BANK_TRANSFER')),

    notes TEXT,
    payment_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1.3 debt_adjustments table - Manual adjustments with audit trail
CREATE TABLE IF NOT EXISTS debt_adjustments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    debt_id UUID NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,

    adjustment_amount DECIMAL(15,2) NOT NULL,
    adjustment_type TEXT NOT NULL CHECK (adjustment_type IN ('increase', 'decrease', 'write_off')),
    reason TEXT NOT NULL,

    previous_amount DECIMAL(15,2) NOT NULL,
    new_amount DECIMAL(15,2) NOT NULL,

    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- 2. CREATE INDEXES FOR PERFORMANCE
-- =============================================================================

-- debts table indexes
CREATE INDEX idx_debts_store_id ON debts(store_id);
CREATE INDEX idx_debts_customer_id ON debts(customer_id);
CREATE INDEX idx_debts_transaction_id ON debts(transaction_id);
CREATE INDEX idx_debts_status ON debts(status);
CREATE INDEX idx_debts_store_customer ON debts(store_id, customer_id);
CREATE INDEX idx_debts_created_at ON debts(created_at DESC);

-- debt_payments table indexes
CREATE INDEX idx_debt_payments_store_id ON debt_payments(store_id);
CREATE INDEX idx_debt_payments_debt_id ON debt_payments(debt_id);
CREATE INDEX idx_debt_payments_customer_id ON debt_payments(customer_id);
CREATE INDEX idx_debt_payments_payment_date ON debt_payments(payment_date DESC);

-- debt_adjustments table indexes
CREATE INDEX idx_debt_adjustments_store_id ON debt_adjustments(store_id);
CREATE INDEX idx_debt_adjustments_debt_id ON debt_adjustments(debt_id);
CREATE INDEX idx_debt_adjustments_customer_id ON debt_adjustments(customer_id);

-- =============================================================================
-- 3. ENABLE ROW LEVEL SECURITY (RLS)
-- =============================================================================

ALTER TABLE debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE debt_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE debt_adjustments ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 4. CREATE RLS POLICIES
-- =============================================================================

-- 4.1 debts table policies
CREATE POLICY "Users can view debts in their store"
    ON debts FOR SELECT
    TO authenticated
    USING (
        store_id IN (
            SELECT store_id
            FROM user_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "Users can create debts in their store"
    ON debts FOR INSERT
    TO authenticated
    WITH CHECK (
        store_id IN (
            SELECT store_id
            FROM user_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "Users can update debts in their store"
    ON debts FOR UPDATE
    TO authenticated
    USING (
        store_id IN (
            SELECT store_id
            FROM user_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

-- 4.2 debt_payments table policies
CREATE POLICY "Users can view debt payments in their store"
    ON debt_payments FOR SELECT
    TO authenticated
    USING (
        store_id IN (
            SELECT store_id
            FROM user_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "Users can create debt payments in their store"
    ON debt_payments FOR INSERT
    TO authenticated
    WITH CHECK (
        store_id IN (
            SELECT store_id
            FROM user_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

-- 4.3 debt_adjustments table policies
CREATE POLICY "Users can view debt adjustments in their store"
    ON debt_adjustments FOR SELECT
    TO authenticated
    USING (
        store_id IN (
            SELECT store_id
            FROM user_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "Users can create debt adjustments in their store"
    ON debt_adjustments FOR INSERT
    TO authenticated
    WITH CHECK (
        store_id IN (
            SELECT store_id
            FROM user_profiles
            WHERE id = auth.uid() AND is_active = true
        )
    );

-- =============================================================================
-- 5. CREATE RPC FUNCTIONS
-- =============================================================================

-- 5.1 Create credit sale (atomic debt creation from transaction)
CREATE OR REPLACE FUNCTION create_credit_sale(
    p_store_id UUID,
    p_customer_id UUID,
    p_transaction_id UUID,
    p_amount DECIMAL(15,2),
    p_due_date DATE DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

-- 5.2 Process customer payment (with overpayment prevention)
CREATE OR REPLACE FUNCTION process_customer_payment(
    p_store_id UUID,
    p_customer_id UUID,
    p_payment_amount DECIMAL(15,2),
    p_payment_method TEXT DEFAULT 'CASH',
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_store_id UUID;
    v_total_debt DECIMAL(15,2);
    v_remaining_payment DECIMAL(15,2);
    v_debt_record RECORD;
    v_payment_to_apply DECIMAL(15,2);
    v_payment_id UUID;
    v_payments_created INTEGER := 0;
    v_debts_updated INTEGER := 0;
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

    -- Validate payment amount
    IF p_payment_amount <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be greater than zero';
    END IF;

    -- Calculate total debt
    SELECT COALESCE(SUM(remaining_amount), 0) INTO v_total_debt
    FROM debts
    WHERE store_id = p_store_id
      AND customer_id = p_customer_id
      AND status IN ('pending', 'partial', 'overdue')
      AND remaining_amount > 0;

    -- **CRITICAL VALIDATION: Prevent overpayment**
    IF p_payment_amount > v_total_debt THEN
        RAISE EXCEPTION 'Số tiền trả (%) vượt quá tổng nợ (%). Vui lòng nhập lại.',
            p_payment_amount, v_total_debt;
    END IF;

    -- Distribute payment across debts (FIFO - oldest first)
    v_remaining_payment := p_payment_amount;

    FOR v_debt_record IN
        SELECT id, remaining_amount
        FROM debts
        WHERE store_id = p_store_id
          AND customer_id = p_customer_id
          AND status IN ('pending', 'partial', 'overdue')
          AND remaining_amount > 0
        ORDER BY created_at ASC
    LOOP
        -- Calculate payment to apply to this debt
        v_payment_to_apply := LEAST(v_remaining_payment, v_debt_record.remaining_amount);

        -- Create payment record
        INSERT INTO debt_payments (
            store_id,
            debt_id,
            customer_id,
            amount,
            payment_method,
            notes,
            created_by
        ) VALUES (
            p_store_id,
            v_debt_record.id,
            p_customer_id,
            v_payment_to_apply,
            p_payment_method,
            p_notes,
            auth.uid()
        )
        RETURNING id INTO v_payment_id;

        v_payments_created := v_payments_created + 1;

        -- Update debt record
        UPDATE debts
        SET
            paid_amount = paid_amount + v_payment_to_apply,
            remaining_amount = remaining_amount - v_payment_to_apply,
            status = CASE
                WHEN remaining_amount - v_payment_to_apply = 0 THEN 'paid'
                WHEN remaining_amount - v_payment_to_apply < original_amount THEN 'partial'
                ELSE status
            END,
            updated_at = NOW()
        WHERE id = v_debt_record.id;

        v_debts_updated := v_debts_updated + 1;

        -- Reduce remaining payment
        v_remaining_payment := v_remaining_payment - v_payment_to_apply;

        -- Exit if payment fully distributed
        IF v_remaining_payment <= 0 THEN
            EXIT;
        END IF;
    END LOOP;

    -- Return summary
    RETURN jsonb_build_object(
        'success', true,
        'payment_amount', p_payment_amount,
        'payments_created', v_payments_created,
        'debts_updated', v_debts_updated,
        'remaining_debt', v_total_debt - p_payment_amount
    );
END;
$$;

-- 5.3 Adjust debt amount (with validation)
CREATE OR REPLACE FUNCTION adjust_debt_amount(
    p_debt_id UUID,
    p_adjustment_amount DECIMAL(15,2),
    p_adjustment_type TEXT,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

-- 5.4 Calculate overdue interest (simple daily interest)
CREATE OR REPLACE FUNCTION calculate_overdue_interest(
    p_debt_id UUID,
    p_daily_interest_rate DECIMAL(5,4) DEFAULT 0.001
)
RETURNS DECIMAL(15,2)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

-- 5.5 Get customer debt summary
CREATE OR REPLACE FUNCTION get_customer_debt_summary(
    p_store_id UUID,
    p_customer_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

-- =============================================================================
-- 6. CREATE TRIGGERS
-- =============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_debts_updated_at
    BEFORE UPDATE ON debts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 7. GRANT PERMISSIONS
-- =============================================================================

-- Grant execute permissions on RPC functions
GRANT EXECUTE ON FUNCTION create_credit_sale TO authenticated;
GRANT EXECUTE ON FUNCTION process_customer_payment TO authenticated;
GRANT EXECUTE ON FUNCTION adjust_debt_amount TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_overdue_interest TO authenticated;
GRANT EXECUTE ON FUNCTION get_customer_debt_summary TO authenticated;

-- =============================================================================
-- 8. VERIFICATION & TESTING
-- =============================================================================

DO $$
DECLARE
    table_count INTEGER;
    policy_count INTEGER;
    function_count INTEGER;
BEGIN
    -- Count tables
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN ('debts', 'debt_payments', 'debt_adjustments');

    -- Count policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE tablename IN ('debts', 'debt_payments', 'debt_adjustments');

    -- Count functions
    SELECT COUNT(*) INTO function_count
    FROM pg_proc
    WHERE proname IN (
        'create_credit_sale',
        'process_customer_payment',
        'adjust_debt_amount',
        'calculate_overdue_interest',
        'get_customer_debt_summary'
    );

    RAISE NOTICE '==============================================';
    RAISE NOTICE 'DEBT MANAGEMENT SYSTEM - MIGRATION COMPLETE';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Tables created: %', table_count;
    RAISE NOTICE 'RLS policies created: %', policy_count;
    RAISE NOTICE 'RPC functions created: %', function_count;
    RAISE NOTICE '==============================================';

    IF table_count != 3 THEN
        RAISE WARNING 'Expected 3 tables, found %', table_count;
    END IF;

    IF function_count != 5 THEN
        RAISE WARNING 'Expected 5 functions, found %', function_count;
    END IF;
END $$;
