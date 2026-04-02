import 'package:flutter/material.dart';
import 'package:roomix/models/lost_item_model.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LostItemDetailScreen extends StatelessWidget {
  final LostItemModel item;

  const LostItemDetailScreen({super.key, required this.item});

  Future<void> _contactFinder(String contact) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: contact,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLost = item.status.toLowerCase() == 'lost';
    final primaryColor = isLost ? Colors.red : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      Container(
                        width: double.infinity,
                        height: 300,
                        color: Colors.white,
                        child: item.image != null
                            ? CachedNetworkImage(
                                imageUrl: item.image!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(color: primaryColor),
                                ),
                                errorWidget: (context, url, error) => const Icon(
                                  Icons.image_not_supported,
                                  size: 64,
                                  color: AppColors.textGray,
                                ),
                              )
                            : Icon(
                                Icons.image,
                                size: 100,
                                color: AppColors.textGray.withOpacity(0.5),
                              ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: primaryColor.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    item.status,
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Info Row
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 20, color: AppColors.textGray),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.location ?? 'Unknown location',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 20, color: AppColors.textGray),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('MMMM dd, yyyy').format(item.date),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textDark,
                                  ),
                                ),
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
                              item.description,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textGray,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Claim Status
                            if (item.claimStatus != 'Unclaimed')
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: item.claimStatus == 'Resolved' 
                                      ? Colors.green.withOpacity(0.1) 
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: item.claimStatus == 'Resolved' 
                                        ? Colors.green.withOpacity(0.3) 
                                        : Colors.orange.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      item.claimStatus == 'Resolved' ? Icons.check_circle : Icons.pending,
                                      color: item.claimStatus == 'Resolved' ? Colors.green : Colors.orange,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Status: ${item.claimStatus}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: item.claimStatus == 'Resolved' ? Colors.green[700] : Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Bottom Bar
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
                    onPressed: () => _contactFinder(item.contact),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: Text(
                      isLost ? 'Contact Reporter' : 'Contact Finder',
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
}
