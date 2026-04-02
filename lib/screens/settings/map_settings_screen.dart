import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:roomix/services/map_service.dart';
import 'package:roomix/constants/app_colors.dart';

class MapSettingsScreen extends StatefulWidget {
  const MapSettingsScreen({super.key});

  @override
  State<MapSettingsScreen> createState() => _MapSettingsScreenState();
}

class _MapSettingsScreenState extends State<MapSettingsScreen> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    // Re-initialize to pick up the conf file key
    await MapService().initialize();
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = MapService.hasApiKey;
    final previewUrl = hasKey
        ? MapService.generatePreviewUrl(centerLat: 28.5244, centerLng: 77.1855)
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasKey
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasKey
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasKey ? Icons.check_circle : Icons.info_outline,
                    color: hasKey ? Colors.green : Colors.orange,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasKey
                              ? 'MapMyIndia Key Active'
                              : _isInitializing
                                  ? 'Detecting key...'
                                  : 'Key loading...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: hasKey ? Colors.green.shade800 : Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasKey
                              ? 'Auto-detected from project config file'
                              : 'Initializing map services...',
                          style: TextStyle(
                            fontSize: 13,
                            color: hasKey ? Colors.green.shade600 : Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Map Preview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isInitializing
                  ? const Center(child: CircularProgressIndicator())
                  : previewUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: previewUrl,
                            fit: BoxFit.cover,
                            placeholder: (c, _) =>
                                const Center(child: CircularProgressIndicator()),
                            errorWidget: (c, _, __) => Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.map, size: 48, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text(
                                      'Map preview loading...',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.map_outlined,
                                    size: 48, color: AppColors.primary),
                                const SizedBox(height: 8),
                                const Text(
                                  'Map uses Google Maps for navigation',
                                  style: TextStyle(
                                    color: AppColors.textGray,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
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
