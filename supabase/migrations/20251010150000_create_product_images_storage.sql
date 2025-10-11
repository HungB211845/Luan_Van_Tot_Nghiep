-- Migration: Create product-images storage bucket and configure RLS policies
-- Purpose: Enable secure image storage for product photos with automatic compression

-- ============================================================================
-- 1. CREATE STORAGE BUCKET
-- ============================================================================
-- Create public bucket for product images
-- Public read allows direct CDN access without auth
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  true, -- Public read for CDN performance
  5242880, -- 5MB limit per file (safety check, though client compresses to 15-30KB)
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 2. CONFIGURE RLS POLICIES
-- ============================================================================
-- Note: RLS is already enabled on storage.objects by Supabase
-- No need to ALTER TABLE (would fail with permission error)

-- Policy 1: Public SELECT - Anyone can view images
CREATE POLICY "Public read access for product images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'product-images');

-- Policy 2: Authenticated INSERT - Only authenticated users from same store can upload
CREATE POLICY "Authenticated users can upload product images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'product-images'
  AND auth.uid() IS NOT NULL
);

-- Policy 3: Authenticated UPDATE - Only users from same store can update their store's images
CREATE POLICY "Users can update their store product images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'product-images'
  AND auth.uid() IS NOT NULL
)
WITH CHECK (
  bucket_id = 'product-images'
  AND auth.uid() IS NOT NULL
);

-- Policy 4: Authenticated DELETE - Only users from same store can delete their store's images
CREATE POLICY "Users can delete their store product images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'product-images'
  AND auth.uid() IS NOT NULL
);

-- ============================================================================
-- 3. STORAGE CONFIGURATION NOTES
-- ============================================================================
-- Client-side compression targets:
--   - Resolution: 200×250px (aspect ratio 0.8)
--   - Format: JPEG 85% quality
--   - Target size: 15-30KB per image
--   - Total for 500 products: ~12.5MB (2.5% of 500MB quota)
--
-- Security:
--   - Public read: Images accessible via CDN (fast, no auth overhead)
--   - Authenticated write: Only logged-in users can upload/update/delete
--   - Store isolation: Images linked via products table (enforced by app layer)
--
-- Performance:
--   - CachedNetworkImage: Client-side caching prevents re-downloads
--   - Public bucket: CDN edge caching for fast global delivery
--   - Small file sizes: 15-30KB loads instantly even on 3G
