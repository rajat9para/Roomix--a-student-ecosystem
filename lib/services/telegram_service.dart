import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

/// Telegram Service for Roomix
/// Handles Telegram deep links via phone number for real-world usability
class TelegramService {
  static final TelegramService _instance = TelegramService._internal();
  factory TelegramService() => _instance;
  TelegramService._internal();

  /// Telegram Play Store URL
  static const String _telegramPlayStore =
      'https://play.google.com/store/apps/details?id=org.telegram.messenger';

  /// Telegram App Store URL
  static const String _telegramAppStore =
      'https://apps.apple.com/app/telegram-messenger/id686449807';

  static String? _readString(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final raw = data[key];
      if (raw == null) continue;
      final value = raw.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static String _digitsOnly(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }

  static String? _normalizePhoneDigits(String phone) {
    var digits = _digitsOnly(phone);
    if (digits.isEmpty) return null;

    // Support common formats: 00-country code, 0-local number, or plain local.
    if (digits.startsWith('00') && digits.length > 2) {
      digits = digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length == 10) {
      digits = '91$digits';
    }

    if (digits.length < 10 || digits.length > 15) {
      return null;
    }
    return digits;
  }

  static bool _isSamePhone(String first, String second) {
    final firstDigits = _normalizePhoneDigits(first);
    final secondDigits = _normalizePhoneDigits(second);
    if (firstDigits == null || secondDigits == null) {
      return false;
    }
    return firstDigits == secondDigits;
  }

  /// Reads telegram phone from common field variants and validates it.
  static String? extractPhoneFromUserData(Map<String, dynamic>? data) {
    final raw = _readString(data, const [
      'telegramPhone',
      'telegram_phone',
      'telegramNumber',
      'telegram_number',
      'telegramNo',
      'telegram_no',
      'telegramContact',
      'telegram_contact',
      'telegram',
      // Legacy: also check telegramUsername (may contain phone in old data)
      'telegramUsername',
      'telegram_username',
    ]);
    if (raw == null) return null;
    return isValidPhone(raw) ? formatPhone(raw) : null;
  }

  /// Open Telegram chat with a phone number
  /// Uses tg://resolve?phone= deeplink → Android intent → install prompt
  static Future<bool> openTelegramChat({
    required BuildContext context,
    required String phone,
    String? message,
    bool showInstallPrompt = true,
  }) async {
    final phoneDigits = _normalizePhoneDigits(phone);
    if (phoneDigits == null) {
      debugPrint('TelegramService: Invalid phone -> "$phone"');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('This number is invalid.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    }

    final messageText = message?.trim();
    debugPrint('TelegramService: Opening chat with +$phoneDigits');

    // Correct deep link: tg://resolve?phone= (NOT tg://openmessage)
    final appQuery = <String, String>{'phone': phoneDigits};
    if (messageText != null && messageText.isNotEmpty) {
      appQuery['text'] = messageText;
    }
    final appUri = Uri(
      scheme: 'tg',
      host: 'resolve',
      queryParameters: appQuery,
    );
    // Android intent fallback (forces Telegram app, not browser)
    final intentUri = Uri.parse(
      'intent://resolve?phone=$phoneDigits#Intent;scheme=tg;package=org.telegram.messenger;end',
    );

    try {
      // 1. Try Telegram app deeplinks first — opens chat with the phone number
      for (final uri in [appUri]) {
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        } catch (_) {
          debugPrint('TelegramService: Deep link failed for $uri');
        }
      }

      // 2. Try Android intent (forces installed app over browser)
      try {
        final launched = await launchUrl(
          intentUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (_) {
        debugPrint(
          'TelegramService: Android intent failed (may not be Android)',
        );
      }

      // 3. Telegram not installed — show install prompt
      if (showInstallPrompt && context.mounted) {
        _showInstallPromptDialog(context);
      }

      return false;
    } catch (e) {
      debugPrint('TelegramService: Error opening Telegram: $e');
      if (showInstallPrompt && context.mounted) {
        _showInstallPromptDialog(context);
      }
      return false;
    }
  }

  /// Smart open: opens Telegram chat using phone number
  static Future<bool> openTelegramSmart({
    required BuildContext context,
    String? phone,
    String? username, // Kept for backward compatibility, ignored
    String? selfPhone,
    String? message,
  }) async {
    final phoneInput = phone?.trim() ?? '';

    if (phoneInput.isEmpty) {
      debugPrint('TelegramService: No phone number provided');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No Telegram number available for this user'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    if (!isValidPhone(phoneInput)) {
      debugPrint('TelegramService: Invalid phone: $phoneInput');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('This number is invalid.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    }

    final selfPhoneInput = selfPhone?.trim() ?? '';
    if (selfPhoneInput.isNotEmpty &&
        isValidPhone(selfPhoneInput) &&
        _isSamePhone(phoneInput, selfPhoneInput)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot message your own Telegram profile.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    return openTelegramChat(
      context: context,
      phone: phoneInput,
      message: message,
    );
  }

  /// Open Telegram app directly
  static Future<bool> openTelegramApp() async {
    try {
      final uri = Uri.parse('tg://');
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('TelegramService: Error opening Telegram app: $e');
      return false;
    }
  }

  /// Open Telegram install page on app store
  static Future<bool> openTelegramInstallPage() async {
    try {
      final uri = defaultTargetPlatform == TargetPlatform.iOS
          ? Uri.parse(_telegramAppStore)
          : Uri.parse(_telegramPlayStore);

      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('TelegramService: Error opening install page: $e');
      return false;
    }
  }

  /// Show dialog prompting user to install Telegram
  static void _showInstallPromptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0088CC).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.send, color: Color(0xFF0088CC), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Install Telegram',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Telegram is required to message property owners and roommates.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Install Telegram to:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            _FeatureItem(text: 'Contact PG/Mess owners directly'),
            _FeatureItem(text: 'Message potential roommates'),
            _FeatureItem(text: 'Get quick responses'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              openTelegramInstallPage();
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Install Telegram'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0088CC),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Validate phone number format (international)
  static bool isValidPhone(String phone) {
    if (phone.trim().isEmpty) return false;
    return _normalizePhoneDigits(phone) != null;
  }

  /// Format phone for display
  static String formatPhone(String phone) {
    final normalized = _normalizePhoneDigits(phone);
    if (normalized == null) return phone.trim();
    return '+$normalized';
  }
}

/// Feature item widget for install dialog
class _FeatureItem extends StatelessWidget {
  final String text;

  const _FeatureItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Color(0xFF0088CC)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// Telegram Contact Button Widget
/// A reusable button styled with Telegram branding
class TelegramButton extends StatelessWidget {
  final String? phone;
  final String? message;
  final VoidCallback? onPressed;
  final bool showLabel;
  final bool isOutlined;
  final double? width;

  const TelegramButton({
    super.key,
    this.phone,
    this.message,
    this.onPressed,
    this.showLabel = true,
    this.isOutlined = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone != null && phone!.isNotEmpty;

    if (!hasPhone) {
      return const SizedBox.shrink();
    }

    final buttonChild = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isOutlined
                ? const Color(0xFF0088CC).withOpacity(0.1)
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.send,
            size: 18,
            color: isOutlined ? const Color(0xFF0088CC) : Colors.white,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 10),
          Text(
            'Telegram',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isOutlined ? const Color(0xFF0088CC) : Colors.white,
            ),
          ),
        ],
      ],
    );

    void defaultAction() {
      TelegramService.openTelegramSmart(context: context, phone: phone);
    }

    if (isOutlined) {
      return SizedBox(
        width: width,
        child: OutlinedButton.icon(
          onPressed: onPressed ?? defaultAction,
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF0088CC).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.send, size: 16, color: Color(0xFF0088CC)),
          ),
          label: const Text(
            'Telegram',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0088CC),
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0088CC),
            side: const BorderSide(color: Color(0xFF0088CC), width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: onPressed ?? defaultAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0088CC),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: buttonChild,
      ),
    );
  }
}
