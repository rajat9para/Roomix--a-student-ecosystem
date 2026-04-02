import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:roomix/providers/utility_provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:shimmer/shimmer.dart';
import 'package:roomix/widgets/bookmark_button.dart';

class UtilityDetailScreen extends StatefulWidget {
  final String utilityId;

  const UtilityDetailScreen({
    super.key,
    required this.utilityId,
  });

  @override
  State<UtilityDetailScreen> createState() => _UtilityDetailScreenState();
}

class _UtilityDetailScreenState extends State<UtilityDetailScreen> {
  late TextEditingController _ratingController;
  late TextEditingController _commentController;
  int? _selectedRating;

  @override
  void initState() {
    super.initState();
    _ratingController = TextEditingController();
    _commentController = TextEditingController();

    Future.microtask(() {
      Provider.of<UtilityProvider>(context, listen: false)
          .getUtility(widget.utilityId);
    });
  }

  @override
  void dispose() {
    _ratingController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _submitReview() {
    if (_selectedRating == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    Provider.of<UtilityProvider>(context, listen: false)
        .addReview(
          widget.utilityId,
          rating: _selectedRating!,
          comment: _commentController.text.isNotEmpty
              ? _commentController.text
              : null,
        )
        .then((_) {
          _selectedRating = null;
          _commentController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review submitted!')),
          );
        })
        .catchError((e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UtilityProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Utility Details'),
            ),
            body: _buildShimmer(),
          );
        }

        final utility = provider.selectedUtility;
        if (utility == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Utility Details'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Utility not found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Utility Details'),
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black87,
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: BookmarkButton(
                  itemId: utility.id,
                  type: 'utility',
                  itemTitle: utility.name,
                  itemImage: utility.image,
                  rating: utility.rating,
                  metadata: {
                    'category': utility.category,
                    'location': utility.address ?? '',
                    'verified': utility.verified,
                  },
                ),
              ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image or placeholder
                  Container(
                    height: 250,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: utility.image != null
                        ? Image.network(
                            utility.image!,
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.location_on,
                            size: 80,
                            color: Colors.grey[600],
                          ),
                  ),

                  // Utility info
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and verification
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    utility.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryAccent
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      utility.category.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (utility.verified)
                              const Tooltip(
                                message: 'Verified',
                                child: Icon(
                                  Icons.verified_user,
                                  color: Colors.green,
                                  size: 28,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Rating
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 24,
                              color: Colors.amber[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              utility.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${utility.reviews.length} reviews)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Description
                        if (utility.description != null) ...[
                          Text(
                            'About',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            utility.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Address
                        if (utility.address != null) ...[
                          _buildInfoRow(
                            icon: Icons.location_on,
                            title: 'Address',
                            value: utility.address!,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Contact information
                        if (utility.contact != null &&
                            (utility.contact!['phone'] != null ||
                                utility.contact!['email'] != null ||
                                utility.contact!['website'] != null)) ...[
                          Text(
                            'Contact',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (utility.contact!['phone'] != null)
                            GestureDetector(
                              onTap: () =>
                                  _launchUrl('tel:${utility.contact!['phone']}'),
                              child: _buildInfoRow(
                                icon: Icons.phone,
                                title: 'Phone',
                                value: utility.contact!['phone'],
                                isClickable: true,
                              ),
                            ),
                          if (utility.contact!['email'] != null)
                            GestureDetector(
                              onTap: () =>
                                  _launchUrl('mailto:${utility.contact!['email']}'),
                              child: _buildInfoRow(
                                icon: Icons.email,
                                title: 'Email',
                                value: utility.contact!['email'],
                                isClickable: true,
                              ),
                            ),
                          if (utility.contact!['website'] != null)
                            GestureDetector(
                              onTap: () => _launchUrl(utility.contact!['website']),
                              child: _buildInfoRow(
                                icon: Icons.language,
                                title: 'Website',
                                value: utility.contact!['website'],
                                isClickable: true,
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],

                        // Divider
                        Divider(color: Colors.grey[300]),
                        const SizedBox(height: 16),

                        // Reviews section
                        Text(
                          'Reviews',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Add review form
                        _buildReviewForm(),
                        const SizedBox(height: 16),

                        // Reviews list
                        if (utility.reviews.isEmpty)
                          Center(
                            child: Text(
                              'No reviews yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          )
                        else
                          Column(
                            children: utility.reviews
                                .map((review) => _buildReviewCard(review))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    bool isClickable = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isClickable ? Colors.blue : Colors.black87,
                  decoration:
                      isClickable ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewForm() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Your Review',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Rating selector
          Text(
            'Rating',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (index) => GestureDetector(
                onTap: () => setState(() => _selectedRating = index + 1),
                child: Icon(
                  Icons.star,
                  size: 28,
                  color: _selectedRating != null && _selectedRating! > index
                      ? Colors.amber[700]
                      : Colors.grey[300],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Comment field
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Share your experience...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 12),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'Submit Review',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(dynamic review) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.userName ?? 'Anonymous',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    Icons.star,
                    size: 14,
                    color: index < review.rating
                        ? Colors.amber[700]
                        : Colors.grey[300],
                  ),
                ),
              ),
            ],
          ),
          if (review.comment != null) ...[
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 250,
              color: Colors.white,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(
                  5,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      height: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
