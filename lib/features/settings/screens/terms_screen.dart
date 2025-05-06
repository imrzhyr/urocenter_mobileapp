import 'package:flutter/material.dart';
import 'package:urocenter/core/theme/theme.dart'; // Assuming theme is here
import 'package:easy_localization/easy_localization.dart'; // Import for translations
import '../../../core/utils/haptic_utils.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios), // Color inherited from foregroundColor/iconTheme
          onPressed: () {
            HapticUtils.lightTap();
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: Text('settings.terms_conditions'.tr()),
      ),
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegalDisclaimer(context),
            const SizedBox(height: 16),

            _buildSectionTitle(context, 'terms.section_introduction'.tr()),
            _buildParagraph(
              context,
              'terms.introduction_content'.tr(),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(context, 'terms.section_use'.tr()),
            _buildParagraph(
              context,
              'terms.use_content_1'.tr(),
            ),
            _buildParagraph(
              context,
              'terms.use_content_2'.tr(),
            ),
            const SizedBox(height: 20),
            
            // Add other relevant sections as needed, e.g.:
            _buildSectionTitle(context, 'terms.section_accounts'.tr()),
            _buildParagraph(
              context,
              'terms.accounts_content'.tr(),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(context, 'terms.section_intellectual'.tr()),
            _buildParagraph(
              context,
              'terms.intellectual_content'.tr(),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(context, 'terms.section_disclaimers'.tr()),
            _buildParagraph(
              context,
              'terms.disclaimers_content'.tr(),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(context, 'terms.section_liability'.tr()),
            _buildParagraph(
              context,
              'terms.liability_content'.tr(),
            ),
            const SizedBox(height: 20),
            
            _buildSectionTitle(context, 'terms.section_law'.tr()),
            _buildParagraph(
              context,
              'terms.law_content'.tr(),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(context, 'terms.section_changes'.tr()),
            _buildParagraph(
              context,
              'terms.changes_content'.tr(),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(context, 'terms.section_contact'.tr()),
            _buildParagraph(
              context,
              'terms.contact_content'.tr(),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets (Consider moving to a shared file if used elsewhere) ---

   Widget _buildLegalDisclaimer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.yellow[100], 
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.orange.shade200)
      ),
      child: Text(
        'terms.ai_disclaimer'.tr(),
        style: TextStyle(color: Colors.orange[900], fontSize: 13, fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        height: 1.5,
        color: AppColors.textSecondary, // Use secondary for body text here
      ),
       textAlign: TextAlign.justify,
    );
  }
  // --- End Helper Widgets ---
} 