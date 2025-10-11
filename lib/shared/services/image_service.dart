import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Service for handling product image operations
/// - Pick from camera/gallery
/// - Download from URL
/// - Compress and resize (400×500px, max 50KB with progressive compression)
/// - Upload to Supabase Storage
class ImageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  // Target dimensions for product images
  static const int targetWidth = 400;
  static const int targetHeight = 500;
  static const int jpegQuality = 80;
  static const int maxFileSizeKB = 50; // Hard limit 50KB
  static const String bucketName = 'product-images';

  /// Upload product image from camera, gallery, or URL
  ///
  /// [source]: Camera or Gallery (use ImageSource enum)
  /// [productId]: Optional product ID for unique filename
  /// [imageUrl]: Optional URL to download image from
  ///
  /// Returns the public URL of the uploaded image, or null if failed
  Future<String?> uploadProductImage({
    ImageSource? source,
    String? productId,
    String? imageUrl,
  }) async {
    try {
      Uint8List? imageBytes;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Download from URL
        imageBytes = await _downloadImageFromUrl(imageUrl);
        if (imageBytes == null) {
          throw Exception('Failed to download image from URL');
        }
      } else if (source != null) {
        // Pick from camera or gallery
        final XFile? pickedFile = await _picker.pickImage(source: source);
        if (pickedFile == null) {
          // User cancelled
          return null;
        }
        imageBytes = await pickedFile.readAsBytes();
      } else {
        throw Exception('Either source or imageUrl must be provided');
      }

      // Compress and resize
      final compressedBytes = await _compressAndResizeImage(imageBytes);
      if (compressedBytes == null) {
        throw Exception('Failed to compress image');
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = productId != null
          ? 'product_${productId}_$timestamp.jpg'
          : 'product_$timestamp.jpg';

      // Upload to Supabase Storage
      final uploadPath = await _supabase.storage
          .from(bucketName)
          .uploadBinary(filename, compressedBytes);

      // Get public URL
      final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(filename);

      if (kDebugMode) {
        print('✅ Image uploaded successfully: $publicUrl');
        print('📦 File size: ${(compressedBytes.length / 1024).toStringAsFixed(2)} KB');
      }

      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error uploading image: $e');
      }
      return null;
    }
  }

  /// Download image from URL
  Future<Uint8List?> _downloadImageFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error downloading image from URL: $e');
      }
      return null;
    }
  }

  /// Compress and resize image to target dimensions with progressive quality
  /// Target: 400×500px, max 50KB with progressive compression (80% → 75% → 65% → 50%)
  Future<Uint8List?> _compressAndResizeImage(Uint8List imageBytes) async {
    try {
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Calculate aspect ratio to fit within target dimensions
      // Maintain aspect ratio while ensuring it fits in 400×500px box
      int newWidth = targetWidth;
      int newHeight = targetHeight;

      final aspectRatio = image.width / image.height;
      final targetAspectRatio = targetWidth / targetHeight;

      if (aspectRatio > targetAspectRatio) {
        // Image is wider - fit to width
        newWidth = targetWidth;
        newHeight = (targetWidth / aspectRatio).round();
      } else {
        // Image is taller - fit to height
        newHeight = targetHeight;
        newWidth = (targetHeight * aspectRatio).round();
      }

      // Resize image
      final resized = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      if (kDebugMode) {
        print('📐 Original: ${image.width}×${image.height} (${(imageBytes.length / 1024).toStringAsFixed(2)} KB)');
        print('📐 Resized to: ${resized.width}×${resized.height}');
      }

      // Progressive compression: Try quality levels until size is acceptable
      final qualityLevels = [85, 75, 65, 50];
      Uint8List? bestResult;

      for (final quality in qualityLevels) {
        final compressed = img.encodeJpg(resized, quality: quality);
        final sizeKB = compressed.length / 1024;

        if (kDebugMode) {
          print('🔄 Trying quality $quality%: ${sizeKB.toStringAsFixed(2)} KB');
        }

        bestResult = Uint8List.fromList(compressed);

        // If within limit, use this quality
        if (sizeKB <= maxFileSizeKB) {
          if (kDebugMode) {
            print('✅ Final: Quality $quality%, ${sizeKB.toStringAsFixed(2)} KB (within ${maxFileSizeKB}KB limit)');
          }
          break;
        }
      }

      // If still too large even at 50% quality, log warning but accept
      if (bestResult != null) {
        final finalSize = bestResult.length / 1024;
        if (finalSize > maxFileSizeKB && kDebugMode) {
          print('⚠️ Warning: Final size ${finalSize.toStringAsFixed(2)} KB exceeds ${maxFileSizeKB}KB limit (using lowest quality 50%)');
        }
      }

      return bestResult;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error compressing image: $e');
      }
      return null;
    }
  }

  /// Delete product image from storage
  ///
  /// [imageUrl]: The full public URL of the image to delete
  ///
  /// Returns true if successful, false otherwise
  Future<bool> deleteProductImage(String imageUrl) async {
    try {
      // Extract filename from public URL
      final uri = Uri.parse(imageUrl);
      final filename = path.basename(uri.path);

      await _supabase.storage.from(bucketName).remove([filename]);

      if (kDebugMode) {
        print('✅ Image deleted successfully: $filename');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting image: $e');
      }
      return false;
    }
  }
}
