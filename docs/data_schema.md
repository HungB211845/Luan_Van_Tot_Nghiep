-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public._test_connection (
  id integer NOT NULL DEFAULT nextval('_test_connection_id_seq'::regclass),
  test_value text DEFAULT 'connected'::text,
  CONSTRAINT _test_connection_pkey PRIMARY KEY (id)
);
CREATE TABLE public.auth_audit_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  store_id uuid,
  event_type text NOT NULL,
  ip_address inet,
  user_agent text,
  device_info jsonb,
  metadata jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT auth_audit_log_pkey PRIMARY KEY (id),
  CONSTRAINT auth_audit_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT auth_audit_log_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id)
);
CREATE TABLE public.banned_substances (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  active_ingredient_name text NOT NULL UNIQUE,
  banned_date date NOT NULL,
  legal_document text,
  reason text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT banned_substances_pkey PRIMARY KEY (id)
);
CREATE TABLE public.companies (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  phone text,
  address text,
  contact_person text,
  note text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  store_id uuid NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT companies_pkey PRIMARY KEY (id),
  CONSTRAINT companies_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id)
);
CREATE TABLE public.customers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  phone text,
  address text,
  debt_limit numeric DEFAULT 0,
  interest_rate numeric DEFAULT 0.5,
  note text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  store_id uuid NOT NULL,
  CONSTRAINT customers_pkey PRIMARY KEY (id),
  CONSTRAINT customers_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id)
);
CREATE TABLE public.debt_adjustments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  debt_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  adjustment_amount numeric NOT NULL,
  adjustment_type text NOT NULL CHECK (adjustment_type = ANY (ARRAY['increase'::text, 'decrease'::text, 'write_off'::text])),
  reason text NOT NULL,
  previous_amount numeric NOT NULL,
  new_amount numeric NOT NULL,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT debt_adjustments_pkey PRIMARY KEY (id),
  CONSTRAINT debt_adjustments_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id),
  CONSTRAINT debt_adjustments_debt_id_fkey FOREIGN KEY (debt_id) REFERENCES public.debts(id),
  CONSTRAINT debt_adjustments_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id),
  CONSTRAINT debt_adjustments_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id)
);
CREATE TABLE public.debt_payments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  debt_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  amount numeric NOT NULL CHECK (amount > 0::numeric),
  payment_method text NOT NULL DEFAULT 'CASH'::text CHECK (payment_method = ANY (ARRAY['CASH'::text, 'BANK_TRANSFER'::text])),
  notes text,
  payment_date timestamp with time zone DEFAULT now(),
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT debt_payments_pkey PRIMARY KEY (id),
  CONSTRAINT debt_payments_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id),
  CONSTRAINT debt_payments_debt_id_fkey FOREIGN KEY (debt_id) REFERENCES public.debts(id),
  CONSTRAINT debt_payments_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id),
  CONSTRAINT debt_payments_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id)
);
CREATE TABLE public.debts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  transaction_id uuid,
  original_amount numeric NOT NULL CHECK (original_amount >= 0::numeric),
  paid_amount numeric NOT NULL DEFAULT 0 CHECK (paid_amount >= 0::numeric),
  remaining_amount numeric NOT NULL CHECK (remaining_amount >= 0::numeric),
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'partial'::text, 'paid'::text, 'overdue'::text, 'cancelled'::text])),
  due_date date,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT debts_pkey PRIMARY KEY (id),
  CONSTRAINT debts_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id),
  CONSTRAINT debts_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id),
  CONSTRAINT debts_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id)
);
CREATE TABLE public.employee_invitations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  email text NOT NULL,
  full_name text NOT NULL,
  invited_by_user_id uuid NOT NULL,
  role text NOT NULL CHECK (role = ANY (ARRAY['OWNER'::text, 'MANAGER'::text, 'CASHIER'::text, 'INVENTORY_STAFF'::text])),
  phone text,
  status text NOT NULL DEFAULT 'PENDING'::text CHECK (status = ANY (ARRAY['PENDING'::text, 'ACCEPTED'::text, 'EXPIRED'::text, 'CANCELLED'::text])),
  invitation_token text NOT NULL UNIQUE,
  expires_at timestamp with time zone NOT NULL,
  accepted_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT employee_invitations_pkey PRIMARY KEY (id),
  CONSTRAINT employee_invitations_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id),
  CONSTRAINT employee_invitations_invited_by_user_id_fkey FOREIGN KEY (invited_by_user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.enhanced_user_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  device_id text NOT NULL,
  device_name text,
  device_type text,
  jwt_format_version text DEFAULT 'v2'::text,
  refresh_token_hash text,
  created_at timestamp with time zone DEFAULT now(),
  last_accessed_at timestamp with time zone DEFAULT now(),
  expires_at timestamp with time zone DEFAULT (now() + '30 days'::interval),
  is_active boolean DEFAULT true,
  CONSTRAINT enhanced_user_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT enhanced_user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.inventory_adjustments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  batch_id uuid NOT NULL,
  quantity_change numeric NOT NULL,
  reason text NOT NULL,
  adjustment_type character varying DEFAULT 'manual'::character varying CHECK (adjustment_type::text = ANY (ARRAY['manual'::character varying, 'void_batch'::character varying, 'stock_correction'::character varying, 'damage'::character varying, 'theft'::character varying]::text[])),
  created_at timestamp with time zone DEFAULT now(),
  user_id_who_adjusted uuid,
  store_id uuid NOT NULL,
  notes text,
  CONSTRAINT inventory_adjustments_pkey PRIMARY KEY (id),
  CONSTRAINT inventory_adjustments_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.product_batches(id)
);
CREATE TABLE public.password_reset_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  email text NOT NULL,
  token text NOT NULL,
  token_type text DEFAULT 'PASSWORD_RESET'::text CHECK (token_type = ANY (ARRAY['PASSWORD_RESET'::text, 'EMAIL_VERIFICATION'::text, 'PHONE_VERIFICATION'::text])),
  expires_at timestamp with time zone NOT NULL,
  is_used boolean DEFAULT false,
  used_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (id)
);
CREATE TABLE public.performance_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  query_type text NOT NULL,
  execution_time_ms bigint NOT NULL,
  store_id uuid,
  user_id uuid,
  query_params jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT performance_logs_pkey PRIMARY KEY (id)
);
CREATE TABLE public.price_history (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  new_price numeric NOT NULL,
  old_price numeric,
  changed_at timestamp with time zone DEFAULT now(),
  user_id_who_changed uuid,
  store_id uuid NOT NULL,
  reason text DEFAULT 'Manual price update'::text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT price_history_pkey PRIMARY KEY (id),
  CONSTRAINT price_history_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id)
);
CREATE TABLE public.product_batches (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  batch_number text NOT NULL,
  quantity integer NOT NULL CHECK (quantity >= 0),
  cost_price numeric NOT NULL CHECK (cost_price >= 0::numeric),
  received_date date NOT NULL,
  expiry_date date,
  supplier_batch_id text,
  notes text,
  is_available boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  purchase_order_id uuid,
  supplier_id uuid,
  store_id uuid NOT NULL,
  sales_count integer DEFAULT 0,
  is_deleted boolean DEFAULT false,
  CONSTRAINT product_batches_pkey PRIMARY KEY (id),
  CONSTRAINT product_batches_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT product_batches_purchase_order_id_fkey FOREIGN KEY (purchase_order_id) REFERENCES public.purchase_orders(id),
  CONSTRAINT product_batches_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.companies(id),
  CONSTRAINT product_batches_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id)
);
CREATE TABLE public.product_prices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid,
  selling_price numeric NOT NULL,
  cost numeric NOT NULL,
  effective_date timestamp with time zone DEFAULT now(),
  is_active boolean DEFAULT true,
  reason text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT product_prices_pkey PRIMARY KEY (id)
);
CREATE TABLE public.products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  sku text UNIQUE,
  name text NOT NULL,
  category text NOT NULL CHECK (category = ANY (ARRAY['FERTILIZER'::text, 'PESTICIDE'::text, 'SEED'::text])),
  company_id uuid,
  attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active boolean DEFAULT true,
  is_banned boolean DEFAULT false,
  image_url text,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  npk_ratio text DEFAULT 
