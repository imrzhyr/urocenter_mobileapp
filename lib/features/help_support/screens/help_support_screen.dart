import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_bar_style2.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  late ScrollController _scrollController;

  final List<FAQItem> _faqItems = [
    FAQItem(
      question: 'How do I update my medical history?',
      answer: 'You can update your medical history by navigating to the Medical History section from the dashboard. Tap on the edit button to make changes to your information.',
    ),
    FAQItem(
      question: 'How do I upload documents?',
      answer: 'Go to My Documents from the dashboard. Tap on the "+" button to add new documents. You can take a photo or upload an existing file from your device.',
    ),
    FAQItem(
      question: 'How do I contact my doctor?',
      answer: 'You can initiate a consultation from the home screen by tapping on the "Start Consultation" button or by continuing an existing conversation with Dr. Ali Kamal.',
    ),
    FAQItem(
      question: 'How do I change my password?',
      answer: 'Go to Settings and select "Change Password". You will need to enter your current password and then set a new one.',
    ),
    FAQItem(
      question: 'Is my data secure?',
      answer: 'Yes, all your data is encrypted and securely stored. We follow strict privacy protocols to ensure your medical information remains confidential. You can review our privacy policy for more details.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBarStyle2(
          title: 'help_support.title'.tr(),
          showSearch: false,
          showFilters: false,
          showBackButton: true,
          showActionButtons: false,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(theme),
              const SizedBox(height: 24),
              _buildContactOptions(theme),
              const SizedBox(height: 32),
              _buildFAQSection(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.warning,
            Color(0xFFD97706),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.support_agent,
                size: 36,
                color: Colors.white,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'help_support.we_are_here'.tr(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'help_support.description'.tr(),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withAlpha(230),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOptions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'help_support.contact_us'.tr(),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Card(
            margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildContactTile(
                theme,
                icon: Icons.phone,
                title: 'help_support.call_us'.tr(),
                subtitle: '+964 750 123 4567',
                onTap: () {
                  // Just show a snackbar instead of launching URL
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Calling support...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              Divider(height: 1, color: theme.dividerColor),
              _buildContactTile(
                theme,
                icon: Icons.email,
                title: 'help_support.email_us'.tr(),
                subtitle: 'support@urocenter.com',
                onTap: () {
                  // Just show a snackbar instead of launching URL
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening email...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              Divider(height: 1, color: theme.dividerColor),
              _buildContactTile(
                theme,
                icon: Icons.chat_bubble_outline,
                title: 'help_support.chat_with_us'.tr(),
                subtitle: 'help_support.chat_description'.tr(),
                onTap: () {
                  // Start a support chat
                  HapticUtils.lightTap();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Starting support chat...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticUtils.lightTap();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.colorScheme.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'help_support.faq'.tr(),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Card(
            margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ExpansionPanelList(
            elevation: 0,
            expandedHeaderPadding: EdgeInsets.zero,
            expansionCallback: (index, isExpanded) {
              setState(() {
                for (int i = 0; i < _faqItems.length; i++) {
                  if (i == index) {
                    _faqItems[i].isExpanded = !_faqItems[i].isExpanded;
                  } else {
                    _faqItems[i].isExpanded = false;
                  }
                }
              });
              HapticUtils.lightTap();

              if (_faqItems[index].isExpanded) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                    final key = _faqItems[index].itemKey;
                    final context = key.currentContext;
                    if (context != null && _scrollController.hasClients) {
                      Scrollable.ensureVisible(
                        context,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                        alignment: 0.0, // Align to the top of the viewport
                        // alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart, // Alternative alignment
                    );
                  }
                });
              }
            },
            children: _faqItems.map((FAQItem item) {
              return ExpansionPanel(
                headerBuilder: (BuildContext context, bool isExpanded) {
                    return Container(
                      key: item.itemKey,
                      child: ListTile(
                    title: Text(
                      item.question,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                          ),
                      ),
                    ),
                  );
                },
                body: Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    bottom: 16.0,
                  ),
                  child: Text(
                    item.answer,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                isExpanded: item.isExpanded,
                backgroundColor: theme.colorScheme.surface,
                canTapOnHeader: true,
              );
            }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class FAQItem {
  final String question;
  final String answer;
  bool isExpanded;
  final GlobalKey itemKey = GlobalKey();

  FAQItem({
    required this.question,
    required this.answer,
    this.isExpanded = false,
  });
} 