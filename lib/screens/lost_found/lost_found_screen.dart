import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/providers/lost_found_provider.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/models/lost_item_model.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/widgets/loading_indicator.dart';
import 'package:roomix/screens/lost_found/report_item_screen.dart';
import 'package:roomix/screens/lost_found/lost_item_detail_screen.dart';
import 'package:roomix/utils/smooth_navigation.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);

    // Initial fetch
    Future.microtask(() {
      final provider = Provider.of<LostFoundProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      provider.setCurrentUserId(authProvider.currentUser?.id);
      provider.fetchItems();
      provider.setTab('Lost'); // Default
    });
  }

  void _handleTabSelection() {
    // Rebuild FAB on every tab animation frame change
    setState(() {});

    if (_tabController.indexIsChanging) {
      final provider = Provider.of<LostFoundProvider>(context, listen: false);
      switch (_tabController.index) {
        case 0:
          provider.setTab('Lost');
          break;
        case 1:
          provider.setTab('Found');
          break;
        case 2:
          provider.setTab('My Reports');
          break;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Lost & Found',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Lost'),
            Tab(text: 'Found'),
            Tab(text: 'My Reports'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  Provider.of<LostFoundProvider>(
                    context,
                    listen: false,
                  ).setSearchQuery(val);
                  setState(() {}); // rebuild for clear icon
                },
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  hintStyle: const TextStyle(color: AppColors.textGray),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textGray,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppColors.textGray,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            Provider.of<LostFoundProvider>(
                              context,
                              listen: false,
                            ).setSearchQuery('');
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: Consumer<LostFoundProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const LoadingIndicator();
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Something went wrong',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.error!,
                          style: const TextStyle(
                            color: AppColors.textGray,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.fetchItems(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.filteredItems.isEmpty) {
                  return _buildEmptyState(provider.currentTab);
                }

                return RefreshIndicator(
                  onRefresh: () => provider.fetchItems(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: provider.filteredItems.length,
                    itemBuilder: (context, index) {
                      return _buildItemCard(provider.filteredItems[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index < 2
          ? FloatingActionButton.extended(
              onPressed: () {
                SmoothNavigation.push(
                  context,
                  ReportItemScreen(
                    initialType: _tabController.index == 0 ? 'Lost' : 'Found',
                  ),
                );
              },
              backgroundColor: _tabController.index == 0
                  ? Colors.red
                  : Colors.green,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(
                'Report ${_tabController.index == 0 ? "Lost" : "Found"} Item',
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState(String tab) {
    IconData icon;
    String title;
    String subtitle;

    switch (tab) {
      case 'My Reports':
        icon = Icons.assignment_outlined;
        title = 'No reports yet';
        subtitle = 'Items you report as lost or found will appear here.';
        break;
      case 'Found':
        icon = Icons.check_circle_outline;
        title = 'No found items reported';
        subtitle = 'Help others by reporting items you find.';
        break;
      default:
        icon = Icons.search_off;
        title = 'No lost items reported';
        subtitle = 'Great! Only peace of mind here.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppColors.textGray.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: AppColors.textGray),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(LostItemModel item) {
    final isLost = item.status.toLowerCase() == 'lost';
    final statusColor = isLost ? Colors.red : Colors.green;
    final imageHeight = (MediaQuery.of(context).size.width * 0.48)
        .clamp(180.0, 250.0)
        .toDouble();

    return GestureDetector(
      onTap: () {
        SmoothNavigation.push(context, LostItemDetailScreen(item: item));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: AppColors.elevatedCardDecoration,
        child: Column(
          children: [
            // Image Section with Status Overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: item.allImages.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.allImages.first,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[200]),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[100],
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey[400],
                              ),
                            ),
                          )
                        : Container(
                            color: statusColor.withOpacity(0.05),
                            child: Icon(
                              isLost ? Icons.search : Icons.inventory_2,
                              size: 40,
                              color: statusColor.withOpacity(0.3),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      item.status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (item.claimStatus != 'Unclaimed')
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.claimStatus == 'Resolved'
                                ? Icons.check_circle
                                : Icons.pending,
                            size: 14,
                            color: item.claimStatus == 'Resolved'
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.claimStatus,
                            style: TextStyle(
                              color: item.claimStatus == 'Resolved'
                                  ? Colors.green
                                  : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Location and Date
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: AppColors.textGray,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.location ?? 'Unknown location',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.textGray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd').format(item.date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  // View on Map button
                  if (item.location != null && item.location!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final query = Uri.encodeComponent(item.location!);
                            final url =
                                'https://www.google.com/maps/search/?api=1&query=$query';
                            if (await canLaunchUrl(Uri.parse(url))) {
                              await launchUrl(
                                Uri.parse(url),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text('View on Map'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        SmoothNavigation.push(
                          context,
                          LostItemDetailScreen(item: item),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: statusColor,
                        side: BorderSide(color: statusColor.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('View Details'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
