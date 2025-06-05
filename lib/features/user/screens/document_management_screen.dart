import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added Riverpod
import 'package:file_picker/file_picker.dart'; // Added file_picker
import 'package:image_picker/image_picker.dart'; // Added image_picker
import 'package:easy_localization/easy_localization.dart'; // Added for localization
import 'package:urocenter/core/utils/logger.dart';
// import '../../../core/widgets/app_scaffold.dart'; // No longer using AppScaffold directly
import '../../../core/theme/theme.dart';
import '../../../app/routes.dart'; // For Back button
import '../../../core/utils/date_utils.dart'; // Import for AppDateUtils
import '../../../core/utils/dialog_utils.dart'; // Import for DialogUtils
import '../../../core/models/models.dart'; // Import all models
import '../../../providers/service_providers.dart'; // Import service providers
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart'; // Import for animations
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/utils/navigation_utils.dart'; // Import for NavigationUtils
import '../../../core/utils/error_handler.dart'; // Import for ErrorHandler
// Import UserProfileService provider to fetch main profile data
import '../../../features/user/services/user_profile_service.dart'; 
import '../../../core/widgets/circular_loading_indicator.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/widgets/app_bar_style2.dart';

// No longer using typedef
// typedef UserDocument = Map<String, dynamic>;

class DocumentManagementScreen extends ConsumerStatefulWidget { // Changed to Consumer
  const DocumentManagementScreen({super.key});

  @override
  ConsumerState<DocumentManagementScreen> createState() => // Changed to ConsumerState
      _DocumentManagementScreenState();
}

class _DocumentManagementScreenState extends ConsumerState<DocumentManagementScreen> { // Changed to ConsumerState
  
