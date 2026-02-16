import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/models/map_marker_model.dart';
import 'package:roomix/providers/map_provider.dart';
import 'package:roomix/providers/user_preferences_provider.dart';
import 'package:roomix/services/map_service.dart';
import 'package:roomix/screens/settings/map_settings_screen.dart';
import 'package:roomix/utils/smooth_navigation.dart';

class CampusMapScreen extends StatefulWidget {
  final List<MapMarkerModel>? initialMarkers;
  final MarkerCategory? filterCategory;

  const CampusMapScreen({
    super.key,
    this.initialMarkers,
    this.filterCategory,
  });

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late AnimationController _animationController;
  bool _showFilters = false;
  bool _showMarkerDetails = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize map provider with markers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prefs = context.read<UserPreferencesProvider>();
      final lat = prefs.campusLat;
      final lng = prefs.campusLng;
      if (lat != null && lng != null) {
        context.read<MapProvider>().updateMapView(lat, lng, 15);
      }
      if (widget.initialMarkers != null) {
        context.read<MapProvider>().addMarkers(widget.initialMarkers!);
      }
      if (widget.filterCategory != null) {
        final provider = context.read<MapProvider>();
        provider.resetView();
        provider.setCategories({widget.filterCategory!});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
        ),
        title: const Text(
          'Campus Map',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapSettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map background
          _buildMapBackground(),

          // Search bar
          _buildSearchBar(),

          // Filter chips
          _buildFilterChips(),

          // Map markers
          _buildMapMarkers(),

          // Bottom sheet for marker details
          if (_showMarkerDetails) _buildMarkerDetailsSheet(),

          // Floating action buttons
          _buildFloatingActions(),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        final mapUrl = mapProvider.getMapImageUrl(width: 1200, height: 1600);

        // If provider reports map unavailable or an explicit error, show a message UI
        if (mapProvider.mapUnavailable || (mapProvider.mapError != null && mapProvider.mapError!.isNotEmpty)) {
          final message = mapProvider.mapUnavailable ? 'Map API key not configured' : (mapProvider.mapError ?? 'Map error');
          return Container(
            color: AppColors.background,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: AppColors.textGray.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(color: AppColors.textGray, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MapSettingsScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Configure API Key'),
                  ),
                ],
              ),
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // Map image
            mapUrl.startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: mapUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, _) => Container(
                      color: AppColors.background,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                    errorWidget: (context, _, __) => Container(
                      color: AppColors.background,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Map failed to load',
                              style: TextStyle(
                                color: AppColors.textGray,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                context.read<MapProvider>().clearMapError();
                                setState(() {});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Image.asset(
                    mapUrl,
                    fit: BoxFit.cover,
                  ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: 'Search locations...',
            hintStyle: TextStyle(
              color: AppColors.textGray.withOpacity(0.5),
            ),
            border: InputBorder.none,
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),
          onChanged: (query) {
            context.read<MapProvider>().searchMarkers(query);
          },
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Consumer<MapProvider>(
        builder: (context, mapProvider, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...MarkerCategory.values.map((category) {
                  final isSelected =
                      mapProvider.selectedCategories.contains(category);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          context.read<MapProvider>().toggleCategory(category),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              category == MarkerCategory.pg
                                  ? '🏠'
                                  : category == MarkerCategory.mess
                                      ? '🍛'
                                      : category == MarkerCategory.service
                                          ? '🔧'
                                          : category == MarkerCategory.event
                                              ? '📅'
                                              : '🏥',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              category == MarkerCategory.pg
                                  ? 'PG'
                                  : category == MarkerCategory.mess
                                      ? 'Mess'
                                      : category == MarkerCategory.service
                                          ? 'Services'
                                          : category == MarkerCategory.event
                                              ? 'Events'
                                              : 'Utilities',
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapMarkers() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        if (mapProvider.filteredMarkers.isEmpty) {
          return Positioned.fill(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off_rounded,
                    color: AppColors.textGray.withOpacity(0.5),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No locations found',
                    style: TextStyle(
                      color: AppColors.textGray.withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMarkerDetailsSheet() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        final marker = mapProvider.selectedMarker;
        if (marker == null) return const SizedBox.shrink();

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 20,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _showMarkerDetails = false);
                        context.read<MapProvider>().selectMarker('');
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textGray,
                      ),
                    ),
                  ),
                ),

                // Marker details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      if (marker.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: marker.imageUrl!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.location_on,
                              size: 64,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              marker.getCategoryName(),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        marker.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),

                      // Description
                      if (marker.description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            marker.description!,
                            style: TextStyle(
                              color: AppColors.textGray,
                              fontSize: 14,
                            ),
                          ),
                        ),

                      // Address
                      if (marker.address != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  marker.address!,
                                  style: TextStyle(
                                    color: AppColors.textGray,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Coordinates
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.navigation_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${marker.latitude.toStringAsFixed(4)}, ${marker.longitude.toStringAsFixed(4)}',
                              style: TextStyle(
                                color: AppColors.textGray,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to detail screen based on category
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('View Details'),
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

                      const SizedBox(height: 20),
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

  Widget _buildFloatingActions() {
    return Positioned(
      bottom: 24,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter button
          FloatingActionButton.small(
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            child: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(height: 12),

          // Center location button
          FloatingActionButton.small(
            onPressed: () {
              context.read<MapProvider>().updateMapView(28.5244, 77.1855, 14);
            },
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
    );
  }
}
