import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:roomix/constants/app_colors.dart';

enum CustomButtonStyle { solid, gradient, glass, outlined }

class CustomButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;
  final Color color;
  final Color? textColor;
  final Color? borderColor;
  final double? width;
  final double? height;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? fontSize;
  final FontWeight? fontWeight;
  final CustomButtonStyle buttonStyle;
  final bool isLoading;
  final Color? gradientStart;
  final Color? gradientEnd;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.color = AppColors.primary,
    this.textColor,
    this.borderColor,
    this.width,
    this.height = 50,
    this.borderRadius = 12,
    this.padding,
    this.fontSize = 16,
    this.fontWeight = FontWeight.bold,
    this.buttonStyle = CustomButtonStyle.solid,
    this.isLoading = false,
    this.gradientStart,
    this.gradientEnd,
    this.icon,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canTap = widget.onPressed != null && !widget.isLoading;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) {
          if (canTap) {
            _controller.forward();
          }
        },
        onTapUp: (_) {
          _controller.reverse();
          if (canTap) {
            widget.onPressed?.call();
          }
        },
        onTapCancel: () {
          _controller.reverse();
        },
        child: SizedBox(
          width: widget.width ?? double.infinity,
          height: widget.height,
          child: _buildButton(),
        ),
      ),
    );
  }

  Widget _buildButton() {
    switch (widget.buttonStyle) {
      case CustomButtonStyle.gradient:
        return _buildGradientButton();
      case CustomButtonStyle.glass:
        return _buildGlassButton();
      case CustomButtonStyle.outlined:
        return _buildOutlinedButton();
      case CustomButtonStyle.solid:
      default:
        return _buildSolidButton();
    }
  }

  Widget _buildButtonContent({required Color textColor}) {
    if (widget.isLoading) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: textColor),
          const SizedBox(width: 8),
        ],
        Text(
          widget.text,
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: widget.fontWeight,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSolidButton() {
    final textColor = widget.textColor ??
        (widget.color == Colors.white ? AppColors.textDark : Colors.white);
    return ElevatedButton(
      onPressed: widget.isLoading ? null : widget.onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.color,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius!),
          side: widget.borderColor != null 
            ? BorderSide(color: widget.borderColor!, width: 1.5) 
            : BorderSide.none,
        ),
        elevation: 3,
        padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 12),
        shadowColor: widget.color.withOpacity(0.35),
      ),
      child: _buildButtonContent(textColor: textColor),
    );
  }

  Widget _buildGradientButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius!),
        gradient: LinearGradient(
          colors: [
            widget.gradientStart ?? AppColors.primary,
            widget.gradientEnd ?? const Color(0xFF3B9AFF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: (widget.gradientStart ?? AppColors.primary).withOpacity(0.4),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isLoading ? null : widget.onPressed,
          borderRadius: BorderRadius.circular(widget.borderRadius!),
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _buildButtonContent(textColor: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius!),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius!),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            color: Colors.white.withOpacity(0.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isLoading ? null : widget.onPressed,
              child: Padding(
                padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: _buildButtonContent(textColor: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius!),
        border: Border.all(
          color: widget.borderColor ?? widget.color,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isLoading ? null : widget.onPressed,
          borderRadius: BorderRadius.circular(widget.borderRadius!),
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _buildButtonContent(textColor: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}
