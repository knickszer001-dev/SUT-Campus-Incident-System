import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget สำหรับแสดงรูปจาก URL — รองรับทั้ง Web (Image.network) และ Mobile (CachedNetworkImage)
/// Web ไม่สามารถใช้ CachedNetworkImage ได้ดีเพราะ CORS issues
class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.broken_image, size: 32, color: Colors.grey));
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: (_, __) => const Center(
        child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 32, color: Colors.grey)),
    );
  }
}
