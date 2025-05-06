import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cache for generated PDF thumbnails to avoid regeneration within the same session.
/// Key: Unique identifier for the message/file (e.g., message ID or media URL)
/// Value: Uint8List of the generated PNG thumbnail
final pdfThumbnailCacheProvider = StateProvider<Map<String, Uint8List>>((ref) {
  return {}; // Start with an empty cache
}); 