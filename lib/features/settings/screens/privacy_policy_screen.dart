import 'package:flutter/material.dart';
import 'package:urocenter/core/theme/theme.dart'; // Assuming theme is here
import 'package:urocenter/core/utils/haptic_utils.dart'; // Import HapticUtils
import 'package:go_router/go_router.dart'; // Import GoRouter for context.pop()

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'), // TODO: Localize
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
             _buildLegalDisclaimer(context), // Reuse disclaimer
             const SizedBox(height: 16),

            _buildSectionTitle(context, '1. Introduction'), // TODO: Localize
            _buildParagraph(
              context,
              'UroCenter ("we", "us", or "our") is committed to protecting the privacy and security of your personal information, including your health information. This Privacy Policy describes how we collect, use, disclose, and protect the information you provide through the UroCenter mobile application (the "App").'
            ),
             _buildParagraph(
              context,
              'By using the App, you consent to the data practices described in this policy. If you do not agree with the data practices described in this policy, you should not use the App.'
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(context, '2. Information We Collect'), // TODO: Localize
            _buildParagraph(
              context,
              'We may collect several types of information from and about users of our App, including:'
            ),
            _buildListItem(context, 'Personal Information:' ,'Such as your name, date of birth, contact information (phone number, email address), and account credentials.'),
            _buildListItem(context, 'Health Information:' , 'Information you provide related to your urological conditions, symptoms, medical history, appointments, communications with healthcare providers via the App, and any documents or images you upload (collectively, "Protected Health Information" or "PHI"). We handle PHI in accordance with applicable health privacy laws (e.g., HIPAA in the US, and relevant laws in your jurisdiction).'),
             _buildListItem(context, 'Usage Information:' , 'Details of your access to and use of the App, including traffic data, logs, communication data, and the resources that you access and use on the App (e.g., feature usage, button taps).'),
             _buildListItem(context, 'Device Information:' , 'Information about your mobile device and internet connection, including the device\'s unique identifier, operating system, browser type, and mobile network information.'),
            const SizedBox(height: 20),
            
            _buildSectionTitle(context, '3. How We Use Your Information'), // TODO: Localize
             _buildParagraph(
              context,
              'We use information that we collect about you or that you provide to us, including any personal information and PHI:'
            ),
             _buildListItem(context, 'To provide App functionality:' ,'To present our App and its contents to you, schedule appointments, facilitate communication (if applicable), and provide information about our services.'),
             _buildListItem(context, 'For treatment purposes:' , 'To provide you with medical care and coordinate your treatment with our healthcare providers.'),
             _buildListItem(context, 'For communication:' , 'To notify you about appointments, provide health reminders, respond to your inquiries, and inform you about changes to our services or policies.'),
             _buildListItem(context, 'For internal operations:' , 'To improve the App, for data analysis, troubleshooting, and security purposes.'),
             _buildListItem(context, 'To fulfill legal obligations:' , 'To comply with applicable laws, regulations, court orders, or governmental requests.'),
            const SizedBox(height: 20),
            
            _buildSectionTitle(context, '4. Disclosure of Your Information'), // TODO: Localize
            _buildParagraph(
              context,
              'We do not sell your personal information or PHI. We may disclose aggregated information about our users, and information that does not identify any individual, without restriction.'
            ),
             _buildParagraph(
              context,
              'We may disclose personal information and PHI that we collect or you provide:'
            ),
            _buildListItem(context, 'To healthcare providers within UroCenter:' , 'For treatment purposes.'),
             _buildListItem(context, 'To contractors and service providers:' , 'To third parties we use to support our business (e.g., hosting providers, technical support) who are bound by contractual obligations to keep information confidential and use it only for the purposes for which we disclose it to them.'),
              _buildListItem(context, 'To comply with the law:' , 'To respond to subpoenas, court orders, or legal process, or to establish or exercise our legal rights or defend against legal claims.'),
               _buildListItem(context, 'With your consent:' , 'For any other purpose disclosed by us when you provide the information or with your explicit consent.'),
            const SizedBox(height: 20),
            
             _buildSectionTitle(context, '5. Data Security'), // TODO: Localize
            _buildParagraph(
              context,
              'We have implemented measures designed to secure your personal information and PHI from accidental loss and from unauthorized access, use, alteration, and disclosure. However, the transmission of information via the internet and mobile platforms is not completely secure. Although we do our best to protect your information, we cannot guarantee the security of your information transmitted through our App.'
            ),
            const SizedBox(height: 20),
            
            _buildSectionTitle(context, '6. Data Retention'), // TODO: Localize
             _buildParagraph(
              context,
              'We will retain your personal information and PHI for as long as necessary to fulfill the purposes outlined in this Privacy Policy, unless a longer retention period is required or permitted by law.'
            ),
            const SizedBox(height: 20),
            
             _buildSectionTitle(context, '7. Your Rights'), // TODO: Localize
              _buildParagraph(
              context,
              'Depending on your jurisdiction, you may have certain rights regarding your personal information and PHI, such as the right to access, correct, or request deletion of your data. Please contact us using the information below to inquire about or exercise these rights.'
            ),
            const SizedBox(height: 20),
            
             _buildSectionTitle(context, '8. Children\'s Privacy'), // Escaped Children's
              _buildParagraph(
              context,
              'Our App is not intended for children under the age of [Specify Age, e.g., 13 or 18 depending on regulations]. We do not knowingly collect personal information from children under [Age]. If we learn we have collected or received personal information from a child under [Age] without verification of parental consent, we will delete that information.'
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(context, '9. Changes to Our Privacy Policy'), // TODO: Localize
            _buildParagraph(
              context,
              'It is our policy to post any changes we make to our privacy policy on this page. If we make material changes to how we treat our users\' personal information or PHI, we will notify you through a notice on the App home screen or by other means. The date the privacy policy was last revised is identified at the top of the page. You are responsible for periodically visiting our App and this privacy policy to check for any changes.' // Escaped users'
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(context, '10. Contact Information'), // TODO: Localize
            _buildParagraph(
              context,
              'To ask questions or comment about this privacy policy and our privacy practices, contact us at: [Contact Email or Phone Number] or [Postal Address].'
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets (Consider moving to a shared file) ---

   Widget _buildLegalDisclaimer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.yellow[100],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.orange.shade200)
      ),
      child: Text(
        'Disclaimer: This is sample text generated by AI. It is NOT a substitute for professional legal advice, especially regarding health information privacy (like HIPAA or local equivalents). Consult with a qualified legal professional.', // TODO: Localize
        style: TextStyle(color: Colors.orange[900], fontSize: 13, fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0), // Added top padding
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0), // Add padding below paragraphs
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: 1.5,
          color: AppColors.textSecondary,
        ),
         textAlign: TextAlign.justify,
      ),
    );
  }

   Widget _buildListItem(BuildContext context, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 10.0), // Indent list items
      child: Row(
         crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           const Padding(
             padding: EdgeInsets.only(top: 5.0, right: 8.0),
             child: Icon(Icons.circle, size: 8, color: AppColors.textSecondary), // Simple bullet point
           ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                children: [
                  TextSpan(text: title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  TextSpan(text: ' $description'),
                ]
              ), 
            ),
          ),
        ],
      ),
    );
  }
  // --- End Helper Widgets ---
} 