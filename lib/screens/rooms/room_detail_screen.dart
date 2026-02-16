import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:roomix/models/room_model.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/services/api_service.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/utils/smooth_navigation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roomix/widgets/bookmark_button.dart';

class RoomDetailScreen extends StatefulWidget {
  final RoomModel room;

  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  bool _localReviewAdded = false;
  late RoomModel _currentRoom;
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingReview = false;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.room;

  }

  // Future<void> _fetchRoomDetails() async {
  //   setState(() => _isLoadingDetails = true);
  //   try {
  //     final response = await ApiService.dio.get('/rooms/${_currentRoom.id}');
  //     if (response.statusCode == 200) {
  //       setState(() {
  //         _currentRoom = RoomModel.fromJson(response.data);
  //       });
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Failed to load room details: $e')),
  //       );
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isLoadingDetails = false);
  //     }
  //   }
  // }

  Future<void> _submitReview() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to submit a review')),
      );
      return;
    }

    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    final commentText = _commentController.text.trim();
    final ratingValue = _selectedRating;

    setState(() => _isSubmittingReview = true);

    try {
      final response = await ApiService.dio.post(
        '/rooms/${_currentRoom.id}/reviews',
        data: {
          'rating': ratingValue,
          'comment': commentText.isNotEmpty ? commentText : null,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {

        /// CREATE LOCAL REVIEW (OPTIMISTIC UPDATE)
        final newReview = RoomReview(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: authProvider.currentUser!.id,
          userName: authProvider.currentUser!.name,
          comment: commentText,
          rating: ratingValue.toDouble(),
          createdAt: DateTime.now(),
        );

        setState(() {

          /// 🔥 ensure mutable list (prevents unmodifiable error)
          final List<RoomReview> updatedReviews = List<RoomReview>.from(_currentRoom.reviews);

          /// ADD REVIEW TO TOP
          updatedReviews.insert(0, newReview);

          /// RECALCULATE AVERAGE RATING SAFELY
          double avg = 0;
          if (updatedReviews.isNotEmpty) {
            avg = updatedReviews
                .map((r) => r.rating)
                .reduce((a, b) => a + b) / updatedReviews.length;
          }

          /// UPDATE ROOM MODEL (DO NOT MUTATE ORIGINAL)
          _currentRoom = _currentRoom.copyWith(
            reviews: updatedReviews,
            rating: avg,
          );

          /// RESET FORM
          _selectedRating = 0;
          _commentController.clear();
        });

        /// 🚫 Prevent API refresh from overwriting local review
        _localReviewAdded = true;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
      }
    }catch (e) {
      print("REVIEW ERROR => $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _handleContactOwner() async {
    final Uri phoneUri = Uri.parse('tel:${_currentRoom.contact}');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone dialer')),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
              slivers: [
                // App Bar with Image
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: BookmarkButton(
                        itemId: _currentRoom.id,
                        type: 'room',
                        itemTitle: _currentRoom.title,
                        itemImage: _currentRoom.image,
                        itemPrice: _currentRoom.price,
                        rating: _currentRoom.rating,
                        metadata: {
                          'description': _currentRoom.location,
                          'location': _currentRoom.location,
                          'contact': _currentRoom.contact,
                        },
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: _currentRoom.image,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.background,
                            child: const Center(
                              child: Icon(Icons.image_not_supported,
                                  color: AppColors.textSubtle),
                            ),
                          ),
                        ),
                        if (_currentRoom.verified)
                          Positioned(
                            top: 80,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
                                _currentRoom.title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '₹${_currentRoom.price.toStringAsFixed(0)}/mo',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Location and Type
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 18, color: AppColors.textGray),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${_currentRoom.location} • ${_currentRoom.type}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Rating Summary
                        Row(
                          children: [
                            ...List.generate(5, (index) {
                              return Icon(
                                index < _currentRoom.rating.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 20,
                                color: index < _currentRoom.rating.round()
                                    ? AppColors.secondary
                                    : AppColors.textSubtle,
                              );
                            }),
                            const SizedBox(width: 12),
                            Text(
                              _currentRoom.rating > 0
                                  ? _currentRoom.rating.toStringAsFixed(1)
                                  : 'No ratings',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            if (_currentRoom.reviews.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${_currentRoom.reviews.length} reviews)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Amenities
                        if (_currentRoom.amenities.isNotEmpty) ...[
                          const Text(
                            'Amenities',
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
                            children: _currentRoom.amenities.map((amenity) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  amenity,
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

                        // Contact Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleContactOwner,
                            icon: const Icon(Icons.call, size: 20),
                            label: const Text(
                              'Contact Owner',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
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
                            if (_currentRoom.reviews.isNotEmpty)
                              Text(
                                '${_currentRoom.reviews.length}',
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
                        if (_currentRoom.reviews.isNotEmpty) ...[
                          const Text(
                            'User Reviews',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._currentRoom.reviews.map(
                            (review) => _buildReviewCard(review),
                          ),
                        ] else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                children: [
                                  Icon(Icons.rate_review,
                                      size: 48, color: AppColors.textSubtle),
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
                                    'Be the first to review this room',
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

          if (!isLoggedIn)
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
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                      ),
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
                hintText: 'Share your thoughts about this room...',
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
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

  Widget _buildReviewCard(RoomReview review) {
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
                      child: const Icon(Icons.person, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        review.userName.isNotEmpty ? review.userName : (review.userId.isEmpty ? 'Unknown user' : 'User ${review.userId.length >= 8 ? review.userId.substring(0, 8) : review.userId}'),
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
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            dateStr,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }
}
