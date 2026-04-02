import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/providers/auth_provider.dart';

class UtilitiesHubScreen extends StatelessWidget {
  const UtilitiesHubScreen({super.key});

  static const List<Map<String, dynamic>> _categories = [
    {
      'icon': Icons.fitness_center,
      'label': 'Gym',
      'query': 'gym',
      'gradient': [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
      'emoji': '🏋️',
    },
    {
      'icon': Icons.local_grocery_store,
      'label': 'Grocery',
      'query': 'grocery store',
      'gradient': [Color(0xFF4ECDC4), Color(0xFF2ECC71)],
      'emoji': '🛒',
    },
    {
      'icon': Icons.local_pharmacy,
      'label': 'Medical',
      'query': 'medical shop pharmacy',
      'gradient': [Color(0xFF45B7D1), Color(0xFF2980B9)],
      'emoji': '💊',
    },
    {
      'icon': Icons.fastfood,
      'label': 'Fast Food',
      'query': 'fast food restaurant',
      'gradient': [Color(0xFFFFA502), Color(0xFFFF6348)],
      'emoji': '🍔',
    },
    {
      'icon': Icons.coffee,
      'label': 'Cafes',
      'query': 'cafe coffee shop',
      'gradient': [Color(0xFFA29BFE), Color(0xFF6C5CE7)],
      'emoji': '☕',
    },
    {
      'icon': Icons.edit_note,
      'label': 'Stationery',
      'query': 'stationery shop',
      'gradient': [Color(0xFFFD79A8), Color(0xFFE84393)],
      'emoji': '✏️',
    },
    {
      'icon': Icons.print,
      'label': 'Photocopy',
      'query': 'photocopy xerox shop',
      'gradient': [Color(0xFF636E72), Color(0xFF2D3436)],
      'emoji': '📄',
    },
    {
      'icon': Icons.sports_esports,
      'label': 'Gaming',
      'query': 'gaming center gaming zone',
      'gradient': [Color(0xFF00CEC9), Color(0xFF0984E3)],
      'emoji': '🎮',
    },
    {
      'icon': Icons.smartphone,
      'label': 'Mobile Shop',
      'query': 'mobile phone shop',
      'gradient': [Color(0xFFDFE6E9), Color(0xFF636E72)],
      'emoji': '📱',
    },
    {
      'icon': Icons.checkroom,
      'label': 'Footwear',
      'query': 'footwear shoe shop',
      'gradient': [Color(0xFFE17055), Color(0xFFD63031)],
      'emoji': '👟',
    },
    {
      'icon': Icons.local_laundry_service,
      'label': 'Laundry',
      'query': 'laundry dry cleaning',
      'gradient': [Color(0xFF74B9FF), Color(0xFF0984E3)],
      'emoji': '🧺',
    },
    {
      'icon': Icons.content_cut,
      'label': 'Salon',
      'query': 'salon barber shop',
      'gradient': [Color(0xFFFAB1A0), Color(0xFFE17055)],
      'emoji': '💇',
    },
  ];

  void _openGoogleMaps(BuildContext context, String query) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final university = auth.currentUser?.university ?? '';
    
    if (university.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set your university in Profile → Account Settings first'),
          backgroundColor: Color(0xFFE74C3C),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    final searchQuery = '$query near $university';
    final encodedQuery = Uri.encodeComponent(searchQuery);
    final url = Uri.parse('https://www.google.com/maps/search/$encodedQuery');

    try {
      // Try launching directly (fallback works better on some devices)
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Fallback: try in-app browser
      try {
        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      } catch (e2) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open maps: $e2')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Utilities',
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
      body: Column(
        children: [
          // Header info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Find utilities near your college',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Consumer<AuthProvider>(
                        builder: (_, auth, __) => Text(
                          auth.currentUser?.university ?? 'Set your university in profile',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Grid of utilities
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  return _buildUtilityCard(context, cat);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityCard(BuildContext context, Map<String, dynamic> cat) {
    final gradientColors = cat['gradient'] as List<Color>;

    return GestureDetector(
      onTap: () => _openGoogleMaps(context, cat['query'] as String),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with gradient background
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  cat['emoji'] as String,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              cat['label'] as String,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.near_me, size: 10, color: AppColors.textGray.withOpacity(0.5)),
                const SizedBox(width: 2),
                Text(
                  'Maps',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textGray.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
