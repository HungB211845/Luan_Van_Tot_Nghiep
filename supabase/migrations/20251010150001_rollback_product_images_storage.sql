-- Rollback Migration: Remove product-images storage bucket
-- Purpose: Clean rollback in case of issues or testing
--
-- NOTE: RLS policies on storage.objects are system-managed by Supabase.
-- Deleting the bucket will automatically cleanup associated policies.
-- If you need to manually remove policies, use Supabase Dashboard:
-- Storage > Policies > Delete policies for 'product-images' bucket

-- ============================================================================
-- 1. DELETE STORAGE BUCKET
-- ============================================================================
-- Delete all objects in the bucket first (required before deleting bucket)
-- WARNING: This will permanently delete all product images!
DELETE FROM storage.objects WHERE bucket_id = 'product-images';

-- Delete the bucket itself (this also removes associated RLS policies)
DELETE FROM storage.buckets WHERE id = 'product-images';

-- ============================================================================
-- 2. CLEANUP DATABASE REFERENCES (OPTIONAL)
-- ============================================================================
-- Uncomment the line below if you want to clear broken image URLs from products table
-- UPDATE products SET image_url = NULL WHERE image_url LIKE '%product-images%';

-- ============================================================================
-- 3. ROLLBACK NOTES
-- ============================================================================
-- WARNING: This rollback will:
--   1. Delete ALL product images from storage permanently
--   2. Remove the product-images bucket
--   3. Associated RLS policies are automatically cleaned up by Supabase
--
-- Product records in the database will NOT be affected automatically.
-- The image_url column will still contain URLs, but they will return 404.
--
-- To manually remove policies via Supabase Dashboard:
--   1. Go to Storage > Policies
--   2. Find policies for 'product-images' bucket
--   3. Click Delete on each policy