  // --- State Variables ---
  List<DocumentModel> _userDocuments = []; // Changed to List<DocumentModel>
  bool _isLoading = true; 
  String? _error;
  bool _isUploading = false; // <<< ADDED Uploading State >>>
  // --- End State Variables ---

  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to load data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDocuments(); 
    });
  }

  // --- Data Fetching & Actions ---
  Future<void> _loadDocuments({bool isRefresh = false}) async {
    if (!mounted) return;
    if (!isRefresh || _userDocuments.isEmpty) {
       setState(() {
         _isLoading = true;
         _error = null;
       });
    }
    // List<DocumentModel> fetchedDocs = []; // Will combine results later
    List<DocumentModel> combinedDocs = [];
    
    try {
      // Get services and userId
      final docService = ref.read(documentServiceProvider);
      final profileService = ref.read(userProfileServiceProvider);
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
         throw Exception('User not logged in while trying to load documents.');
      }
      
      // 1. Fetch documents from the dedicated subcollection
      AppLogger.d("Fetching documents from subcollection...");
      List<DocumentModel> subCollectionDocs = await docService.getUserDocuments(userId);
      AppLogger.d("Found ${subCollectionDocs.length} documents in subcollection.");
      combinedDocs.addAll(subCollectionDocs);
      
      // 2. Fetch document URLs from the main user profile
      AppLogger.d("Fetching main user profile for additional document URLs...");
      Map<String, dynamic>? userProfile = await profileService.getUserProfile(userId);
      
      if (userProfile != null) {
        AppLogger.d("User profile fetched successfully.");
        // a. Get URLs from 'uploadedDocumentUrls' list (from DocumentUploadScreen)
        List<String> onboardingUrls = [];
        if (userProfile['uploadedDocumentUrls'] is List) {
           onboardingUrls = List<String>.from(userProfile['uploadedDocumentUrls']);
           AppLogger.d("Found ${onboardingUrls.length} URLs in 'uploadedDocumentUrls'.");
        }
        
        // b. Get URL from 'medicationDocumentUrl' field (from MedicalHistoryScreen)
        String? medicationUrl = userProfile['medicalHistory']?['medicationDocumentUrl'] as String?;
        if (medicationUrl != null && medicationUrl.isNotEmpty) {
           AppLogger.d("Found medication URL: $medicationUrl");
           onboardingUrls.add(medicationUrl); // Add to the list to process together
        }
        
        // c. Convert URLs to DocumentModel objects
        for (String url in onboardingUrls) {
           // Avoid adding duplicates if already present in subcollection (check by URL)
           if (!combinedDocs.any((doc) => doc.url == url)) {
              // Attempt to extract filename from URL
              String name = 'Onboarding Document'; // Default name
              String type = 'unknown'; // Default type
              try {
                 Uri uri = Uri.parse(url);
                 String pathSegment = uri.pathSegments.last;
                 // Decode potential URL encoding in the filename
                 name = Uri.decodeComponent(pathSegment.split('/').last);
                 if (name.contains('.')) {
                    type = name.split('.').last;
                 } 
              } catch (e) {
                 AppLogger.e("Could not parse filename from URL: $url - Error: $e");
              }
           
              // Create a placeholder DocumentModel
              combinedDocs.add(DocumentModel(
                 id: url, // Use URL as a temporary ID (or generate one)
                 userId: userId,
                 name: name,
                 type: type,
                 url: url,
                 uploadDate: DateTime.now(), // Placeholder date - maybe extract from profile if available?
                 size: null, // Size unknown from URL
              ));
              AppLogger.d("Added DocumentModel for URL: $url (Name: $name)");
           } else {
              AppLogger.d("Skipping duplicate URL found in subcollection: $url");
           }
        }
      } else {
         AppLogger.d("User profile not found or empty.");
      }
      
      // Sort combined list (optional, but good practice)
      combinedDocs.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
      AppLogger.d("Total combined documents: ${combinedDocs.length}");
      
    } catch (e) {
      AppLogger.e("Error loading documents (combined fetch): $e");
      if (mounted) {
         _error = "Failed to load documents: ${ErrorHandler.handleError(e)}"; 
      }
    } finally {
      if (mounted) {
        setState(() {
          // Use the combined list
          _userDocuments = combinedDocs; 
          _isLoading = false;
          // Keep existing error logic
          if (combinedDocs.isNotEmpty || isRefresh) {
            _error = null;
          }
        });
      }
    }
  }

  // --- ADD NEW BOTTOM SHEET LAUNCHER ---
  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: Text('documents.take_photo'.tr()), // Localized
                onTap: () {
                  Navigator.of(ctx).pop(); // Close the bottom sheet
                  _handleTakePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined, color: AppColors.primary),
                title: Text('documents.upload_photo'.tr()), // Localized
                onTap: () {
                  Navigator.of(ctx).pop(); // Close the bottom sheet
                  _handlePickPhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file, color: AppColors.primary),
                title: Text('documents.upload_document'.tr()), // Localized
                onTap: () {
                  Navigator.of(ctx).pop(); // Close the bottom sheet
                  _handlePickFile();
                },
              ),
               const SizedBox(height: 16), // Add some padding at the bottom
            ],
          ),
        );
      },
    );
  }

  // --- ADD UPLOAD HANDLER IMPLEMENTATIONS ---
  Future<void> _handleTakePhoto() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        await _uploadAndSaveDocument(File(image.path));
      } else {
        AppLogger.d('Take Photo cancelled.');
      }
    } catch (e) {
      AppLogger.e('Error taking photo: $e');
      if (mounted) {
        DialogUtils.showMessageDialog(context: context, title: 'Error Taking Photo', message: ErrorHandler.handleError(e));
      }
    }
  }

  Future<void> _handlePickPhoto() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _uploadAndSaveDocument(File(image.path));
      } else {
        AppLogger.d('Pick Photo cancelled.');
      }
    } catch (e) {
      AppLogger.e('Error picking photo: $e');
      if (mounted) {
        DialogUtils.showMessageDialog(context: context, title: 'Error Picking Photo', message: ErrorHandler.handleError(e));
      }
    }
  }

  Future<void> _handlePickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'], 
      );
      if (result != null && result.files.single.path != null) {
        await _uploadAndSaveDocument(File(result.files.single.path!));
      } else {
        AppLogger.d('Pick File cancelled.');
      }
    } catch (e) {
       AppLogger.e('Error picking file: $e');
       if (mounted) {
         DialogUtils.showMessageDialog(context: context, title: 'Error Picking File', message: ErrorHandler.handleError(e));
       }
    }
  }

  // --- ADD CENTRAL UPLOAD/SAVE IMPLEMENTATION ---
  Future<void> _uploadAndSaveDocument(File file) async {
    final String fileName = file.path.split('/').last;
    AppLogger.d("Attempting to upload: $fileName");
    
    // <<< Set uploading state to true >>>
    setState(() {
      _isUploading = true;
    });

    try {
      // 1. Get userId
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception("User not logged in.");
      }

      // 2. Upload to Storage
      final storageService = ref.read(storageServiceProvider);
      final downloadUrl = await storageService.uploadFile(
        userId: userId,
        filePath: file.path,
        destinationFolder: 'user_documents',
        fileName: fileName, // Use original name
      );

      if (downloadUrl == null) {
        throw Exception("Failed to upload file to storage.");
      }
      
      AppLogger.d("File uploaded, URL: $downloadUrl");

      // 3. Prepare DocumentModel data
      final fileType = fileName.split('.').last;
      final fileSize = await file.length();
      final now = DateTime.now();

      final docData = DocumentModel(
         id: '', // Firestore will generate ID
         userId: userId, // Associate with user
         name: fileName,
         type: fileType,
         url: downloadUrl,
         size: fileSize,
         uploadDate: now,
      );
      
      // 4. Save metadata to Firestore subcollection
      final docService = ref.read(documentServiceProvider);
      final String? newDocId = await docService.addUserDocument(userId, docData);
      
      if (newDocId == null) {
         throw Exception("Failed to save document metadata to Firestore.");
      }
      AppLogger.d("Document metadata saved to Firestore with ID: $newDocId");
      
      // 6. Show Success
      if(mounted) {
         NavigationUtils.showSnackBar(context, 'Document uploaded successfully!', backgroundColor: AppColors.success);
      }
      
      // 7. Refresh UI
      _loadDocuments(isRefresh: true);

    } catch (e) {
      AppLogger.e("Error in _uploadAndSaveDocument: $e");
      // 8. Show Error using showMessageDialog
      if(mounted) {
         DialogUtils.showMessageDialog(
             context: context, 
             title: 'Upload Failed', 
             message: ErrorHandler.handleError(e) // Use error handler
         );
      }
    } finally {
      // <<< Always set uploading state to false in finally block >>>
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    } 
  }

  Future<void> _deleteDocument(String docId) async {
    if (docId.isEmpty) return;

    // Get the userId first
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
       AppLogger.e("Error: Cannot delete document, user not logged in.");
       DialogUtils.showMessageDialog(context: context, title: 'errors.auth_error'.tr(), message: 'auth.user_not_logged_in'.tr());
       return;
    }

    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context, 
      title: 'documents.confirm_deletion'.tr(), 
      message: 'documents.confirm_deletion_message'.tr(), 
      confirmText: 'common.delete'.tr(), 
      confirmColor: AppColors.error,
    );

    if (confirmed == true) {
      AppLogger.d("Deleting document: $docId for user: $userId");
       // Show loading indicator manually
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 20),
                    Text('documents.deleting'.tr()), // Localized
                  ],
                ),
              ),
            );
          },
        );
      bool success = false;
      try {
         // Get the service and call delete with BOTH userId and docId
        final docService = ref.read(documentServiceProvider);
        success = await docService.deleteDocument(userId, docId);

      } catch(e) {
         AppLogger.e("Error deleting document via service: $e");
         success = false;
      } finally {
         if(mounted && Navigator.canPop(context)) Navigator.of(context).pop(); // Hide loading
      }

      if (success) {
        AppLogger.d("Deletion successful for $docId");
        setState(() {
          _userDocuments.removeWhere((doc) => doc.id == docId);
        });
         // Use ScaffoldMessenger for Snackbar
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('documents.deleted'.tr())) // Localized
        );
      } else {
        AppLogger.e("Deletion failed for $docId");
        DialogUtils.showMessageDialog(
            context: context, 
            title: 'documents.deletion_failed'.tr(), 
            message: 'documents.could_not_delete'.tr() // Localized
        );
      }
    }
  }

  Future<void> _viewDocument(DocumentModel doc) async {
    // Assuming doc.url points to a resource that can be opened.
    // For local files, check existence.
    // For network URLs, use url_launcher or a dedicated viewer.
    AppLogger.d("Viewing document: ${doc.name}, URL/Path: ${doc.url}");
    
    if (doc.url.isEmpty) {
      DialogUtils.showMessageDialog(context: context, title: 'errors.error'.tr(), message: 'documents.missing_path'.tr()); // Localized
      return;
    }

    // Example navigation (adapt based on actual URL type and desired viewer)
    if (doc.type.toLowerCase() == 'pdf') {
       context.pushNamed(RouteNames.pdfViewer, extra: {'filePath': doc.url}); // Assuming url is a local path for now
    } else if (['jpg', 'jpeg', 'png', 'gif'].contains(doc.type.toLowerCase())) {
       context.pushNamed(RouteNames.imageViewer, extra: {'imagePath': doc.url}); // Assuming url is a local path for now
    } else {
       DialogUtils.showMessageDialog(context: context, title: 'documents.unsupported'.tr(), message: 'documents.cannot_preview'.tr()); // Localized
    }
  }

  // --- End Data Fetching & Actions ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
        
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBarStyle2(
          title: 'documents.title'.tr(),
          showSearch: false,
          showFilters: false,
          showBackButton: true,
          showActionButtons: false,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildDocumentsList(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticUtils.mediumTap();
          _showAddOptions(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- Body Content Builder ---
  Widget _buildDocumentsList(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton( // Add a retry button
                onPressed: () {
                  HapticUtils.lightTap();
                  _loadDocuments();
                },
                child: Text('common.retry'.tr()), // Localized
              ),
            ],
          ),
        ),
      );
    }

    if (_userDocuments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_outlined, size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                'documents.no_documents'.tr(), // Localized
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'documents.add_first_document'.tr(), // Localized
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // <<< CHANGE ListView to GridView >>>
    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _userDocuments.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Two columns
          crossAxisSpacing: 12.0, // Spacing between columns
          mainAxisSpacing: 12.0, // Spacing between rows
          childAspectRatio: 0.85, // Adjust aspect ratio (width/height) for item size
        ),
        itemBuilder: (context, index) {
          final doc = _userDocuments[index];
          return AnimationConfiguration.staggeredGrid( // Use staggeredGrid
            position: index,
            columnCount: 2, // Match crossAxisCount
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildDocumentGridItem(doc), // <<< Use new grid item builder >>>
              ),
            ),
          );
        },
      ),
    );
  }

  // <<< RENAME and REFACTOR to build a Grid Item >>>
  Widget _buildDocumentGridItem(DocumentModel doc) { 
    final docId = doc.id;
    final docName = doc.name;
    final docType = doc.type;
    final docUrl = doc.url;
    final uploadDate = doc.uploadDate;
    final bool isImage = ['jpg', 'jpeg', 'png', 'gif'].contains(docType.toLowerCase());

    Widget contentWidget;
    if (isImage && docUrl.isNotEmpty) {
      // Image Preview takes most space
      contentWidget = SizedBox(
        width: double.infinity, // Take available width
        height: 120, // <<< Fixed height for square-ish preview (adjust as needed)
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
          child: Image.network(
            docUrl,
                fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null, strokeWidth: 2.0));
            },
                errorBuilder: (context, error, stackTrace) {
              AppLogger.e("Error loading grid image preview for $docUrl: $error");
              return const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 40);
                },
              ),
            ),
          );
        } else {
      // Icon for non-image types
      IconData iconData;
      Color iconColor;
      switch (docType.toLowerCase()) {
        case 'pdf': iconData = Icons.picture_as_pdf_outlined; iconColor = Colors.red.shade400; break;
      case 'doc':
        case 'docx': iconData = Icons.description_outlined; iconColor = Colors.indigo.shade400; break;
        default: iconData = Icons.insert_drive_file_outlined; iconColor = Colors.grey.shade600; break;
      }
      contentWidget = Expanded(
          child: Center(
            child: Icon(iconData, color: iconColor, size: 50), // Larger icon
          ),
        );
    }

    return Card(
      margin: EdgeInsets.zero, // No margin for grid items
      elevation: 2.0,
      shadowColor: Colors.black.withValues(alpha: 26.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias, // Clip content to card shape
      child: InkWell( // Make the whole card tappable
        onTap: () => _viewDocument(doc),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 8.0), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content (Image Preview or Icon)
              Expanded(
                 child: contentWidget,
              ),
              const SizedBox(height: 8),
              // Title (only for non-images)
              if (!isImage)
                Text(
          docName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
              if (!isImage)
                 const SizedBox(height: 4),
                 
              // Subtitle (Upload Date) and Delete Button
              Row(
                children: [
                  Expanded(
                    child: Container(), // Empty container to keep the delete button to the right
                  ),
                  SizedBox(
                    width: 24, // Constrain button size
                    height: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      tooltip: 'documents.delete_document'.tr(), // Localized
                      onPressed: () {
                        HapticUtils.lightTap();
                        _deleteDocument(docId);
                      },
                      splashRadius: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  // --- End Document Grid Item Builder ---
} 
