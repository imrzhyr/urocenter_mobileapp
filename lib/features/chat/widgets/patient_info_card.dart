import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/patient_onboarding_data_model.dart';
import '../../../core/utils/haptic_utils.dart';
import '../screens/fullscreen_image_viewer.dart';

/// A widget that displays patient information in a card format
class PatientInfoCard extends StatelessWidget {
  final PatientOnboardingData patient;
  final VoidCallback onDismiss;
  final Animation<Offset> slideAnimation;
  
  const PatientInfoCard({
    super.key,
    required this.patient,
    required this.onDismiss,
    required this.slideAnimation,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SlideTransition(
      position: slideAnimation,
      child: Card(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        elevation: 1.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(100), width: 1.0)
        ),
        clipBehavior: Clip.antiAlias,
        color: theme.colorScheme.surface,
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Dismiss button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Patient Introduction',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold, 
                      color: theme.colorScheme.primary
                    )
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Dismiss Introduction',
                    onPressed: onDismiss,
                  )
                ],
              ),
              Divider(height: 16, thickness: 0.5, color: theme.dividerColor.withAlpha(100)),
              
              // Basic Info Row with Avatar
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      patient.name.isNotEmpty ? patient.name[0].toUpperCase() : 'P',
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold, 
                        color: theme.colorScheme.onPrimaryContainer
                      )
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patient.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        if (patient.age != null || patient.gender != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '${patient.gender ?? ''}${patient.gender != null && patient.age != null ? ', ' : ''}${patient.age != null ? '${patient.age} years old' : ''}',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Vitals & Location Row
              _buildVitalsLocationRow(context, patient),
              const SizedBox(height: 12),
              
              // Medical Information Sections
              if (patient.conditions.isNotEmpty)
                _buildInfoSection(context,
                  title: 'Conditions',
                  icon: Icons.monitor_heart_outlined,
                  items: patient.conditions
                ),
                
              if (patient.otherConditions != null && patient.otherConditions!.isNotEmpty)
                _buildInfoSection(context,
                  title: 'Other Conditions',
                  icon: Icons.help_outline_rounded,
                  items: [patient.otherConditions!]
                ),
              
              if (patient.surgicalHistory != null && patient.surgicalHistory!.toLowerCase() != 'none')
                _buildInfoSection(context,
                  title: 'Surgical History',
                  icon: Icons.content_cut_rounded,
                  items: [patient.surgicalHistory!]
                ),
                
              if (patient.medications != null && patient.medications!.toLowerCase() != 'none')
                _buildInfoSection(context,
                  title: 'Current Medications',
                  icon: Icons.medication_outlined,
                  items: [patient.medications!]
                ),
              
              if (patient.allergies != null && patient.allergies!.toLowerCase() != 'none')
                _buildInfoSection(context,
                  title: 'Reported Allergies',
                  icon: Icons.warning_amber_rounded,
                  items: [patient.allergies!],
                  useErrorColor: true
                ),
                
              if (patient.documents.isNotEmpty)
                _buildInfoSection(context,
                  title: 'Uploaded Documents',
                  icon: Icons.attach_file_outlined,
                  isDocumentList: true,
                  documentItems: patient.documents
                ),
            ],
          ),
        ),
      ),
    );
  }
  
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
  
  Widget _buildInfoSection(BuildContext context, {
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
                      // Handle document click - implementation not shown for brevity
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
          
          // Grid view for images
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