import 'package:flutter/material.dart';
import 'package:roomix/models/market_item_model.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/widgets/bookmark_button.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:roomix/services/telegram_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ItemDetailScreen extends StatefulWidget {
  final MarketItemModel item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  int _currentImageIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<Map<String, String?>> _resolveSellerTelegramTarget() async {
    String? phone;

    final sellerId = widget.item.sellerId?.trim();
    if (sellerId != null && sellerId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(sellerId)
            .get(const GetOptions(source: Source.serverAndCache));
        if (doc.exists) {
          final data = doc.data();
          phone = TelegramService.extractPhoneFromUserData(data);
        }
      } catch (e) {
        debugPrint('ItemDetail: seller profile lookup failed: $e');
      }
    }

    // Backward compatibility for older listings.
    final legacyContact = widget.item.sellerContact.trim();
    if ((phone == null || phone.isEmpty) && legacyContact.isNotEmpty) {
      if (TelegramService.isValidPhone(legacyContact)) {
        phone = legacyContact;
      }
    }

    return {'phone': phone};
  }

  Future<void> _contactViaTelegram(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final buyerName = auth.currentUser?.name.trim();
    final target = await _resolveSellerTelegramTarget();
    final sellerPhone = target['phone'];

    if (sellerPhone == null || sellerPhone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seller Telegram contact is unavailable.'),
          ),
        );
      }
      return;
    }

    final itemLabel = widget.item.allImages.isNotEmpty
        ? 'Photo ${_currentImageIndex + 1}'
        : widget.item.title;
    final intro = buyerName != null && buyerName.isNotEmpty
        ? 'Hi, I am $buyerName.'
        : 'Hi,';
    final message =
        '$intro I am interested in this item ($itemLabel). Could you please provide more details about the product?';

    final launched = await TelegramService.openTelegramSmart(
      context: context,
      phone: sellerPhone,
      selfPhone: auth.currentUser?.telegramPhone,
      message: message,
    );

    if (!mounted) return;

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Telegram. Please install the app.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final images = item.allImages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BookmarkButton(
              itemId: item.id,
              type: 'market',
              itemTitle: item.title,
              itemImage: images.isNotEmpty ? images.first : null,
              itemPrice: item.price,
              metadata: {
                'condition': item.condition,
                'seller': item.sellerName,
                'sold': item.sold,
              },
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Carousel
                      _buildImageCarousel(images),

                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹${item.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Badges
                            Row(
                              children: [
                                _buildBadge(
                                  item.condition,
                                  item.condition == 'New'
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 12),
                                _buildBadge(
                                  item.category ?? 'General',
                                  Colors.blue,
                                ),
                                if (item.sold) ...[
                                  const SizedBox(width: 12),
                                  _buildBadge('SOLD', Colors.red),
                                ],
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Description
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.description ?? 'No description provided.',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textGray,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Seller Info (NO phone number)
                            const Text(
                              'Seller',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary
                                        .withOpacity(0.1),
                                    child: Text(
                                      item.sellerName.isNotEmpty
                                          ? item.sellerName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.sellerName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const Text(
                                          'Contact via Telegram',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: AppColors.textGray,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom — Telegram button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: item.sold
                        ? null
                        : () => _contactViaTelegram(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0088CC),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    label: Text(
                      item.sold ? 'Item Sold' : 'Message on Telegram',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    if (images.isEmpty) {
      return Container(
        width: double.infinity,
        height: 300,
        color: Colors.white,
        child: const Icon(Icons.image, size: 100, color: AppColors.textGray),
      );
    }

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              return Container(
                color: const Color(0xFF1a1a2e),
                child: CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[100],
                    child: const Icon(
                      Icons.broken_image,
                      size: 64,
                      color: AppColors.textGray,
                    ),
                  ),
                ),
              );
            },
          ),
          // Dot indicators
          if (images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (index) {
                  return Container(
                    width: _currentImageIndex == index ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: _currentImageIndex == index
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          // Image counter
          if (images.length > 1)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
