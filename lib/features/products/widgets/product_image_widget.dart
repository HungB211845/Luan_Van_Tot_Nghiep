import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Size presets for product images based on context
enum ProductImageSize {
  list(50),    // List view - compact
  grid(80),    // Grid view - medium
  detail(200); // Detail view - large

  final double height;
  const ProductImageSize(this.height);
}

/// Reusable widget for displaying product images with caching
///
/// Features:
/// - Automatic caching via CachedNetworkImage
/// - Responsive sizing based on context
/// - Placeholder during loading
/// - Error fallback with icon
/// - AspectRatio maintained to prevent overflow
class ProductImageWidget extends StatelessWidget {
  final String? imageUrl;
  final ProductImageSize size;
  final double? width;
  final BoxFit fit;

  const ProductImageWidget({
    Key? key,
    required this.imageUrl,
    this.size = ProductImageSize.grid,
    this.width,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If no image URL, show placeholder icon
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    return SizedBox(
      width: width,
      height: size.height,
      child: AspectRatio(
        aspectRatio: 1.0, // Maintain square aspect ratio
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: fit,
            placeholder: (context, url) => _buildPlaceholder(isLoading: true),
            errorWidget: (context, url, error) => _buildPlaceholder(isError: true),
          ),
        ),
      ),
    );
  }

  /// Build placeholder widget for empty, loading, or error states
  Widget _buildPlaceholder({bool isLoading = false, bool isError = false}) {
    return Container(
      width: width,
      height: size.height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Center(
        child: isLoading
            ? SizedBox(
                width: size.height * 0.3,
                height: size.height * 0.3,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                isError ? Icons.broken_image : Icons.inventory_2_outlined,
                color: Colors.grey[400],
                size: size.height * 0.4,
              ),
      ),
    );
  }
}
