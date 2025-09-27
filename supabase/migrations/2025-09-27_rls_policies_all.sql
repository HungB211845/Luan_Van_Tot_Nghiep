-- RLS policies for multi-tenant isolation across core business tables
-- Assumes a helper function get_current_user_store_id() exists and returns uuid
-- Run this after tables are created and store_id columns exist on all target tables

--- Đảm bảo đã có hàm get_current_user_store_id() sẵn trong DB.

create or replace function public.get_current_user_store_id()
returns uuid
language sql
stable
as $$
  select (auth.jwt() ->> 'store_id')::uuid;
$$;

BEGIN;

-- Helper: Indexes for store_id filtering performance
CREATE INDEX IF NOT EXISTS idx_products_store_id ON public.products (store_id);
CREATE INDEX IF NOT EXISTS idx_companies_store_id ON public.companies (store_id);
CREATE INDEX IF NOT EXISTS idx_customers_store_id ON public.customers (store_id);
CREATE INDEX IF NOT EXISTS idx_transactions_store_id ON public.transactions (store_id);
CREATE INDEX IF NOT EXISTS idx_transaction_items_store_id ON public.transaction_items (store_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_store_id ON public.purchase_orders (store_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_store_id ON public.purchase_order_items (store_id);
CREATE INDEX IF NOT EXISTS idx_product_batches_store_id ON public.product_batches (store_id);
CREATE INDEX IF NOT EXISTS idx_seasonal_prices_store_id ON public.seasonal_prices (store_id);

-- PRODUCTS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS products_select_own ON public.products;
CREATE POLICY products_select_own
ON public.products FOR SELECT
TO authenticated
USING (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS products_insert_own ON public.products;
CREATE POLICY products_insert_own
ON public.products FOR INSERT
TO authenticated
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS products_update_own ON public.products;
CREATE POLICY products_update_own
ON public.products FOR UPDATE
TO authenticated
USING (store_id = get_current_user_store_id())
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS products_delete_own ON public.products;
CREATE POLICY products_delete_own
ON public.products FOR DELETE
TO authenticated
USING (store_id = get_current_user_store_id());

-- COMPANIES
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS companies_select_own ON public.companies;
CREATE POLICY companies_select_own
ON public.companies FOR SELECT
TO authenticated
USING (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS companies_insert_own ON public.companies;
CREATE POLICY companies_insert_own
ON public.companies FOR INSERT
TO authenticated
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS companies_update_own ON public.companies;
CREATE POLICY companies_update_own
ON public.companies FOR UPDATE
TO authenticated
USING (store_id = get_current_user_store_id())
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS companies_delete_own ON public.companies;
CREATE POLICY companies_delete_own
ON public.companies FOR DELETE
TO authenticated
USING (store_id = get_current_user_store_id());

-- CUSTOMERS
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS customers_select_own ON public.customers;
CREATE POLICY customers_select_own
ON public.customers FOR SELECT
TO authenticated
USING (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS customers_insert_own ON public.customers;
CREATE POLICY customers_insert_own
ON public.customers FOR INSERT
TO authenticated
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS customers_update_own ON public.customers;
CREATE POLICY customers_update_own
ON public.customers FOR UPDATE
TO authenticated
USING (store_id = get_current_user_store_id())
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS customers_delete_own ON public.customers;
CREATE POLICY customers_delete_own
ON public.customers FOR DELETE
TO authenticated
USING (store_id = get_current_user_store_id());

-- TRANSACTIONS
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS transactions_select_own ON public.transactions;
CREATE POLICY transactions_select_own
ON public.transactions FOR SELECT
TO authenticated
USING (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS transactions_insert_own ON public.transactions;
CREATE POLICY transactions_insert_own
ON public.transactions FOR INSERT
TO authenticated
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS transactions_update_own ON public.transactions;
CREATE POLICY transactions_update_own
ON public.transactions FOR UPDATE
TO authenticated
USING (store_id = get_current_user_store_id())
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS transactions_delete_own ON public.transactions;
CREATE POLICY transactions_delete_own
ON public.transactions FOR DELETE
TO authenticated
USING (store_id = get_current_user_store_id());

-- TRANSACTION ITEMS
ALTER TABLE public.transaction_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS transaction_items_select_own ON public.transaction_items;
CREATE POLICY transaction_items_select_own
ON public.transaction_items FOR SELECT
TO authenticated
USING (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS transaction_items_insert_own ON public.transaction_items;
CREATE POLICY transaction_items_insert_own
ON public.transaction_items FOR INSERT
TO authenticated
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS transaction_items_update_own ON public.transaction_items;
CREATE POLICY transaction_items_update_own
ON public.transaction_items FOR UPDATE
TO authenticated
USING (store_id = get_current_user_store_id())
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS transaction_items_delete_own ON public.transaction_items;
CREATE POLICY transaction_items_delete_own
ON public.transaction_items FOR DELETE
TO authenticated
USING (store_id = get_current_user_store_id());

-- PURCHASE ORDERS
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS purchase_orders_select_own ON public.purchase_orders;
CREATE POLICY purchase_orders_select_own
ON public.purchase_orders FOR SELECT
TO authenticated
USING (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS purchase_orders_insert_own ON public.purchase_orders;
CREATE POLICY purchase_orders_insert_own
ON public.purchase_orders FOR INSERT
TO authenticated
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS purchase_orders_update_own ON public.purchase_orders;
CREATE POLICY purchase_orders_update_own
ON public.purchase_orders FOR UPDATE
TO authenticated
USING (store_id = get_current_user_store_id())
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS purchase_orders_delete_own ON public.purchase_orders;
CREATE POLICY purchase_orders_delete_own
ON public.purchase_orders FOR DELETE
TO authenticated
USING (store_id = get_current_user_store_id());

-- PURCHASE ORDER ITEMS
ALTER TABLE public.purchase_order_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS purchase_order_items_select_own ON public.purchase_order_items;
CREATE POLICY purchase_order_items_select_own
ON public.purchase_order_items FOR SELECT
TO authenticated
USING (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS purchase_order_items_insert_own ON public.purchase_order_items;
CREATE POLICY purchase_order_items_insert_own
ON public.purchase_order_items FOR INSERT
TO authenticated
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS purchase_order_items_update_own ON public.purchase_order_items;
CREATE POLICY purchase_order_items_update_own
ON public.purchase_order_items FOR UPDATE
TO authenticated
USING (store_id = get_current_user_store_id())
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS purchase_order_items_delete_own ON public.purchase_order_items;
CREATE POLICY purchase_order_items_delete_own
ON public.purchase_order_items FOR DELETE
TO authenticated
USING (store_id = get_current_user_store_id());

-- PRODUCT BATCHES
ALTER TABLE public.product_batches ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS product_batches_select_own ON public.product_batches;
CREATE POLICY product_batches_select_own
ON public.product_batches FOR SELECT
TO authenticated
USING (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS product_batches_insert_own ON public.product_batches;
CREATE POLICY product_batches_insert_own
ON public.product_batches FOR INSERT
TO authenticated
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS product_batches_update_own ON public.product_batches;
CREATE POLICY product_batches_update_own
ON public.product_batches FOR UPDATE
TO authenticated
USING (store_id = get_current_user_store_id())
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS product_batches_delete_own ON public.product_batches;
CREATE POLICY product_batches_delete_own
ON public.product_batches FOR DELETE
TO authenticated
USING (store_id = get_current_user_store_id());

-- SEASONAL PRICES
ALTER TABLE public.seasonal_prices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS seasonal_prices_select_own ON public.seasonal_prices;
CREATE POLICY seasonal_prices_select_own
ON public.seasonal_prices FOR SELECT
TO authenticated
USING (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS seasonal_prices_insert_own ON public.seasonal_prices;
CREATE POLICY seasonal_prices_insert_own
ON public.seasonal_prices FOR INSERT
TO authenticated
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS seasonal_prices_update_own ON public.seasonal_prices;
CREATE POLICY seasonal_prices_update_own
ON public.seasonal_prices FOR UPDATE
TO authenticated
USING (store_id = get_current_user_store_id())
WITH CHECK (store_id = get_current_user_store_id());

DROP POLICY IF EXISTS seasonal_prices_delete_own ON public.seasonal_prices;
CREATE POLICY seasonal_prices_delete_own
ON public.seasonal_prices FOR DELETE
TO authenticated
USING (store_id = get_current_user_store_id());

COMMIT;


--- tạo helper function trong Supabas

 CREATE OR REPLACE FUNCTION get_current_user_store_id()
  RETURNS uuid
  LANGUAGE sql
  SECURITY DEFINER
  AS $$
    SELECT (auth.jwt() -> 'app_metadata' ->> 'store_id')::uuid;
  $$; 