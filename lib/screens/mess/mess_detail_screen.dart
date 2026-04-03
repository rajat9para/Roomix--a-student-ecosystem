import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:roomix/models/mess_model.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/services/api_service.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roomix/widgets/bookmark_button.dart';
import 'package:roomix/screens/messages/chat_detail_screen.dart';
import 'package:roomix/services/maps_navigation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessDetailScreen extends StatefulWidget {
  final MessModel mess;

  const MessDetailScreen({super.key, required this.mess});

  @override
  State<MessDetailScreen> createState() => _MessDetailScreenState();
}

class _MessDetailScreenState extends State<MessDetailScreen> {
  bool _localReviewAdded = false;
  late MessModel _currentMess;
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingReview = false;
  bool _isLoadingDetails = false;

  // Owner info
  String? _ownerTelegramPhone;
  bool _isLoadingOwner = false;

  // Review duplicate check
  bool _hasAlreadyReviewed = false;
  bool _isOwnerViewingOwnListing = false;
  bool _isCheckingReview = true;

  @override
  void initState() {
    super.initState();
    _currentMess = widget.mess;
    _fetchMessDetails();
    _fetchOwnerDetails();
    _loadReviewsFromFirestore();
    _checkIfAlreadyReviewed();
  }

  /// Load reviews from Firestore subcollection
  Future<void> _loadReviewsFromFirestore() async {
    try {
      final reviewMaps = await ApiService.getMessReviews(_currentMess.id);
      final reviews = reviewMaps
          .map((json) => MessReview.fromJson(json))
          .toList();

      if (mounted && !_localReviewAdded) {
        double avg = 0;
        if (reviews.isNotEmpty) {
          avg =
              reviews.map((r) => r.rating).reduce((a, b) => a + b) /
              reviews.length;
        }
        setState(() {
          _currentMess = _currentMess.copyWith(
            reviews: reviews,
            rating: double.parse(avg.toStringAsFixed(1)),
          );
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading mess reviews: $e');
    }
  }

  /// Check if the current user has already reviewed this mess
  Future<void> _checkIfAlreadyReviewed() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      setState(() => _isCheckingReview = false);
      return;
    }
    if (currentUser.id == _currentMess.ownerid) {
      setState(() {
        _isOwnerViewingOwnListing = true;
        _isCheckingReview = false;
      });
      return;
    }
    try {
      final alreadyReviewed = await ApiService.hasUserReviewedMess(
        _currentMess.id,
        currentUser.id,
      );
      if (mounted) {
        setState(() {
          _hasAlreadyReviewed = alreadyReviewed;
          _isOwnerViewingOwnListing = false;
          _isCheckingReview = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error checking mess review status: $e');
      if (mounted) setState(() => _isCheckingReview = false);
    }
  }

  Future<void> _fetchMessDetails() async {
    // Skip re-fetch if a local review was just added (prevents overwriting)
    if (_localReviewAdded) return;

    setState(() => _isLoadingDetails = true);
    try {
      final response = await ApiService.dio.get('/mess/${_currentMess.id}');
      if (response.statusCode == 200) {
        setState(() {
          _currentMess = MessModel.fromJson(response.data);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load mess details: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
    }
  }

  Future<void> _fetchOwnerDetails() async {
    setState(() => _isLoadingOwner = true);

    try {
      final ownerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentMess.ownerid)
          .get(const GetOptions(source: Source.serverAndCache));

      if (ownerDoc.exists) {
        final ownerData = ownerDoc.data()!;
        setState(() {
          _ownerTelegramPhone = ownerData['telegramPhone'] as String? ??
              ownerData['telegram_phone'] as String? ??
              ownerData['phone'] as String?;
        });
      } else {
        final fallback = _currentMess.telegramPhone?.trim();
        if (fallback != null && fallback.isNotEmpty) {
          setState(() {
            _ownerTelegramPhone = fallback;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching owner details: $e');
      final fallback = _currentMess.telegramPhone?.trim();
      if (fallback != null &&
          fallback.isNotEmpty &&
          (_ownerTelegramPhone == null || _ownerTelegramPhone!.isEmpty)) {
        setState(() {
          _ownerTelegramPhone = fallback;
        });
      }
    } finally {
      setState(() => _isLoadingOwner = false);
    }
  }

  Future<void> _submitReview() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to submit a review')),
      );
      return;
    }

    if (_hasAlreadyReviewed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already reviewed this Mess')),
      );
      return;
    }
    if (_isOwnerViewingOwnListing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Owners cannot review their own Mess listing'),
        ),
      );
      return;
    }

    if (_selectedRating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rating')));
      return;
    }

    final commentText = _commentController.text.trim();
    final ratingValue = _selectedRating;

    setState(() => _isSubmittingReview = true);
    try {
      // Persist review to Firestore
      final success = await ApiService.addMessReview(
        messId: _currentMess.id,
        userId: authProvider.currentUser!.id,
        userName: authProvider.currentUser!.name,
        rating: ratingValue.toDouble(),
        comment: commentText,
      );

      if (success) {
        final newReview = MessReview(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: authProvider.currentUser!.id,
          userName: authProvider.currentUser!.name,
          comment: commentText,
          rating: ratingValue.toDouble(),
          createdAt: DateTime.now(),
        );

        setState(() {
          final List<MessReview> updatedReviews = List<MessReview>.from(
            _currentMess.reviews,
          );
          updatedReviews.insert(0, newReview);

          double avg = 0;
          if (updatedReviews.isNotEmpty) {
            avg =
                updatedReviews.map((r) => r.rating).reduce((a, b) => a + b) /
                updatedReviews.length;
          }

          _currentMess = _currentMess.copyWith(
            reviews: updatedReviews,
            rating: avg,
          );

          _selectedRating = 0;
          _commentController.clear();
          _hasAlreadyReviewed = true;
        });

        _localReviewAdded = true;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to submit review. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('REVIEW ERROR => $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReview = false);
      }
    }
  }

  Future<void> _handleContactMess() async {
    if (_currentMess.contact == null || _currentMess.contact!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact information not available')),
      );
      return;
    }

    final Uri phoneUri = Uri.parse('tel:${_currentMess.contact}');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone dialer')),
      );
    }
  }

  /// Handle Telegram contact
  /// Handle in-app chat contact
  Future<void> _handleChatContact() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to message the owner.')),
      );
      return;
    }

