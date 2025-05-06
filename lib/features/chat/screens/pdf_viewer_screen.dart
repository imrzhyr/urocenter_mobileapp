import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:urocenter/core/utils/logger.dart';

class PdfViewerScreen extends StatefulWidget {
  final dynamic extraData;

  const PdfViewerScreen({super.key, this.extraData});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _isLoading = true;
  String? _localFilePath;
  String? _errorMessage;
  PDFViewController? _pdfController;
  int? pages = 0;
  int? currentPage = 0;
  bool isReady = false;
  String pdfFileName = "Document";

  @override
  void initState() {
    super.initState();
    _preparePdfSource();
  }

  Future<void> _preparePdfSource() async {
    if (widget.extraData == null || !(widget.extraData is String)) {
      setState(() {
        _errorMessage = "Invalid PDF source provided.";
        _isLoading = false;
      });
      return;
    }

    final String sourcePathOrUrl = widget.extraData as String;

    try {
      pdfFileName = Uri.parse(sourcePathOrUrl).pathSegments.last;
    } catch (_) {
       pdfFileName = "Document";
    }

    if (sourcePathOrUrl.startsWith('http')) {
      AppLogger.d("[PDFViewer] Source is URL, attempting download: $sourcePathOrUrl");
      setState(() { 
        _isLoading = true;
        _errorMessage = null;
      });
      await _downloadAndPreparePdf(sourcePathOrUrl);
    } else {
      AppLogger.d("[PDFViewer] Source is Local Path: $sourcePathOrUrl");
      if (await File(sourcePathOrUrl).exists()) {
        setState(() {
          _localFilePath = sourcePathOrUrl;
          _isLoading = false;
           _errorMessage = null;
        });
      } else {
         AppLogger.e("[PDFViewer] Error: Local file does not exist at $sourcePathOrUrl");
         setState(() {
           _errorMessage = "File not found.";
           _isLoading = false;
         });
      }
    }
  }

  Future<void> _downloadAndPreparePdf(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getTemporaryDirectory();
        final filename = '${const Uuid().v4()}.pdf';
        final tempPath = '${dir.path}/$filename';
        final file = File(tempPath);
        await file.writeAsBytes(bytes, flush: true);
        AppLogger.d("[PDFViewer] PDF downloaded and saved to: $tempPath");
        if (mounted) {
          setState(() {
            _localFilePath = tempPath;
            _isLoading = false;
             _errorMessage = null;
          });
        }
      } else {
        throw Exception('Failed to download PDF: Status code ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.e("[PDFViewer] Error downloading/preparing PDF: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load PDF.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(pdfFileName),
      ),
      body: _buildBody(),
      floatingActionButton: pages != null && pages! > 1 ? FloatingActionButton.extended(
        label: Text("Page ${currentPage! + 1}/$pages"),
        icon: const Icon(Icons.navigate_next),
        onPressed: () {
           _pdfController?.setPage(currentPage! + 1);
        },
      ) : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [ 
             const Icon(Icons.error_outline, color: Colors.red, size: 50),
             const SizedBox(height: 10),
             Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
          ]
        )
      );
    }
    if (_localFilePath == null) {
      return const Center(child: Text("Could not load PDF."));
    }

    return PDFView(
            filePath: _localFilePath!,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: false,
            pageFling: true,
            pageSnap: true,
            defaultPage: currentPage ?? 0,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false,
            onRender: (pagesCount) {
              if (mounted) {
                 setState(() {
                    pages = pagesCount;
                    isReady = true;
                 });
              }
            },
            onError: (error) {
              AppLogger.e("PDFView Error: $error");
              if(mounted){
                setState(() {
                  _errorMessage = "Error displaying PDF: $error";
                });
              }
            },
            onPageError: (page, error) {
              AppLogger.e('PDFView Page Error: page: $page, error: $error');
            },
            onViewCreated: (PDFViewController pdfViewController) {
               _pdfController = pdfViewController;
            },
            onLinkHandler: (String? uri) {
              AppLogger.d('PDF Link tapped: $uri');
            },
            onPageChanged: (int? page, int? total) {
              AppLogger.d('PDFView page change: $page/$total');
               if (mounted) {
                 setState(() {
                   currentPage = page;
                 });
              }
            },
         );
  }
} 
