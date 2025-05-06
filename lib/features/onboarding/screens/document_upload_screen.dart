import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:easy_localization/easy_localization.dart'; // Import for translations
import 'package:urocenter/core/utils/logger.dart';
// import 'package:file_picker/file_picker.dart'; // Temporarily removed due to dependency issues
import 'dart:io';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/utils.dart';
import '../../../app/routes.dart';
import '../widgets/onboarding_progress.dart';
import '../widgets/upload_document_tile.dart';
import '../providers/onboarding_providers.dart'; // Import provider
import '../../../providers/service_providers.dart'; // Import service providers
import '../../../core/constants/app_constants.dart'; // Import for onboarding steps
import '../../../core/utils/haptic_utils.dart'; 

/// Document upload screen for onboarding
class DocumentUploadScreen extends ConsumerStatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  ConsumerState<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> with SingleTickerProviderStateMixin {
  final List<UploadedDocument> _uploadedDocuments = [];
  bool _isUploading = false;
  bool _isLoading = false;
  bool _isExiting = false;
  bool _hasConfirmedNoDocuments = false; // State for "No Documents" confirmation
  bool _isInfoExpanded = false; // State for info expansion

  // Animation controller for the button pulse
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Future<void> _pickDocument() async {
  //   try {
  //     FilePickerResult? result = await FilePicker.platform.pickFiles(
  //       type: FileType.custom,
  //       allowedExtensions: ['pdf', 'doc', 'docx'],
  //     );

  //     if (result != null) {
  //       File file = File(result.files.single.path!);
  //       setState(() {
  //         _isUploading = true;
  //       });

  //       // Simulate upload with delay
  //       await Future.delayed(const Duration(milliseconds: 1500));

  //       setState(() {
  //         _uploadedDocuments.add(
  //           UploadedDocument(
  //             name: result.files.single.name,
  //             size: file.lengthSync(),
  //             path: file.path,
  //             dateUploaded: DateTime.now(),
  //             type: DocumentType.file,
  //           ),
  //         );
  //         _isUploading = false;
  //       });
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _isUploading = false;
  //     });
  //     if (mounted) {
  //       NavigationUtils.showSnackBar(
  //         context,
  //         'Error uploading document: ${e.toString()}',
  //         backgroundColor: AppColors.error,
  //       );
  //     }
  //   }
  // }

  // Temporary replacement for _pickDocument that shows a message
  void _pickDocument() {
    NavigationUtils.showSnackBar(
      context,
      'onboarding.document_picking_disabled'.tr(),
      backgroundColor: AppColors.warning,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void initState() {
    super.initState();
    // Button Pulse Animation Setup
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateButtonState();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose(); // Dispose animation controller
    super.dispose();
  }

  // --- Update Continue button state based on uploads or confirmation ---
  void _updateButtonState() {
     if (!mounted) return;
    final bool canContinue = _uploadedDocuments.isNotEmpty || _hasConfirmedNoDocuments;
    ref.read(onboardingButtonProvider.notifier).state = OnboardingButtonState(
      text: 'common.continue'.tr(),
      onPressed: canContinue ? _saveAndContinue : null,
      isLoading: _isLoading,
    );
  }

  // --- Action for the "No Documents" button ---
  void _confirmNoDocuments() {
    HapticUtils.lightTap();
    setState(() {
      _hasConfirmedNoDocuments = true;
    });
    _updateButtonState();
  }

  Future<void> _takePicture() async {
    HapticUtils.lightTap();
    FocusScope.of(context).unfocus(); // Dismiss keyboard if camera opens
    final ImagePicker picker = ImagePicker();
    XFile? photo;

    try {
      // Attempt to pick image from camera
      photo = await picker.pickImage(source: ImageSource.camera);

    } catch (e) {
      // Log error and suggest permissions, then fall back to gallery
      AppLogger.e('CAMERA ERROR: $e');
      AppLogger.i('Ensure camera permissions are granted in Info.plist (NSCameraUsageDescription) and AndroidManifest.xml');
      if (mounted) {
        NavigationUtils.showSnackBar(
          context,
          'Could not access camera. Ensure permissions are granted. Falling back to gallery.',
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 4),
        );
        try {
          photo = await picker.pickImage(source: ImageSource.gallery);
        } catch (galleryError) {
           AppLogger.e('Gallery Error after Camera Error: $galleryError');
           if (mounted) {
             NavigationUtils.showSnackBar(
               context, 'Could not access photos: $galleryError', backgroundColor: AppColors.error
             );
           }
        }
      }
    }

    if (photo != null) {
      File file = File(photo.path);
      String fileName = photo.name; // Get filename
      int fileSize = file.lengthSync();
      
      setState(() {
        _isUploading = true; // Show local indicator while this specific file uploads
      });

      String? downloadUrl;
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) throw Exception("User not logged in.");
        
        final storageService = ref.read(storageServiceProvider);
        downloadUrl = await storageService.uploadFile(
          userId: userId,
          filePath: file.path,
          destinationFolder: 'user_documents', // Or a specific onboarding folder?
          fileName: fileName, 
        );
        
        if (downloadUrl == null) {
          throw Exception("Failed to get download URL from storage.");
        }
        
        AppLogger.d("Onboarding photo uploaded: $downloadUrl");
        
        // Add to list ONLY after successful upload
      setState(() {
        _uploadedDocuments.add(
          UploadedDocument(
              name: fileName, // Use actual filename
              size: fileSize, // Use actual size
              downloadUrl: downloadUrl, // Store the URL
            dateUploaded: DateTime.now(),
            type: DocumentType.image,
          ),
        );
          _hasConfirmedNoDocuments = false; // Reset confirmation
        });
        _updateButtonState(); // Update button state
        
      } catch (e) {
        AppLogger.e("Error uploading onboarding photo: $e");
        if(mounted) {
          NavigationUtils.showSnackBar(
            context,
            "Error uploading photo: ${ErrorHandler.handleError(e)}",
            backgroundColor: AppColors.error,
          );
        }
      } finally {
        // Hide local indicator regardless of outcome
        if (mounted) {
          setState(() {
        _isUploading = false;
      });
        }
      }
    } else {
       AppLogger.d('No photo was selected or taken.');
    }
  }

