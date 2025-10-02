-- Add quick_access_config column to user_profiles table
-- This stores user's customized quick access shortcuts as JSON array of IDs

ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS quick_access_config jsonb DEFAULT NULL;

-- Add comment for documentation
COMMENT ON COLUMN user_profiles.quick_access_config IS 'Array of quick access item IDs configured by user (max 6 items)';

-- Example: ['purchase_orders', 'reports', 'customers', 'debts']
