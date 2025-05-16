import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pdf_render/pdf_render.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/routes.dart';
import '../../../core/models/message_model.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../providers/ui_providers.dart';

/// A widget that displays a document message in a chat bubble
class DocumentMessage extends ConsumerStatefulWidget {
  final Message message;
  final BorderRadius borderRadius;
  final Color textColor;

  const DocumentMessage({
    super.key,
    required this.message,
    required this.borderRadius,
    required this.textColor,
  });

  @override
  ConsumerState<DocumentMessage> createState() => _DocumentMessageState();
}

class _DocumentMessageState extends ConsumerState<DocumentMessage> with AutomaticKeepAliveClientMixin {
  Uint8List? _pdfThumbnailBytes;
  bool _isLoadingThumbnail = false;
  bool _isPdf = false;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    
    // Check if the document is a PDF
    bool detectedPdf = false;
    if (widget.message.localFilePath != null && 
        widget.message.localFilePath!.toLowerCase().endsWith('.pdf')) {
      detectedPdf = true;
    } else if (widget.message.mediaUrl != null && 
               widget.message.mediaUrl!.toLowerCase().contains('.pdf')) {
      detectedPdf = true;
    } else if (widget.message.content.toLowerCase().endsWith('.pdf')) {
      detectedPdf = true;
    }
    
