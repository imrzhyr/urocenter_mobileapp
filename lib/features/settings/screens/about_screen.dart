import 'package:flutter/material.dart';
import 'package:urocenter/core/theme/theme.dart'; // Assuming theme is here
import 'package:urocenter/core/utils/haptic_utils.dart'; // Import HapticUtils
import 'package:go_router/go_router.dart'; // Import GoRouter for context.pop()

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About UroCenter'), // TODO: Localize
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios), // Color inherited from foregroundColor/iconTheme
          onPressed: () {
            HapticUtils.lightTap(); 
            context.pop();
          },
        ),
      ),
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Our Mission'), // TODO: Localize
            _buildParagraph(
              context,
              'To provide compassionate, comprehensive, and cutting-edge urological care to our community. We are dedicated to improving the quality of life for our patients through personalized treatment plans, advanced technology, and a patient-centered approach.'
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(context, 'Our Vision'), // TODO: Localize
            _buildParagraph(
              context,
              'To be the leading urology center in the region, recognized for clinical excellence, innovative research, and exceptional patient experiences. We strive to set the standard for urological health and wellness.'
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(context, 'Our Values'), // TODO: Localize
            _buildValueItem(context, Icons.favorite_border, 'Compassion', 'We treat every patient with empathy, respect, and understanding.'),
            _buildValueItem(context, Icons.verified_user_outlined, 'Integrity', 'We uphold the highest ethical standards in all our interactions.'),
            _buildValueItem(context, Icons.star_border, 'Excellence', 'We are committed to continuous learning and providing the highest quality of care.'),
            _buildValueItem(context, Icons.groups_outlined, 'Teamwork', 'We collaborate effectively to ensure the best outcomes for our patients.'),
            _buildValueItem(context, Icons.lightbulb_outline, 'Innovation', 'We embrace new technologies and research to advance urological treatments.'),
            const SizedBox(height: 24),

            _buildSectionTitle(context, 'Our Services'), // TODO: Localize
            _buildParagraph(
              context,
              'UroCenter offers a wide range of diagnostic and therapeutic services for various urological conditions, including kidney stones, prostate health, incontinence, urologic cancers, male infertility, and more. Our team utilizes state-of-the-art equipment and minimally invasive techniques whenever possible.'
            ),
            const SizedBox(height: 24),
             _buildSectionTitle(context, 'Contact Us'), // TODO: Localize
             _buildParagraph(
               context,
               'For appointments or inquiries, please contact us at [Phone Number] or visit our website at [Website Address]. Our clinic is located at [Clinic Address].' // TODO: Replace placeholders
             ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        height: 1.5, // Improved line spacing
        color: AppColors.textPrimary,
      ),
      textAlign: TextAlign.justify,
    );
  }

  Widget _buildValueItem(BuildContext context, IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
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