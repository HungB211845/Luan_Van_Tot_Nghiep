-- =============================================================================
-- MIGRATION: Add Biometric Authentication Support
-- Date: 2025-09-30
-- Description: Add biometric_enabled column to user_profiles table
-- =============================================================================

-- Add biometric_enabled column to user_profiles table
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS biometric_enabled BOOLEAN DEFAULT false;

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_biometric_enabled
ON user_profiles (biometric_enabled) WHERE biometric_enabled = true;

-- Update column comment for documentation
COMMENT ON COLUMN user_profiles.biometric_enabled
IS 'Indicates whether user has enabled biometric authentication (Face ID/Touch ID)';

-- Verify the change
SELECT 'biometric_enabled column added to user_profiles' as status;

-- Show table structure to confirm
\d user_profiles;