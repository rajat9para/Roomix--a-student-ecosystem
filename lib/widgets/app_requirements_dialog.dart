import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/services/telegram_service.dart';
import 'package:roomix/services/maps_navigation_service.dart';

/// App Requirements Dialog
/// Shows a dialog on first launch informing users about required apps
class AppRequirementsDialog {
  static const String _shownKey = 'app_requirements_shown';

  /// Check if requirements dialog has been shown before
  static Future<bool> hasBeenShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_shownKey) ?? false;
  }

  /// Mark the dialog as shown
  static Future<void> markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shownKey, true);
  }

  /// Show the requirements dialog if not shown before
  /// Returns true if dialog was shown, false if already shown before
  static Future<bool> showIfNotShown(BuildContext context) async {
    if (await hasBeenShown()) {
      return false;
    }

    if (context.mounted) {
      await show(context);
      return true;
    }
    return false;
  }

  /// Show the requirements dialog
  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _AppRequirementsDialogContent(),
    );
    await markAsShown();
  }
}

class _AppRequirementsDialogContent extends StatefulWidget {
  const _AppRequirementsDialogContent();

  @override
  State<_AppRequirementsDialogContent> createState() => _AppRequirementsDialogContentState();
}

class _AppRequirementsDialogContentState extends State<_AppRequirementsDialogContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildHeader(),
                
                const SizedBox(height: 24),
                
                // Telegram Section
                _buildAppSection(
                  icon: Icons.send,
                  title: 'Telegram',
                  description: 'Contact PG owners and mess providers directly',
                  color: const Color(0xFF0088CC),
                  onInstall: TelegramService.openTelegramInstallPage,
                ),
                
                const SizedBox(height: 16),
                
                // Google Maps Section
                _buildAppSection(
                  icon: Icons.map_outlined,
                  title: 'Google Maps',
                  description: 'Get directions to PGs and mess locations',
                  color: AppColors.primary,
                  onInstall: MapsNavigationService.openGoogleMapsInstallPage,
                ),
                
                const SizedBox(height: 24),
                
                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  'You can install these apps later from the app store',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.apps,
            size: 48,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Recommended Apps',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'For the best experience, we recommend installing these apps:',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textGray,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAppSection({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onInstall,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onInstall,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.download,
                    size: 16,
                    color: Colors.white,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Install',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A simpler inline notice widget for showing app requirements
class AppRequirementsNotice extends StatelessWidget {
  final bool showInstallButtons;
  
  const AppRequirementsNotice({
    super.key,
    this.showInstallButtons = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Recommended Apps',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Install Telegram and Google Maps for the best experience:',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textGray,
            ),
          ),
          if (showInstallButtons) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InstallButton(
                    icon: Icons.send,
                    label: 'Telegram',
                    color: const Color(0xFF0088CC),
                    onTap: TelegramService.openTelegramInstallPage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InstallButton(
                    icon: Icons.map_outlined,
                    label: 'Google Maps',
                    color: AppColors.primary,
                    onTap: MapsNavigationService.openGoogleMapsInstallPage,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InstallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _InstallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}