    final ownerId = _currentMess.ownerid;
    if (ownerId.isEmpty || ownerId == currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot message this listing.')),
      );
      return;
    }

    // Resolve owner name and photo
    String ownerName = 'Owner';
    String? ownerPhoto;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();
      if (doc.exists) {
        ownerName = doc.data()?['name'] as String? ?? 'Owner';
        ownerPhoto = doc.data()?['profilePicture'] as String?;
      }
    } catch (_) {}

    final name = currentUser.name.trim();
    final intro = name.isNotEmpty ? "Hi, I'm $name." : 'Hi,';
    final message =
        "$intro I'm interested in your mess service '${_currentMess.name}'. Can you share the menu and pricing?";

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          userId: ownerId,
          userName: ownerName,
          userPhoto: ownerPhoto,
          initialMessage: message,
        ),
      ),
    );
  }

  /// Handle Get Directions
  Future<void> _handleGetDirections() async {
    if (!_currentMess.hasCoordinates) {
      _showNoCoordinatesDialog();
      return;
    }

    await MapsNavigationService.openDirectionsWithCurrentLocation(
      context: context,
      destinationLat: _currentMess.latitude!,
      destinationLng: _currentMess.longitude!,
      destinationName: _currentMess.name,
    );
  }

  void _showNoCoordinatesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_off, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Location Not Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exact coordinates for "${_currentMess.name}" are not available.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Address: ${_currentMess.location}',
              style: const TextStyle(fontSize: 13, color: AppColors.textGray),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildDialogOption('Call the owner for directions', Icons.call),
            _buildDialogOption('Search the address in Google Maps', Icons.map),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              MapsNavigationService.openLocation(
                context: context,
                latitude: 28.6139,
                longitude: 77.2090,
                label: _currentMess.location,
              );
            },
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Search in Maps'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogOption(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTelegram = true; // Always show chat button

    return Scaffold(
      body: _isLoadingDetails
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // App Bar with Image
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: BookmarkButton(
                        itemId: _currentMess.id,
                        type: 'mess',
                        itemTitle: _currentMess.name,
                        itemImage: _currentMess.image,
                        itemPrice: _currentMess.price,
                        rating: _currentMess.rating,
                        metadata: {
                          'description':
                              _currentMess.specialization ??
                              _currentMess.menuPreview ??
                              '',
                          'location': _currentMess.address ?? '',
                          'contact': _currentMess.contact ?? '',
                        },
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        _currentMess.image != null &&
                                _currentMess.image!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _currentMess.image!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.background,
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: AppColors.textSubtle,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                decoration: const BoxDecoration(
                                  gradient: AppColors.headerGradient,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.restaurant,
                                    size: 64,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                        // Gradient overlay for readability
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 80,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.4),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Price
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _currentMess.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '₹${_currentMess.price.toStringAsFixed(0)}/mo',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Meals per day and food type info
                        if (_currentMess.mealsPerDay != null ||
                            _currentMess.foodtype.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_currentMess.mealsPerDay != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.success.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '${_currentMess.mealsPerDay} meals/day',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                                if (_currentMess.mealsPerDay != null &&
                                    _currentMess.foodtype.isNotEmpty)
                                  const SizedBox(width: 8),
                                if (_currentMess.foodtype.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _currentMess.foodtype.toLowerCase() == 'veg'
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _currentMess.foodtype.toLowerCase() == 'veg'
                                            ? Colors.green.withOpacity(0.3)
                                            : Colors.orange.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      _currentMess.foodtype.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _currentMess.foodtype.toLowerCase() == 'veg'
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Address with map icon
                        if (_currentMess.address != null &&
                            _currentMess.address!.isNotEmpty)
                          GestureDetector(
                            onTap: _currentMess.hasCoordinates
                                ? _handleGetDirections
                                : null,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 18,
                                  color: _currentMess.hasCoordinates
                                      ? AppColors.primary
                                      : AppColors.textGray,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _currentMess.address!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _currentMess.hasCoordinates
                                          ? AppColors.primary
                                          : AppColors.textGray,
                                      decoration: _currentMess.hasCoordinates
                                          ? TextDecoration.underline
                                          : null,
                                    ),
                                  ),
                                ),
                                if (_currentMess.hasCoordinates)
                                  const Icon(
                                    Icons.directions,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                              ],
                            ),
                          ),
                        if (_currentMess.address != null)
                          const SizedBox(height: 12),

                        // Rating Summary
                        Row(
                          children: [
                            ...List.generate(5, (index) {
                              return Icon(
                                index < _currentMess.rating.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 20,
                                color: index < _currentMess.rating.round()
                                    ? AppColors.secondary
                                    : AppColors.textSubtle,
                              );
                            }),
                            const SizedBox(width: 12),
                            Text(
                              _currentMess.rating > 0
                                  ? _currentMess.rating.toStringAsFixed(1)
                                  : 'No ratings',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            if (_currentMess.reviews.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${_currentMess.reviews.length} reviews)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Timings
                        if (_currentMess.openingTime != null &&
                            _currentMess.closingTime != null) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 18,
                                color: AppColors.textGray,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_currentMess.openingTime} - ${_currentMess.closingTime}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Specialities
                        if (_currentMess.specialities != null &&
                            _currentMess.specialities!.isNotEmpty) ...[
                          const Text(
                            'Specialties',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _currentMess.specialities!.map((spec) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  spec,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Action Buttons
                        _buildActionButtons(hasTelegram),
                        const SizedBox(height: 32),

                        // Reviews Section Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Reviews',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            if (_currentMess.reviews.isNotEmpty)
                              Text(
                                '${_currentMess.reviews.length}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Add Review Form
                        _buildReviewForm(),
                        const SizedBox(height: 32),

                        // Reviews List
                        if (_currentMess.reviews.isNotEmpty) ...[
                          const Text(
                            'User Reviews',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._currentMess.reviews.map(
                            (review) => _buildReviewCard(review),
                          ),
                        ] else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.rate_review,
                                    size: 48,
                                    color: AppColors.textSubtle,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No reviews yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textGray,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Be the first to review this mess',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSubtle,
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildActionButtons(bool hasTelegram) {
    return Column(
      children: [
        // Primary Actions Row - Call and Message
        Row(
          children: [
            // Call Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handleContactMess,
                icon: const Icon(Icons.call, size: 20),
                label: const Text('Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Message Owner Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handleChatContact,
                icon: const Icon(Icons.chat_rounded, size: 20),
                label: const Text('Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Get Directions Button (Full Width)
        SizedBox(
          width: double.infinity,
          child: GetDirectionsButton(
            latitude: _currentMess.latitude ?? 0,
            longitude: _currentMess.longitude ?? 0,
            locationName: _currentMess.name,
            isOutlined: !_currentMess.hasCoordinates,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewForm() {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoggedIn = authProvider.currentUser != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share Your Experience',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),

          // Owner review restriction
          if (_isOwnerViewingOwnListing)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.block, size: 18, color: AppColors.warning),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Owners cannot review their own Mess listing.',
                      style: TextStyle(fontSize: 13, color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
            )
          else if (_hasAlreadyReviewed)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'You have already reviewed this Mess. Thank you!',
                      style: TextStyle(fontSize: 13, color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
            )
          else if (_isCheckingReview)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (!isLoggedIn)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 18, color: Colors.orange[800]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Please login to submit a review',
                      style: TextStyle(fontSize: 13, color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Star Rating Picker
            const Text(
              'Rating',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedRating = index + 1);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      _selectedRating > index ? Icons.star : Icons.star_border,
                      size: 32,
                      color: _selectedRating > index
                          ? AppColors.secondary
                          : AppColors.textSubtle,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Comment TextField
            const Text(
              'Comment (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              enabled: !_isSubmittingReview,
              decoration: InputDecoration(
                hintText: 'Share your thoughts about this mess...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingReview ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.textSubtle,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmittingReview
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Submit Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard(MessReview review) {
    final dateStr = review.createdAt != null
        ? DateFormat('MMM d, yyyy').format(review.createdAt!)
        : 'Recently';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary,
                      child: const Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        review.userName.isNotEmpty
                            ? review.userName
                            : (review.userId.isEmpty
                                  ? 'Unknown user'
                                  : 'User ${review.userId.length >= 8 ? review.userId.substring(0, 8) : review.userId}'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Rating Stars
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: index < review.rating
                        ? AppColors.secondary
                        : AppColors.textSubtle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (review.comment.isNotEmpty) ...[
            Text(
              review.comment,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            dateStr,
            style: const TextStyle(fontSize: 11, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }
}
