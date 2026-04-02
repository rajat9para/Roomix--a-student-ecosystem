import 'dart:async';
import 'package:flutter/material.dart';
import 'package:roomix/constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _taglineController;
  late AnimationController _cursorController;
  late AnimationController _loadingController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _loadingRotation;
  
  String _displayedText = '';
  final String _fullText = 'Roomix';
  int _currentIndex = 0;
  Timer? _typingTimer;
  bool _showCursor = true;
  bool _isTypingComplete = false;
  bool _showTagline = false;
  bool _showLoading = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
  }

  void _initializeAnimations() {
    // Logo animation controller
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    // Text typing controller
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Tagline fade controller
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    // Cursor blink controller
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    );
    
    // Loading spinner controller
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
    
    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    
    _loadingRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: Curves.linear,
      ),
    );

    // Cursor blink animation
    _cursorController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showCursor = !_showCursor);
        _cursorController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        setState(() => _showCursor = !_showCursor);
        _cursorController.forward();
      }
    });
    
    // Loading rotation
    _loadingController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _loadingController.repeat();
      }
    });
  }

  void _startAnimationSequence() async {
    // Step 1: Animate logo appearing (0-1200ms)
    _logoController.forward();
    
    // Wait for logo animation to complete
    await Future.delayed(const Duration(milliseconds: 1400));
    
    // Check if still mounted
    if (!mounted) return;
    
    // Step 2: Start typewriter effect
    _startTypewriterEffect();
    _cursorController.forward();
    
    // Step 3: After typing completes, show tagline
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    setState(() {
      _isTypingComplete = true;
      _showTagline = true;
    });
    _taglineController.forward();
    
    // Step 4: Show loading animation
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _showLoading = true);
    _loadingController.forward();
    
    // Step 5: Just wait — AuthGate handles navigation automatically
    await Future.delayed(const Duration(milliseconds: 2000));
    // No navigation here — AuthGate is the sole navigator
  }

  void _startTypewriterEffect() {
    _typingTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (_currentIndex < _fullText.length) {
        setState(() {
          _displayedText = _fullText.substring(0, _currentIndex + 1);
          _currentIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _logoController.dispose();
    _textController.dispose();
    _taglineController.dispose();
    _cursorController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background gradient circles
          _buildBackgroundEffects(),
          
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo
                _buildAnimatedLogo(),
                
                const SizedBox(height: 40),
                
                // Typewriter Text
                _buildTypewriterText(),
                
                const SizedBox(height: 20),
                
                // Tagline with fade
                _buildTagline(),
                
                const SizedBox(height: 50),
                
                // Loading indicator
                _buildLoadingIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundEffects() {
    return Stack(
      children: [
        // Top right gradient
        Positioned(
          top: -100,
          right: -100,
          child: AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return Opacity(
                opacity: _logoOpacityAnimation.value * 0.5,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Bottom left gradient
        Positioned(
          bottom: -150,
          left: -100,
          child: AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return Opacity(
                opacity: _logoOpacityAnimation.value * 0.3,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryLight,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Decorative dots
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15,
          left: 40,
          child: _buildDecorativeDot(8, const Duration(milliseconds: 0)),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.25,
          right: 60,
          child: _buildDecorativeDot(6, const Duration(milliseconds: 200)),
        ),
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.25,
          left: 80,
          child: _buildDecorativeDot(10, const Duration(milliseconds: 400)),
        ),
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.15,
          right: 40,
          child: _buildDecorativeDot(5, const Duration(milliseconds: 600)),
        ),
      ],
    );
  }

  Widget _buildDecorativeDot(double size, Duration delay) {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        final delayedValue = _logoController.value > (delay.inMilliseconds / 1200)
            ? (_logoController.value - (delay.inMilliseconds / 1200)) / (1 - (delay.inMilliseconds / 1200))
            : 0.0;
        
        return Opacity(
          opacity: delayedValue.clamp(0.0, 1.0) * 0.6,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Transform.scale(
          scale: _logoScaleAnimation.value,
          child: Opacity(
            opacity: _logoOpacityAnimation.value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.apartment,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypewriterText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Typed text
        Text(
          _displayedText,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            letterSpacing: 2,
          ),
        ),
        
        // Blinking cursor
        if (!_isTypingComplete)
          AnimatedBuilder(
            animation: _cursorController,
            builder: (context, child) {
              return Opacity(
                opacity: _showCursor ? 1.0 : 0.0,
                child: Container(
                  width: 4,
                  height: 50,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTagline() {
    return AnimatedBuilder(
      animation: _taglineController,
      builder: (context, child) {
        return Opacity(
          opacity: _taglineController.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _taglineController.value)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Find Your Perfect Space',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    if (!_showLoading) return const SizedBox(height: 40);
    
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        return Opacity(
          opacity: _loadingController.value.clamp(0.0, 1.0),
          child: SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                RotationTransition(
                  turns: _loadingController,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                        width: 3,
                      ),
                    ),
                  ),
                ),
                
                // Animated arc
                RotationTransition(
                  turns: _loadingRotation,
                  child: CustomPaint(
                    size: const Size(50, 50),
                    painter: ArcPainter(AppColors.primary),
                  ),
                ),
                
                // Center dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Custom painter for animated arc
class ArcPainter extends CustomPainter {
  final Color color;
  
  ArcPainter(this.color);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.0, // Start angle
      2.5, // Sweep angle
      false,
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}