    if (detectedPdf) {
      _isPdf = true;
      _generatePdfThumbnail();
    }
  }
  
  Future<void> _generatePdfThumbnail() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingThumbnail = true;
    });
    
    Uint8List? finalImageBytes;
    PdfDocument? doc;
    try {
      // Determine source: network URL or local path
      if (widget.message.mediaUrl != null && widget.message.mediaUrl!.isNotEmpty) {
        AppLogger.d("[DocumentMessage] Generating PDF thumbnail from URL: ${widget.message.mediaUrl}");
        final url = Uri.parse(widget.message.mediaUrl!);
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final rawBytes = response.bodyBytes;
          doc = await PdfDocument.openData(rawBytes);
        } else {
          AppLogger.e("Error downloading PDF for thumbnail: Status code ${response.statusCode}");
        }
      } else if (widget.message.localFilePath != null) {
        AppLogger.d("[DocumentMessage] Generating PDF thumbnail from Path: ${widget.message.localFilePath}");
        doc = await PdfDocument.openFile(widget.message.localFilePath!);
      } else {
        AppLogger.d("[DocumentMessage] Cannot generate thumbnail: No valid source (URL or Path)");
      }
      
      // Render page and encode if document loaded
      if (doc != null && doc.pageCount >= 1) {
        final page = await doc.getPage(1);
        final targetWidth = (page.width * 1.5).toInt();
        final targetHeight = (page.height * 1.5).toInt();
        final PdfPageImage pageImage = await page.render(width: targetWidth, height: targetHeight);
        
        AppLogger.d("[DocumentMessage] PDF page rendered. Size: ${pageImage.width}x${pageImage.height}");
        
        // Use Completer to handle async callback
        final Completer<Uint8List?> pngCompleter = Completer<Uint8List?>();
        
        final int width = pageImage.width;
        final int height = pageImage.height;
        final Uint8List pixels = pageImage.pixels;
        final int rowBytes = width * 4;
        
        // Call decodeImageFromPixels with the callback
        ui.decodeImageFromPixels(
          pixels,
          width,
          height,
          ui.PixelFormat.rgba8888,
          (ui.Image renderedImage) async {
            try {
              // Encode ui.Image to PNG ByteData inside the callback
              final ByteData? byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);
              // Convert ByteData to Uint8List (final PNG bytes)
              if (byteData != null) {
                final encodedBytes = byteData.buffer.asUint8List();
                AppLogger.d("[DocumentMessage] Encoded thumbnail to PNG: ${encodedBytes.lengthInBytes} bytes");
                if (!pngCompleter.isCompleted) pngCompleter.complete(encodedBytes);
              } else {
                AppLogger.e("[DocumentMessage] Failed to encode rendered image to PNG.");
                if (!pngCompleter.isCompleted) pngCompleter.complete(null);
              }
            } catch (e) {
              AppLogger.e("[DocumentMessage] Error during PNG encoding: $e");
              if (!pngCompleter.isCompleted) pngCompleter.complete(null);
            }
          },
          rowBytes: rowBytes,
        );
        
        // Wait for the completer
        finalImageBytes = await pngCompleter.future;
      } else {
        AppLogger.d("[DocumentMessage] Document was null or had no pages.");
      }
    } catch (e) {
      AppLogger.e("Error generating or encoding PDF thumbnail: $e");
      finalImageBytes = null;
    }
    
    // Update state with the encoded PNG bytes
    if (mounted) {
      // Store in cache if bytes were generated
      if (finalImageBytes != null) {
        final cacheKey = widget.message.id;
        if (cacheKey.isNotEmpty) {
          ref.read(pdfThumbnailCacheProvider.notifier).update((state) {
            final newState = Map<String, Uint8List>.from(state);
            newState[cacheKey] = finalImageBytes!;
            return newState;
          });
          AppLogger.d("[DocumentMessage] Thumbnail cached for key: $cacheKey");
        }
      }
      // Update local state AFTER attempting cache write
      setState(() {
        _pdfThumbnailBytes = finalImageBytes;
        _isLoadingThumbnail = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    const double placeholderSize = 150.0;
    
    if (_isPdf) {
      // PDF document handling
      Widget pdfPreviewContent;
      final cacheKey = widget.message.id;
      final cachedThumbnails = ref.watch(pdfThumbnailCacheProvider);
      
      if (cacheKey.isNotEmpty && cachedThumbnails.containsKey(cacheKey)) {
        pdfPreviewContent = Image.memory(
          cachedThumbnails[cacheKey]!,
          fit: BoxFit.cover,
          width: placeholderSize,
          height: placeholderSize,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.white70)
          ),
        );
      } else if (_pdfThumbnailBytes == null && !_isLoadingThumbnail) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _generatePdfThumbnail();
          }
        });
        pdfPreviewContent = const Center(
          child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white70),
        );
      } else if (_isLoadingThumbnail) {
        pdfPreviewContent = const Center(
          child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white70),
        );
      } else if (_pdfThumbnailBytes != null) {
        pdfPreviewContent = Image.memory(
          _pdfThumbnailBytes!,
          fit: BoxFit.cover,
          width: placeholderSize,
          height: placeholderSize,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.white70)
          ),
        );
      } else {
        pdfPreviewContent = Center(
          child: Icon(Icons.picture_as_pdf_outlined, size: 40, color: Colors.grey[600]),
        );
      }
      
      return GestureDetector(
        onTap: () {
          HapticUtils.lightTap();
          final sourcePathOrUrl = widget.message.mediaUrl ?? widget.message.localFilePath;
          
          if (sourcePathOrUrl != null) {
            context.pushNamed(
              RouteNames.pdfViewer,
              extra: sourcePathOrUrl,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF source not available.')),
            );
          }
        },
        child: Container(
          width: placeholderSize,
          height: placeholderSize,
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: Container(
              color: Colors.grey[300],
              child: pdfPreviewContent,
            ),
          ),
        ),
      );
    } else {
      // Non-PDF document
      return GestureDetector(
        onTap: () async {
          HapticUtils.lightTap();
          final sourcePathOrUrl = widget.message.mediaUrl ?? widget.message.localFilePath;
          
          if (sourcePathOrUrl != null) {
            final Uri? uri = Uri.tryParse(sourcePathOrUrl);
            if (uri != null) {
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open document: ${widget.message.content}')),
                    );
                  }
                }
              } catch (e) {
                AppLogger.e('Error launching URL $uri: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error opening document: ${widget.message.content}')),
                  );
                }
              }
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cannot open invalid link for: ${widget.message.content}')),
                );
              }
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('No link available for: ${widget.message.content}')),
              );
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.insert_drive_file_outlined, color: widget.textColor, size: 40),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    widget.message.content,
                    style: TextStyle(color: widget.textColor, fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
} 