  Future<void> _pickImage() async {
    HapticUtils.lightTap();
    FocusScope.of(context).unfocus(); // Dismiss keyboard if gallery opens
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        File file = File(image.path);
        String fileName = image.name; // Get filename
        int fileSize = file.lengthSync();
        
        setState(() {
          _isUploading = true; // Show local indicator
        });
        
        String? downloadUrl;
        try {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId == null) throw Exception("User not logged in.");
          
          final storageService = ref.read(storageServiceProvider);
          downloadUrl = await storageService.uploadFile(
            userId: userId,
            filePath: file.path,
            destinationFolder: 'user_documents', // Or a specific onboarding folder?
            fileName: fileName, 
          );
          
          if (downloadUrl == null) {
            throw Exception("Failed to get download URL from storage.");
          }
          
          AppLogger.d("Onboarding image uploaded: $downloadUrl");
          
          // Add to list ONLY after successful upload
        setState(() {
          _uploadedDocuments.add(
            UploadedDocument(
                name: fileName, // Use actual filename
                size: fileSize, // Use actual size
                downloadUrl: downloadUrl, // Store the URL
              dateUploaded: DateTime.now(),
              type: DocumentType.image,
            ),
          );
            _hasConfirmedNoDocuments = false; // Reset confirmation
          });
          _updateButtonState(); // Update button state
          
        } catch (e) {
           AppLogger.e("Error uploading onboarding image: $e");
          if(mounted) {
            NavigationUtils.showSnackBar(
              context,
              "Error uploading image: ${ErrorHandler.handleError(e)}",
              backgroundColor: AppColors.error,
            );
          }
        } finally {
           // Hide local indicator regardless of outcome
           if (mounted) {
             setState(() {
          _isUploading = false;
        });
           }
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        NavigationUtils.showSnackBar(
          context,
          'Error selecting image: ${e.toString()}',
          backgroundColor: AppColors.error,
        );
      }
    }
  }

  void _deleteDocument(int index) {
    HapticUtils.lightTap();
    setState(() {
      _uploadedDocuments.removeAt(index);
      // If last document was removed, reset the "No Documents" confirmation
      if (_uploadedDocuments.isEmpty) {
        _hasConfirmedNoDocuments = false;
      }
    });
    _updateButtonState(); // Update button state after deleting
  }

  Future<void> _saveAndContinue() async {
    HapticUtils.lightTap();
    FocusScope.of(context).unfocus(); // Dismiss keyboard

    setState(() => _isExiting = true);
    ref.read(onboardingButtonProvider.notifier).update((state) => state.copyWith(isLoading: true));

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    try {
      // Get user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in during document upload setup.");
      }
      final userId = user.uid;

      // --- Upload Documents to Firebase Storage ---
      // REMOVED: No longer upload here. Upload happens when picking.
      // final List<String> downloadUrls = [];
      // final storageService = ref.read(storageServiceProvider);
      
      // Use a standard for loop to allow await inside
      // for (final doc in _uploadedDocuments) {
      //   if (!mounted) return; // Check mount status in loop
        
      //   AppLogger.d("Uploading document: ${doc.name}");
      //   final downloadUrl = await storageService.uploadFile(
      //     userId: userId,
      //     filePath: doc.path, // <<< THIS WAS THE ERROR >>>
      //     destinationFolder: 'user_documents',
      //     fileName: doc.name, // Use original name for storage
      //   );
        
      //   if (downloadUrl != null) {
      //     downloadUrls.add(downloadUrl);
      //   } else {
      //     // Handle upload failure for a specific document
      //     AppLogger.e("Error uploading ${doc.name}. Skipping file.");
      //     // Optionally show a specific error message to the user
      //     // NavigationUtils.showSnackBar(context, 'Failed to upload ${doc.name}', backgroundColor: AppColors.error);
      //     // Depending on requirements, you might want to stop the whole process here
      //     // throw Exception("Failed to upload document: ${doc.name}"); 
      //   }
      // }
      
      // --- Get Download URLs from the state list --- 
      final List<String> downloadUrls = _uploadedDocuments
          .map((doc) => doc.downloadUrl)
          .where((url) => url != null && url.isNotEmpty) // Filter out null/empty URLs
          .cast<String>() // Ensure type safety
          .toList();
      
      AppLogger.d("Collected URLs for saving: $downloadUrls");

      // --- Update Firestore --- 
      // Determine the next onboarding step
      final String nextOnboardingStep = AppConstants.onboardingSteps[3]; // 'payment'

      // Prepare the data map to save
      final Map<String, dynamic> dataToSave = {
        'uploadedDocumentUrls': downloadUrls, // Save the list of URLs
        'documentsUploaded': true, // Mark step as completed
        'onboardingStep': nextOnboardingStep,
        'profileLastUpdatedAt': FieldValue.serverTimestamp(),
      };

      // Get the user profile service and save data
      final userProfileService = ref.read(userProfileServiceProvider);
      await userProfileService.saveUserProfile(userId: userId, data: dataToSave);
      AppLogger.d("Document Upload Step Data Saved to Firestore: $dataToSave");

      // Navigate to the next step (Payment Screen)
      context.goNamed(RouteNames.payment);
      
    } catch (e) {
      if (mounted) {
        NavigationUtils.showSnackBar(
          context,
          ErrorHandler.handleError(e),
          backgroundColor: AppColors.error,
        );
        setState(() => _isExiting = false);
         // Reset button state on error
        ref.read(onboardingButtonProvider.notifier).update((state) => state.copyWith(isLoading: false));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
          Expanded(
            child: ScrollableContent(
              padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0), 
              child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final slideAnimation = Tween<Offset>(
                      begin: const Offset(0.0, 0.3),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slideAnimation, child: child),
                    );
                  },
                  child: _isExiting
                    ? const SizedBox.shrink()
                    : Column(
                       key: const ValueKey('upload_content'),
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          // --- Animated Button to Toggle Info --- 
                          _buildExpandInfoButton(),
                          
                          // --- Animated Info Card Content --- 
                          _buildAnimatedInfoList(),
                          
                          const SizedBox(height: 24), // Spacing after info section
                          
                          // Upload Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: Text('onboarding.upload_document_photo'.tr()),
                              onPressed: () => _showUploadOptions(context),
                              style: ElevatedButton.styleFrom(
                                 padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          if (_isUploading) Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 24.0), child: Column(children: [const AnimatedLoader(size: 40), const SizedBox(height: 16), Text('onboarding.uploading'.tr())]))),
                          if (!_isUploading && _uploadedDocuments.isNotEmpty) 
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0), // Add space above the list
                              child: ListView.builder(
                                shrinkWrap: true, 
                                physics: const NeverScrollableScrollPhysics(), 
                                itemCount: _uploadedDocuments.length, 
                                itemBuilder: (context, index) { 
                                  final doc = _uploadedDocuments[index]; 
                                  return UploadDocumentTile(document: doc, onDelete: () => _deleteDocument(index));
                                }
                              ),
                            ),
                          if (!_isUploading && _uploadedDocuments.isEmpty) 
                             Padding(
                               padding: const EdgeInsets.only(top: 16.0), // Reduced spacing
                               child: Center(
                                 child: _hasConfirmedNoDocuments
                                   ? Chip( // Show confirmation chip
                                       avatar: Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.secondary, size: 18),
                                       label: Text('onboarding.continuing_without_documents'.tr(), 
                                         style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                       backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withAlpha(77),
                                       side: BorderSide.none,
                                     )
                                   : OutlinedButton.icon(
                                       icon: Icon(Icons.library_add_check_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                                       label: Text(
                                         'onboarding.no_documents_now'.tr(),
                                         style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.normal),
                                       ),
                                       onPressed: _confirmNoDocuments, 
                                       style: OutlinedButton.styleFrom(
                                          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                                          side: BorderSide(color: Theme.of(context).colorScheme.outline),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                       ),
                                     ),
                               ),
                             ),
                          const SizedBox(height: 80), 
                       ],
                    ),
              ),
            ),
          ),
        ],
      );
  }

  // --- Button to toggle the info section (Revised: Info Capsule) ---
  Widget _buildExpandInfoButton() {
    final theme = Theme.of(context); // Get theme
    return FadeTransition(
      opacity: _pulseAnimation, 
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0), 
        child: InkWell(
          onTap: () {
            HapticUtils.lightTap();
            setState(() {
              _isInfoExpanded = !_isInfoExpanded;
            });
          },
          borderRadius: BorderRadius.circular(30), // Match container border radius
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), 
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(26), // Very subtle background
              borderRadius: BorderRadius.circular(30), 
              border: Border.all(color: theme.colorScheme.primary.withAlpha(77), width: 1),
              boxShadow: [
                 BoxShadow(
                    color: theme.shadowColor.withAlpha(_isInfoExpanded ? 38 : 13), 
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
              ]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out content
              children: [
                Row( // Group icon and text
                   mainAxisSize: MainAxisSize.min, 
                   children: [
                     Icon(Icons.lightbulb_outline_rounded, color: theme.colorScheme.primary, size: 22),
                     const SizedBox(width: 10),
                     Text(
                        'onboarding.what_documents_helpful'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                          fontSize: 14,
                        ),
                      ), 
                   ],
                ),
                // Animated Down/Up Arrow
                AnimatedRotation(
                  turns: _isInfoExpanded ? 0.5 : 0, // 0.5 turn = 180 degrees
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: theme.colorScheme.primary.withAlpha(204),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Animated Container for the Info List --- 
  Widget _buildAnimatedInfoList() {
    final theme = Theme.of(context); // Get theme
    // Define theme-based container colors
    final Map<String, Color> categoryColors = {
      'Lab': theme.colorScheme.primaryContainer.withAlpha(153),
      'Imaging': theme.colorScheme.secondaryContainer.withAlpha(153),
      'Notes': theme.colorScheme.tertiaryContainer.withAlpha(153),
      'Surgical': theme.colorScheme.errorContainer.withAlpha(153),
      'Pathology': theme.colorScheme.surfaceContainerHighest.withAlpha(153),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _isInfoExpanded
        ? Card(
            elevation: 0.5, 
            margin: const EdgeInsets.only(top: 4.0, bottom: 0), // Add space above card
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
            color: theme.colorScheme.surfaceContainer, 
            clipBehavior: Clip.antiAlias, 
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 0), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Re-implement the single column list using _buildInfoRow
                   _buildInfoRow(
                    context,
                    icon: Icons.science_outlined,
                    iconColor: categoryColors['Lab']!,
                    title: 'onboarding.document_type_lab'.tr(),
                    subtitle: 'onboarding.document_desc_lab'.tr(),
                  ),
                  _buildInfoRow(
                    context,
                    icon: Icons.image_search_outlined,
                    iconColor: categoryColors['Imaging']!,
                    title: 'onboarding.document_type_imaging'.tr(),
                    subtitle: 'onboarding.document_desc_imaging'.tr(),
                  ),
                  _buildInfoRow(
                    context,
                    icon: Icons.description_outlined,
                    iconColor: categoryColors['Notes']!,
                    title: 'onboarding.document_type_consultation'.tr(),
                    subtitle: 'onboarding.document_desc_consultation'.tr(),
                  ),
                   _buildInfoRow(
                    context,
                    icon: Icons.medical_services_outlined,
                    iconColor: categoryColors['Surgical']!,
                    title: 'onboarding.document_type_surgical'.tr(),
                    subtitle: 'onboarding.document_desc_surgical'.tr(),
                  ),
                    _buildInfoRow(
                    context,
                    icon: Icons.biotech_outlined,
                    iconColor: categoryColors['Pathology']!,
                    title: 'onboarding.document_type_pathology'.tr(),
                    subtitle: 'onboarding.document_desc_pathology'.tr(),
                    isLast: true,
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink(), // Collapsed state
    );
  }

  // --- Method to show upload options in a bottom sheet ---
  void _showUploadOptions(BuildContext context) {
    final theme = Theme.of(context); // Get theme
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
                leading: Icon(Icons.camera_alt_outlined, color: theme.colorScheme.primary),
                title: Text('documents.take_photo'.tr()),
                onTap: () {
                  HapticUtils.lightTap();
                  Navigator.of(ctx).pop(); // Close the bottom sheet
                  _takePicture();
                },
              ),
              ListTile(
                leading: Icon(Icons.image_outlined, color: theme.colorScheme.primary),
                title: Text('documents.upload_photo'.tr()),
                onTap: () {
                  HapticUtils.lightTap();
                  Navigator.of(ctx).pop(); // Close the bottom sheet
                  _pickImage();
                },
              ),
              ListTile(
                leading: Icon(Icons.attach_file, color: theme.colorScheme.onSurfaceVariant),
                title: Text('documents.upload_document'.tr()),
                subtitle: Text('onboarding.temporarily_disabled'.tr(), 
                  style: TextStyle(color: theme.colorScheme.tertiary, fontSize: 12)),
                onTap: () {
                  HapticUtils.lightTap();
                  Navigator.of(ctx).pop(); // Close the bottom sheet
                  _pickDocument(); // Still calls the temporary function
                },
              ),
               const SizedBox(height: 16), // Add some padding at the bottom
            ],
          ),
        );
      },
    );
  }

  // --- Helper for a single row in the Info Card (Restored Single Column Style) ---
  Widget _buildInfoRow(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool isLast = false,
  }) {
    final theme = Theme.of(context); // Get theme
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0), 
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: theme.colorScheme.outline.withAlpha(128), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, 
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: iconColor, 
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith( 
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3, 
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Placeholder for UploadedDocument model (adjust as needed)
// enum DocumentType { image, file }

// class UploadedDocument {
//   final String name;
//   final int size;
//   final String path;
//   final DateTime dateUploaded;
//   final DocumentType type;

//   UploadedDocument({
//     required this.name,
//     required this.size,
//     required this.path,
//     required this.dateUploaded,
//     required this.type,
//   });
// } 
// } 
