import 'package:flutter/material.dart';
import 'package:roomix/constants/app_colors.dart';

class SortChip extends StatelessWidget {
  /// Display text for the chip
  final String label;
  
  /// Icon to display (optional)
  final IconData? icon;
  
  /// Is this chip currently selected/active
  final bool isActive;
  
  /// Callback when chip is tapped
  final VoidCallback onTap;
  
  /// Custom color for the chip
  final Color? activeColor;

  const SortChip({
    Key? key,
    required this.label,
    this.icon,
    required this.isActive,
    required this.onTap,
    this.activeColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activeCol = activeColor ?? const Color(0xFF8B5CF6);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeCol.withOpacity(0.1)
              : Colors.white,
          border: Border.all(
            color: isActive
                ? activeCol
                : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isActive
                    ? activeCol
                    : AppColors.textGray,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? activeCol
                    : AppColors.textGray,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
