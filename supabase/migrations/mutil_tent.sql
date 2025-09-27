    -- =======================================================================
   ======
     -- MIGRATION: ADD STORE_ID TO ALL BUSINESS TABLES
     -- =======================================================================
   ======
     
     -- 1. Add store_id columns to existing tables
     ALTER TABLE products ADD COLUMN store_id UUID REFERENCES stores(id);
     ALTER TABLE customers ADD COLUMN store_id UUID REFERENCES stores(id);  
     ALTER TABLE transactions ADD COLUMN store_id UUID REFERENCES stores(id);
     ALTER TABLE product_batches ADD COLUMN store_id UUID REFERENCES 
   stores(id);
     ALTER TABLE seasonal_prices ADD COLUMN store_id UUID REFERENCES 
   stores(id);
     ALTER TABLE companies ADD COLUMN store_id UUID REFERENCES stores(id);
     ALTER TABLE purchase_orders ADD COLUMN store_id UUID REFERENCES 
   stores(id);
     
     -- 2. Create indexes for performance
     CREATE INDEX idx_products_store_id ON products(store_id);
     CREATE INDEX idx_customers_store_id ON customers(store_id);
     CREATE INDEX idx_transactions_store_id ON transactions(store_id);
     CREATE INDEX idx_companies_store_id ON companies(store_id);
     
     -- 3. Make store_id NOT NULL after data migration
     -- (Run after Step 1.2 data migration)
  ALTER TABLE products ALTER COLUMN store_id SET NOT NULL;
   ALTER TABLE customers ALTER COLUMN store_id SET NOT NULL;
   ALTER TABLE transactions ALTER COLUMN store_id SET NOT NULL;

   -- =======================================================================
   ======
     -- DATA MIGRATION: ASSIGN EXISTING DATA TO STORES
     -- =======================================================================
   ======
     
     -- Function to migrate existing data to first available store
     CREATE OR REPLACE FUNCTION migrate_existing_data_to_stores()
     RETURNS TEXT AS $$
     DECLARE
       default_store_id UUID;
       updated_count INTEGER;
     BEGIN
       -- Get first active store as default
       SELECT id INTO default_store_id FROM stores WHERE is_active = true LIMIT
    1;
       
       if default_store_id IS NULL THEN
         RETURN 'ERROR: No active stores found for migration';
       END IF;
     
       -- Migrate all existing data to default store
       UPDATE products SET store_id = default_store_id WHERE store_id IS NULL;
       GET DIAGNOSTICS updated_count = ROW_COUNT;
       
       UPDATE customers SET store_id = default_store_id WHERE store_id IS NULL;
       UPDATE transactions SET store_id = default_store_id WHERE store_id IS 
   NULL;
       UPDATE companies SET store_id = default_store_id WHERE store_id IS NULL;
       
       RETURN 'SUCCESS: Migrated ' || updated_count || ' products and related 
   data to store: ' || default_store_id;
     END;
     $$ LANGUAGE plpgsql;
     
     -- Execute migration
     SELECT migrate_existing_data_to_stores();



  -- =======================================================================
   ======
     -- RLS POLICIES: STORE-BASED DATA ISOLATION
     -- =======================================================================
   ======
     
     -- Enable RLS on all business tables
     ALTER TABLE products ENABLE ROW LEVEL SECURITY;
     ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
     ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
     ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
     ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
     
     -- Helper function to get current user's store_id
     CREATE OR REPLACE FUNCTION get_current_user_store_id()
     RETURNS UUID AS $$
     BEGIN
       RETURN (
         SELECT store_id 
         FROM user_profiles 
         WHERE id = auth.uid()::text 
         LIMIT 1
       );
     END;
     $$ LANGUAGE plpgsql SECURITY DEFINER;
     
     -- Products policies
     CREATE POLICY "Users can only see products from their store" ON products
       FOR SELECT USING (store_id = get_current_user_store_id());
     
     CREATE POLICY "Users can only insert products to their store" ON products
       FOR INSERT WITH CHECK (store_id = get_current_user_store_id());
     
     CREATE POLICY "Users can only update products from their store" ON 
   products
       FOR UPDATE USING (store_id = get_current_user_store_id());
     
     -- Customers policies  
     CREATE POLICY "Users can only see customers from their store" ON customers
       FOR SELECT USING (store_id = get_current_user_store_id());
     
     CREATE POLICY "Users can only insert customers to their store" ON 
   customers
       FOR INSERT WITH CHECK (store_id = get_current_user_store_id());
     
     -- Transactions policies
     CREATE POLICY "Users can only see transactions from their store" ON 
   transactions
       FOR SELECT USING (store_id = get_current_user_store_id());
     
     CREATE POLICY "Users can only insert transactions to their store" ON 
   transactions
       FOR INSERT WITH CHECK (store_id = get_current_user_store_id());
     
     -- Companies policies
     CREATE POLICY "Users can only see companies from their store" ON companies
       FOR SELECT USING (store_id = get_current_user_store_id());
     
     -- Purchase Orders policies  
     CREATE POLICY "Users can only see POs from their store" ON purchase_orders
       FOR SELECT USING (store_id = get_current_user_store_id());



  -- =======================================================================
   ======
     -- EMPLOYEE MANAGEMENT TABLES
     -- =======================================================================
   ======
     
     -- Employee invitations table
     CREATE TABLE employee_invitations (
       id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
       store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
       email TEXT NOT NULL,
       full_name TEXT NOT NULL,
       invited_by_user_id UUID NOT NULL REFERENCES auth.users(id),
       role TEXT NOT NULL CHECK (role IN ('OWNER', 'MANAGER', 'CASHIER', 
   'INVENTORY_STAFF')),
       phone TEXT,
       status TEXT NOT NULL CHECK (status IN ('PENDING', 'ACCEPTED', 'EXPIRED',
    'CANCELLED')) DEFAULT 'PENDING',
       invitation_token TEXT UNIQUE NOT NULL,
       expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
       accepted_at TIMESTAMP WITH TIME ZONE,
       created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
       updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
       
       -- Business constraints
       UNIQUE(store_id, email),
       CHECK (expires_at > created_at)
     );
     
     -- Indexes
     CREATE INDEX idx_employee_invitations_store_id ON 
   employee_invitations(store_id);
     CREATE INDEX idx_employee_invitations_token ON 
   employee_invitations(invitation_token);
     CREATE INDEX idx_employee_invitations_email ON 
   employee_invitations(email);
     CREATE INDEX idx_employee_invitations_status ON 
   employee_invitations(status);
     
     -- Auto-expire invitations function
     CREATE OR REPLACE FUNCTION auto_expire_invitations()
     RETURNS INTEGER AS $$
     DECLARE
       expired_count INTEGER;
     BEGIN
       UPDATE employee_invitations 
       SET status = 'EXPIRED', updated_at = NOW()
       WHERE status = 'PENDING' AND expires_at < NOW();
       
       GET DIAGNOSTICS expired_count = ROW_COUNT;
       RETURN expired_count;
     END;
     $$ LANGUAGE plpgsql;

