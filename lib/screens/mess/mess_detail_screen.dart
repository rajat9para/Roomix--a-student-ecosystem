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

class MessDetailScreen extends StatefulWidget {
  final MessModel mess;

  const MessDetailScreen({super.key, required this.mess});

  @override
  State<MessDetailScreen> createState() => _MessDetailScreenState();
}

class _MessDetailScreenState extends State<MessDetailScreen> {
  late MessModel _currentMess;
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingReview = false;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _currentMess = widget.mess;
    _fetchMessDetails();
  }

  Future<void> _fetchMessDetails() async {
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

    setState(() => _isSubmittingReview = true);
    try {
      final response = await ApiService.dio.post(
        '/mess/${_currentMess.id}/reviews',
        data: {
          'rating': _selectedRating,
          'comment': _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
        _selectedRating = 0;
        _commentController.clear();
        await _fetchMessDetails();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit review: $e')),
      );
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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoadingDetails
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // App Bar with Image
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
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
                          'description': _currentMess.specialization ?? _currentMess.menuPreview ?? '',
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
                        _currentMess.image != null && _currentMess.image!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _currentMess.image!,
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
                              )
                            : Container(
                                color: AppColors.background,
                                child: const Center(
                                  child: Icon(Icons.restaurant,
                                      size: 64, color: AppColors.textSubtle),
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
                                  horizontal: 16, vertical: 8),
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
                        const SizedBox(height: 12),

                        // Address
                        if (_currentMess.address != null &&
                            _currentMess.address!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 18, color: AppColors.textGray),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _currentMess.address!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textGray,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (_currentMess.address != null) const SizedBox(height: 12),

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
                              const Icon(Icons.access_time,
                                  size: 18, color: AppColors.textGray),
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
                                    horizontal: 14, vertical: 8),
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

                        // Contact Button
                        if (_currentMess.contact != null &&
                            _currentMess.contact!.isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _handleContactMess,
                              icon: const Icon(Icons.call, size: 20),
                              label: const Text(
                                'Contact Mess',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
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