CASE
    WHEN (category = 'FERTILIZER'::text) THEN (attributes ->> 'npk_ratio'::text)
    ELSE NULL::text
END,
  active_ingredient text DEFAULT 
CASE
    WHEN (category = 'PESTICIDE'::text) THEN (attributes ->> 'active_ingredient'::text)
    ELSE NULL::text
END,
  seed_strain text DEFAULT 
CASE
    WHEN (category = 'SEED'::text) THEN (attributes ->> 'strain'::text)
    ELSE NULL::text
END,
  search_vector tsvector,
  store_id uuid NOT NULL,
  min_stock_level integer DEFAULT 0,
  current_selling_price numeric NOT NULL DEFAULT 0,
  CONSTRAINT products_pkey PRIMARY KEY (id),
  CONSTRAINT products_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id),
  CONSTRAINT products_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id)
);
CREATE TABLE public.purchase_order_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  purchase_order_id uuid NOT NULL,
  product_id uuid NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_cost numeric NOT NULL CHECK (unit_cost >= 0::numeric),
  total_cost numeric DEFAULT ((quantity)::numeric * unit_cost),
  received_quantity integer DEFAULT 0 CHECK (received_quantity >= 0),
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  unit text,
  store_id uuid NOT NULL,
  CONSTRAINT purchase_order_items_pkey PRIMARY KEY (id),
  CONSTRAINT purchase_order_items_purchase_order_id_fkey FOREIGN KEY (purchase_order_id) REFERENCES public.purchase_orders(id),
  CONSTRAINT purchase_order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT purchase_order_items_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id)
);
CREATE TABLE public.purchase_orders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  supplier_id uuid NOT NULL,
  po_number text UNIQUE,
  order_date date DEFAULT CURRENT_DATE,
  expected_delivery_date date,
  delivery_date date,
  status text DEFAULT 'DRAFT'::text CHECK (status = ANY (ARRAY['DRAFT'::text, 'SENT'::text, 'CONFIRMED'::text, 'DELIVERED'::text, 'CANCELLED'::text])),
  subtotal numeric DEFAULT 0 CHECK (subtotal >= 0::numeric),
  tax_amount numeric DEFAULT 0,
  total_amount numeric DEFAULT 0 CHECK (total_amount >= 0::numeric),
  discount_amount numeric DEFAULT 0,
  payment_terms text,
  notes text,
  created_by text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  store_id uuid NOT NULL,
  CONSTRAINT purchase_orders_pkey PRIMARY KEY (id),
  CONSTRAINT purchase_orders_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.companies(id),
  CONSTRAINT purchase_orders_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id)
);
CREATE TABLE public.seasonal_prices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  selling_price numeric NOT NULL CHECK (selling_price >= 0::numeric),
  season_name text NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  is_active boolean DEFAULT true,
  markup_percentage numeric,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  store_id uuid NOT NULL,
  CONSTRAINT seasonal_prices_pkey PRIMARY KEY (id),
  CONSTRAINT seasonal_prices_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT seasonal_prices_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id)
);
CREATE TABLE public.stores (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_code text NOT NULL UNIQUE,
  store_name text NOT NULL,
  owner_name text NOT NULL,
  phone text,
  email text,
  address text,
  business_license text,
  tax_code text,
  subscription_type text DEFAULT 'free'::text CHECK (subscription_type IS NULL OR (lower(subscription_type) = ANY (ARRAY['free'::text, 'premium'::text]))),
  subscription_expires_at timestamp with time zone,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid NOT NULL DEFAULT auth.uid(),
  CONSTRAINT stores_pkey PRIMARY KEY (id)
);
CREATE TABLE public.transaction_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL,
  product_id uuid NOT NULL,
  batch_id uuid,
  quantity integer NOT NULL CHECK (quantity > 0),
  price_at_sale numeric NOT NULL CHECK (price_at_sale >= 0::numeric),
  sub_total numeric NOT NULL CHECK (sub_total >= 0::numeric),
  discount_amount numeric DEFAULT 0 CHECK (discount_amount >= 0::numeric),
  created_at timestamp with time zone DEFAULT now(),
  store_id uuid NOT NULL,
  CONSTRAINT transaction_items_pkey PRIMARY KEY (id),
  CONSTRAINT transaction_items_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id),
  CONSTRAINT transaction_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id),
  CONSTRAINT transaction_items_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.product_batches(id),
  CONSTRAINT transaction_items_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id)
);
CREATE TABLE public.transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_id uuid,
  total_amount numeric NOT NULL CHECK (total_amount >= 0::numeric),
  transaction_date timestamp with time zone DEFAULT now(),
  is_debt boolean DEFAULT false,
  payment_method text DEFAULT 'CASH'::text CHECK (payment_method = ANY (ARRAY['CASH'::text, 'BANK_TRANSFER'::text, 'DEBT'::text])),
  notes text,
  invoice_number text UNIQUE,
  created_by text,
  created_at timestamp with time zone DEFAULT now(),
  store_id uuid NOT NULL,
  surcharge_amount numeric NOT NULL DEFAULT 0,
  CONSTRAINT transactions_pkey PRIMARY KEY (id),
  CONSTRAINT transactions_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id),
  CONSTRAINT transactions_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id)
);
CREATE TABLE public.user_profiles (
  id uuid NOT NULL,
  store_id uuid NOT NULL,
  full_name text NOT NULL,
  phone text,
  avatar_url text,
  role text NOT NULL DEFAULT 'CASHIER'::text CHECK (role = ANY (ARRAY['OWNER'::text, 'MANAGER'::text, 'CASHIER'::text, 'INVENTORY_STAFF'::text])),
  permissions jsonb DEFAULT '{}'::jsonb,
  google_id text,
  facebook_id text,
  zalo_id text,
  is_active boolean DEFAULT true,
  last_login_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  biometric_enabled boolean DEFAULT false,
  quick_access_config jsonb,
  CONSTRAINT user_profiles_pkey PRIMARY KEY (id),
  CONSTRAINT user_profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id),
  CONSTRAINT user_profiles_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id)
);
CREATE TABLE public.user_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  device_id text NOT NULL,
  device_name text,
  device_type text CHECK (device_type = ANY (ARRAY['MOBILE'::text, 'TABLET'::text, 'DESKTOP'::text])),
  fcm_token text,
  is_biometric_enabled boolean DEFAULT false,
  last_accessed_at timestamp with time zone DEFAULT now(),
  expires_at timestamp with time zone DEFAULT (now() + '30 days'::interval),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);