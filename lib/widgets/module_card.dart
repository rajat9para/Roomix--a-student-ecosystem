import 'package:flutter/material.dart';
import 'package:roomix/constants/app_colors.dart';

class ModuleCard extends StatefulWidget {
  final ModuleData module;
  final VoidCallback onTap;
  final int index;

  const ModuleCard({
    super.key,
    required this.module,
    required this.onTap,
    this.index = 0,
  });

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _rotationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _elevationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _colorAnimation = ColorTween(
      begin: Colors.white,
      end: Colors.white,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHoverEnter() {
    setState(() => _isHovered = true);
    _animationController.forward();
  }

  void _onHoverExit() {
    setState(() => _isHovered = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _animationController.forward(),
        onTapUp: (_) => _animationController.reverse(),
        onTapCancel: () => _animationController.reverse(),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _scaleAnimation,
            _elevationAnimation,
            _rotationAnimation,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                      // Enhanced shadow on hover
                      if (_isHovered)
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 30,
                          offset: Offset(0, 20 * _elevationAnimation.value),
                          spreadRadius: 2,
                        ),
                    ],
                    border: Border.all(
                      color: _isHovered
                          ? AppColors.primary.withOpacity(0.4)
                          : AppColors.primary.withOpacity(0.1),
                      width: _isHovered ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Gradient overlay on hover (enhanced)
                      if (_isHovered)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  widget.module.color.withOpacity(0.04),
                                  widget.module.color.withOpacity(0.01),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Main content
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated Icon Container (enhanced)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            width: _isHovered ? 75 : 70,
                            height: _isHovered ? 75 : 70,
                            decoration: BoxDecoration(
                              color: _isHovered
                                  ? widget.module.color.withOpacity(0.18)
                                  : widget.module.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(_isHovered ? 18 : 14),
                              boxShadow: _isHovered
                                  ? [
                                      BoxShadow(
                                        color: widget.module.color.withOpacity(0.15),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: AnimatedScale(
                                scale: _isHovered ? 1.15 : 1.0,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                child: Icon(
                                  widget.module.icon,
                                  size: 36,
                                  color: widget.module.color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Title (with color transition)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: AnimatedDefaultTextStyle(
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _isHovered
                                    ? widget.module.color
                                    : AppColors.textDark,
                                letterSpacing: _isHovered ? 0.3 : 0,
                              ),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              child: Text(
                                widget.module.title,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),

                          // Animated Chevron (enhanced)
                          if (_isHovered) ...[
                            const SizedBox(height: 8),
                            AnimatedOpacity(
                              opacity: _isHovered ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              child: AnimatedSlide(
                                offset: _isHovered
                                    ? const Offset(0.1, 0)
                                    : const Offset(-0.2, 0),
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16,
                                      color: widget.module.color,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Re-export the ModuleData class for convenience
class ModuleData {
  final String title;
  final IconData icon;
  final Widget Function() route;
  final Color color;

  ModuleData({
    required this.title,
    required this.icon,
    required this.route,
    required this.color,
  });
}
