import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../features/chat/screens/fullscreen_image_viewer.dart';
import '../../../features/chat/screens/chat_screen.dart';

class PatientInfoScreen extends StatelessWidget {
  final PatientOnboardingData data;

  const PatientInfoScreen({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final age = data.age;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Use theme background instead of hardcoded surface
      appBar: AppBar(
        backgroundColor: AppColors.primary, // Match chat screen's blue background
        foregroundColor: Colors.white, // White text and icons for contrast
        title: Text(
          'Patient Information',
          style: const TextStyle(color: Colors.white), // Explicitly set title text to white
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white), // Match chat screen's back icon
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(
            top: 16, 
            left: 16, 
            right: 16, 
            bottom: MediaQuery.of(context).padding.bottom + 16
          ),
          children: [
            // Header with Basic Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 32, 
                  backgroundColor: AppColors.primary.withAlpha(51),
                  child: Text(
                    data.name.isNotEmpty ? data.name[0].toUpperCase() : 'P',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name, 
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
                      ),
                      if (age != null || data.gender != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '${data.gender ?? ''}${data.gender != null && age != null ? ', ' : ''}${age != null ? '$age years old' : ''}', 
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Vitals & Location
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildVitalsLocationRow(context, data),
            ),

            // Detailed Sections
            if (data.conditions.isNotEmpty)
              _buildIntroSection(context, title: 'Conditions', icon: Icons.monitor_heart_outlined, items: data.conditions),
            if (data.otherConditions != null && data.otherConditions!.isNotEmpty)
              _buildIntroSection(context, title: 'Other Conditions', icon: Icons.help_outline_rounded, items: [data.otherConditions!]),
            if (data.surgicalHistory != null && data.surgicalHistory!.toLowerCase() != 'none')
              _buildIntroSection(context, title: 'Surgical History', icon: Icons.healing_outlined, items: [data.surgicalHistory!]),
            if (data.medications != null && data.medications!.toLowerCase() != 'none')
              _buildIntroSection(context, title: 'Current Medications', icon: Icons.medication_outlined, items: [data.medications!]),
            if (data.allergies != null && data.allergies!.toLowerCase() != 'none')
              _buildIntroSection(context, title: 'Reported Allergies', icon: Icons.warning_amber_rounded, items: [data.allergies!], useErrorColor: true),
            if (data.documents.isNotEmpty)
              _buildIntroSection(context, title: 'Uploaded Documents', icon: Icons.attach_file_outlined, isDocumentList: true, documentItems: data.documents),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper method for vitals and location row
  Widget _buildVitalsLocationRow(BuildContext context, PatientOnboardingData patient) {
    final theme = Theme.of(context);
    Widget buildItem(IconData icon, String? value) {
      if (value == null || value.isEmpty) return const SizedBox.shrink();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(value, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 12),
        ],
      );
    }

    return Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      children: [
        if (patient.height != null) buildItem(Icons.height, patient.height),
        if (patient.weight != null) buildItem(Icons.monitor_weight_outlined, patient.weight),
        if (patient.city != null || patient.country != null)
          buildItem(Icons.location_on_outlined, '${patient.city ?? ''}${patient.city != null && patient.country != null ? ', ' : ''}${patient.country ?? ''}'),
      ],
    );
  }

  // Helper to build sections
  Widget _buildIntroSection(BuildContext context, {
    required String title,
    required IconData icon,
    List<String>? items,
    List<Map<String, dynamic>>? documentItems,
    bool isDocumentList = false,
    bool useErrorColor = false,
  }) {
    final theme = Theme.of(context);
    final List<dynamic> contentItems = isDocumentList 
        ? (documentItems?.map((e) => e).toList() ?? [])
        : (items ?? []);

    if (isDocumentList) {
      AppLogger.d("[DEBUG Docs UI] _buildIntroSection received documentItems: $documentItems");
    }

    if (contentItems.isEmpty) return const SizedBox.shrink();

    final Color chipBackgroundColor = useErrorColor 
        ? theme.colorScheme.errorContainer 
        : theme.colorScheme.secondaryContainer;
    final Color chipForegroundColor = useErrorColor 
        ? theme.colorScheme.onErrorContainer 
        : theme.colorScheme.onSecondaryContainer;
    final Color iconColor = useErrorColor
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 6.0,
            children: contentItems.map((item) {
              String itemName;
              String? itemUrl;
              String itemType = 'text';

              bool isConsideredImage = false;
              String lowerCaseName = '';
              String lowerCaseUrl = '';
              String lowerCaseType = '';

              if (isDocumentList && item is Map<String, dynamic>) {
                itemName = item['name']?.toString() ?? 'Unknown Document';
                itemUrl = item['url']?.toString();
                itemType = item['type']?.toString() ?? 'document';

                lowerCaseName = itemName.toLowerCase();
                lowerCaseUrl = itemUrl?.toLowerCase() ?? '';
                lowerCaseType = itemType.toLowerCase();

                isConsideredImage = lowerCaseType == 'image' ||
                                  lowerCaseName.endsWith('.png') || lowerCaseName.endsWith('.jpg') || 
                                  lowerCaseName.endsWith('.jpeg') || lowerCaseName.endsWith('.gif') || 
                                  lowerCaseName.endsWith('.webp') ||
                                  lowerCaseUrl.contains('.png?') || lowerCaseUrl.contains('.jpg?') || 
                                  lowerCaseUrl.contains('.jpeg?') || lowerCaseUrl.contains('.gif?') || 
                                  lowerCaseUrl.contains('.webp?');

                if (isConsideredImage) {
                  AppLogger.d('[DEBUG Docs UI] Image found (by type/ext): Name=$itemName, URL=$itemUrl, Type=$itemType');
                } else if (itemUrl != null) {
                  AppLogger.d('[DEBUG Docs UI] Non-image document found: Name=$itemName, URL=$itemUrl, Type=$itemType');
                }
              } else if (item is String) {
                itemName = item;
                isConsideredImage = false;
              } else {
                return const SizedBox.shrink();
              }

              if (isDocumentList) {
                if (!isConsideredImage && itemUrl != null) {
                  IconData docIcon = Icons.description_outlined;
                  if (lowerCaseType == 'pdf' || lowerCaseName.endsWith('.pdf')) {
                    docIcon = Icons.picture_as_pdf_outlined;
                  }

                  return ActionChip(
                    avatar: Icon(docIcon, size: 16, color: chipForegroundColor),
                    label: Text(itemName, style: TextStyle(color: chipForegroundColor)),
                    onPressed: () async {
                      HapticUtils.lightTap();
                      AppLogger.d('Tapped on document chip: $itemName - URL: $itemUrl');
                      if (itemUrl != null) {
                        final Uri? uri = Uri.tryParse(itemUrl);
                        if (uri != null) {
                          try {
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } else {
                              AppLogger.w('Could not launch URL: $uri');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not open document: $itemName')),
                                );
                              }
                            }
                          } catch (e) {
                            AppLogger.e('Error launching URL $uri: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error opening document: $itemName')),
                              );
                            }
                          }
                        } else {
                          AppLogger.w('Invalid URL format for document: $itemUrl');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Cannot open invalid link for: $itemName')),
                            );
                          }
                        }
                      } else {
                        AppLogger.w('No URL available for document chip: $itemName');
                      }
                    },
                    backgroundColor: chipBackgroundColor,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    labelPadding: const EdgeInsets.only(left: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                } else {
                  return const SizedBox.shrink();
                }
              } else {
                return Chip(
                  label: Text(itemName),
                  backgroundColor: chipBackgroundColor,
                  labelStyle: TextStyle(color: chipForegroundColor, fontSize: 13, fontWeight: FontWeight.w500),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }
            }).where((widget) => widget is! SizedBox || (widget is SizedBox && widget.height != 0)).toList(),
          ),

          // GridView for Images
          if (isDocumentList && documentItems != null)
            Builder(
              builder: (context) {
                final imageItems = documentItems.where((item) {
                  final type = item['type']?.toString().toLowerCase();
                  final name = item['name']?.toString().toLowerCase() ?? '';
                  final url = item['url']?.toString().toLowerCase() ?? '';
                  return (type == 'image' ||
                          name.endsWith('.png') || name.endsWith('.jpg') || 
                          name.endsWith('.jpeg') || name.endsWith('.gif') || 
                          name.endsWith('.webp') ||
                          url.contains('.png?') || url.contains('.jpg?') || 
                          url.contains('.jpeg?') || url.contains('.gif?') || 
                          url.contains('.webp?')) && 
                          item['url'] != null;
                }).toList();
                
                AppLogger.d("[DEBUG Docs UI] Filtered image items for GridView: ${imageItems.length}");

                if (imageItems.isEmpty) return const SizedBox.shrink();

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: imageItems.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                  ),
                  itemBuilder: (context, index) {
                    final imageItem = imageItems[index];
                    final imageUrl = imageItem['url'] as String;

                    return GestureDetector(
                      onTap: () {
                        AppLogger.i("Tapping image grid item: $imageUrl");
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullscreenImageViewer(imagePath: imageUrl),
                          ),
                        );
                      },
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2)
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              AppLogger.e("Error loading grid image: $imageUrl, Error: $error");
                              return Container(
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
            ),
        ],
      ),
    );
  }
} 