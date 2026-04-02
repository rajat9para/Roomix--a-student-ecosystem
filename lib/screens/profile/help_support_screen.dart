import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roomix/constants/app_colors.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _expandedIndex = -1;
  static const String _supportEmail = 'genzcoder66@gmail.com';
  static const String _supportWhatsAppNumber = '919675306079';

  final List<Map<String, dynamic>> _faqItems = [
    {
      'category': 'Getting Started',
      'icon': Icons.rocket_launch_outlined,
      'questions': [
        {
          'question': 'How do I create an account?',
          'answer':
              'Open Roomix, tap Sign Up, select Student or Owner role, then complete your profile details. You can use email/password or Google sign-in.',
        },
        {
          'question': 'How do I complete my profile properly?',
          'answer':
              'Go to Profile > Account Settings and add your university, course/year (for students), and your Telegram phone number. Telegram contact is required for messaging.',
        },
        {
          'question': 'Why is Telegram asked in account settings?',
          'answer':
              'Roomix uses Telegram as the primary secure contact channel. Buyer-seller and roommate conversations are redirected to the user-linked Telegram contact.',
        },
      ],
    },
    {
      'category': 'Marketplace',
      'icon': Icons.shopping_bag_outlined,
      'questions': [
        {
          'question': 'How do I sell an item?',
          'answer':
              'Go to Market > Sell Item, add title/price/photos, and submit. Buyers can contact you through Telegram using your linked Telegram number.',
        },
        {
          'question': 'Why is seller phone number hidden in item details?',
          'answer':
              'For privacy and safety, item details do not show raw phone numbers. Contact is handled through Telegram redirect only.',
        },
        {
          'question': 'What should I do if Telegram opens wrong chat?',
          'answer':
              'Update your Telegram phone in Account Settings and ensure country code is correct (for example +91XXXXXXXXXX). Then retry from the listing button.',
        },
      ],
    },
    {
      'category': 'Lost & Found',
      'icon': Icons.search_outlined,
      'questions': [
        {
          'question': 'How do I report a lost or found item?',
          'answer':
              'Open Lost & Found, tap Report Lost Item, fill item details, upload image, and submit. Your report appears in the Lost/Found feed and My Reports.',
        },
        {
          'question': 'Can I edit or remove my report?',
          'answer':
              'Yes. Open Lost & Found > My Reports to manage items you posted.',
        },
      ],
    },
    {
      'category': 'Checkout & Notifications',
      'icon': Icons.campaign_outlined,
      'questions': [
        {
          'question': 'What is the Checkout section on home?',
          'answer':
              'Checkout is the admin update feed. Admin posts announcements with image and description, and users can like and comment.',
        },
        {
          'question': 'How do I know when admin posts something new?',
          'answer':
              'A red notification dot appears on the bell icon whenever a new admin Checkout post is published.',
        },
      ],
    },
    {
      'category': 'Account & Security',
      'icon': Icons.security_outlined,
      'questions': [
        {
          'question': 'How do I reset my password?',
          'answer':
              'Use Forgot Password on login, or go to Account Settings > Change Password after signing in.',
        },
        {
          'question': 'How do I delete my account?',
          'answer':
              'Go to Profile > Account Settings > Delete Account. This is permanent and removes your linked data.',
        },
        {
          'question': 'Is admin access protected?',
          'answer':
              'Yes. Admin login uses restricted admin email plus OTP verification and admin-only route checks.',
        },
      ],
    },
    {
      'category': 'Support',
      'icon': Icons.support_agent_outlined,
      'questions': [
        {
          'question': 'How can I contact support quickly?',
          'answer':
              'Use Live Chat to open WhatsApp support or tap Email to open your phone mail app pre-filled with support details.',
        },
        {
          'question': 'What details should I include in support messages?',
          'answer':
              'Share your account email, device model, app section, and screenshots so issues can be resolved faster.',
        },
      ],
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredFaqs(String query) {
    if (query.isEmpty) return _faqItems;

    final filteredItems = <Map<String, dynamic>>[];
    for (final category in _faqItems) {
      final matchingQuestions = (category['questions'] as List).where((q) {
        final question = (q['question'] as String).toLowerCase();
        final answer = (q['answer'] as String).toLowerCase();
        final searchQuery = query.toLowerCase();
        return question.contains(searchQuery) || answer.contains(searchQuery);
      }).toList();

      if (matchingQuestions.isNotEmpty) {
        filteredItems.add({
          ...category,
          'questions': matchingQuestions,
        });
      }
    }
    return filteredItems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Search Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search for help...',
                        hintStyle: const TextStyle(
                          color: AppColors.textGray,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppColors.textGray),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Quick Actions
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.chat_bubble_outline,
                      title: 'Live Chat',
                      subtitle: 'WhatsApp Support',
                      onTap: () => _launchWhatsApp(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      subtitle: _supportEmail,
                      onTap: () => _launchEmail(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // FAQ Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._buildFaqList(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Contact Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contact Us',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildContactItem(
                    icon: Icons.email_outlined,
                    title: 'Email Support',
                    subtitle: _supportEmail,
                    onTap: () => _launchEmail(),
                  ),
                  Divider(height: 24, color: AppColors.border.withOpacity(0.5)),
                  _buildContactItem(
                    icon: Icons.chat_outlined,
                    title: 'Live Chat (WhatsApp)',
                    subtitle: '+91 9675306079',
                    onTap: () => _launchWhatsApp(),
                  ),
                  Divider(height: 24, color: AppColors.border.withOpacity(0.5)),
                  _buildContactItem(
                    icon: Icons.language_outlined,
                    title: 'Website',
                    subtitle: 'www.roomix.in',
                    onTap: () => _launchWebsite(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Social Media Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border.withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Follow Us',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialButton(
                        icon: Icons.facebook,
                        onTap: () => _showComingSoonDialog('Facebook'),
                      ),
                      _buildSocialButton(
                        icon: Icons.camera_alt_outlined,
                        onTap: () => _showComingSoonDialog('Instagram'),
                      ),
                      _buildSocialButton(
                        icon: Icons.alternate_email,
                        onTap: () => _showComingSoonDialog('Twitter'),
                      ),
                      _buildSocialButton(
                        icon: Icons.play_circle_outline,
                        onTap: () => _showComingSoonDialog('YouTube'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // App Version
            Center(
              child: Text(
                'Roomix v2.4.0',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGray.withOpacity(0.5),
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFaqList() {
    final filteredFaqs = _getFilteredFaqs(_searchController.text);

    if (filteredFaqs.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: AppColors.textGray.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'No results found',
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return filteredFaqs.map((category) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                category['icon'] as IconData,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                category['category'] as String,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...(category['questions'] as List).asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final globalIndex = _faqItems.indexOf(category) * 100 + index;
            
            return _buildFaqItem(
              question: question['question'] as String,
              answer: question['answer'] as String,
              index: globalIndex,
            );
          }),
          const SizedBox(height: 8),
        ],
      );
    }).toList();
  }

  Widget _buildFaqItem({
    required String question,
    required String answer,
    required int index,
  }) {
    final isExpanded = _expandedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isExpanded ? AppColors.primary.withOpacity(0.05) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? AppColors.primary.withOpacity(0.2) : AppColors.border.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? -1 : index;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      question,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isExpanded ? FontWeight.w600 : FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                answer,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textGray,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppColors.textGray.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
    );
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'Roomix App Support',
        'body':
            'Hi Rajat,\n\nI need help with:\n\nIssue details:\n- App section:\n- Device:\n- Steps to reproduce:\n\nThanks.',
      },
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app')),
        );
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    final message = Uri.encodeComponent(
      'Hi Rajat, I need support with the Roomix app.',
    );
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$_supportWhatsAppNumber?text=$message',
    );
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp chat')),
        );
      }
    }
  }

  Future<void> _launchWebsite() async {
    final Uri webUri = Uri.parse('https://www.roomix.in');
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open website')),
        );
      }
    }
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          '$feature Coming Soon',
          style: const TextStyle(color: AppColors.textDark),
        ),
        content: Text(
          'We are working hard to bring you this feature. Stay tuned for updates!',
          style: const TextStyle(color: AppColors.textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
