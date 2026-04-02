import 'dart:async';
import 'package:flutter/material.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/services/location_autocomplete_service.dart';

/// A reusable location autocomplete text field widget
class LocationAutocompleteField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? initialValue;
  final TextEditingController? controller;
  final Function(LocationDetails)? onLocationSelected;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool showCurrentLocationButton;
  final IconData prefixIcon;
  final int maxLines;
  final FocusNode? focusNode;

  const LocationAutocompleteField({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.controller,
    this.onLocationSelected,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.showCurrentLocationButton = true,
    this.prefixIcon = Icons.location_on_outlined,
    this.maxLines = 1,
    this.focusNode,
  });

  @override
  State<LocationAutocompleteField> createState() => _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  final LocationAutocompleteService _locationService = LocationAutocompleteService();
  final TextEditingController _internalController = TextEditingController();
  final FocusNode _internalFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  
  late TextEditingController _controller;
  late FocusNode _focusNode;
  
  List<LocationPrediction> _predictions = [];
  bool _isLoading = false;
  bool _showDropdown = false;
  String _previousQuery = '';
  Timer? _debounceTimer;
  OverlayEntry? _overlayEntry;
  LocationDetails? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _internalController;
    _focusNode = widget.focusNode ?? _internalFocusNode;
    
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    _internalController.dispose();
    _internalFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _predictions.isNotEmpty) {
      _showDropdownOverlay();
    } else if (!_focusNode.hasFocus) {
      // Delay to allow tap on dropdown item
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _removeOverlay();
        }
      });
    }
  }

  void _onTextChange() {
    final query = _controller.text.trim();
    
    if (query == _previousQuery) return;
    _previousQuery = query;
    
    widget.onChanged?.call(query);
    
    if (query.length < 2) {
      _predictions = [];
      _removeOverlay();
      return;
    }
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchLocations(query);
    });
  }

  Future<void> _searchLocations(String query) async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final predictions = await _locationService.search(query);
      if (mounted) {
        setState(() {
          _predictions = predictions;
          _isLoading = false;
        });
        
        if (_predictions.isNotEmpty && _focusNode.hasFocus) {
          _showDropdownOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _removeOverlay();
      }
    }
  }

  void _showDropdownOverlay() {
    _removeOverlay();
    
    if (_predictions.isEmpty || !mounted) return;
    
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final size = renderBox.size;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            shadowColor: Colors.black26,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withOpacity(0.5)),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _predictions.length,
                itemBuilder: (context, index) {
                  final prediction = _predictions[index];
                  return _buildPredictionItem(prediction, index == _predictions.length - 1);
                },
              ),
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showDropdown = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted && _showDropdown) {
      setState(() => _showDropdown = false);
    }
  }

  Widget _buildPredictionItem(LocationPrediction prediction, bool isLast) {
    return InkWell(
      onTap: () => _selectPrediction(prediction),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: isLast ? null : Border(
            bottom: BorderSide(
              color: AppColors.border.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prediction.mainText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (prediction.secondaryText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      prediction.secondaryText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectPrediction(LocationPrediction prediction) async {
    _controller.text = prediction.description;
    _removeOverlay();
    
    setState(() => _isLoading = true);
    
    try {
      final details = await _locationService.getPlaceDetails(
        prediction.placeId,
        lat: prediction.latitude,
        lng: prediction.longitude,
      );
      
      if (mounted) {
        setState(() {
          _selectedLocation = details;
          _isLoading = false;
        });
        
        if (details != null) {
          widget.onLocationSelected?.call(details);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    
    try {
      final location = await _locationService.getCurrentLocation();
      
      if (mounted && location != null) {
        _controller.text = location.formattedAddress;
        setState(() {
          _selectedLocation = location;
          _isLoading = false;
        });
        widget.onLocationSelected?.call(location);
      } else if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get current location'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Stack(
            children: [
              TextFormField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                maxLines: widget.maxLines,
                validator: widget.validator,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint ?? 'Enter location',
                  hintStyle: const TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(widget.prefixIcon, color: AppColors.primary),
                  suffixIcon: _buildSuffixIcon(),
                  filled: true,
                  fillColor: widget.enabled ? Colors.white : AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
                  ),
                ),
              ),
            ],
          ),
          if (widget.showCurrentLocationButton) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: widget.enabled && !_isLoading ? _getCurrentLocation : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.my_location,
                    size: 16,
                    color: widget.enabled ? AppColors.primary : AppColors.textGray,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Use current location',
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.enabled ? AppColors.primary : AppColors.textGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }
    
    if (_controller.text.isNotEmpty && widget.enabled) {
      return IconButton(
        icon: const Icon(Icons.clear, color: AppColors.textGray, size: 20),
        onPressed: () {
          _controller.clear();
          setState(() {
            _selectedLocation = null;
            _predictions = [];
          });
          _removeOverlay();
          widget.onChanged?.call('');
        },
      );
    }
    
    return null;
  }
}

/// A simplified location picker that shows a modal bottom sheet
class LocationPickerBottomSheet extends StatefulWidget {
  final String? title;
  final Function(LocationDetails) onLocationSelected;
  final String? initialQuery;

  const LocationPickerBottomSheet({
    super.key,
    this.title,
    required this.onLocationSelected,
    this.initialQuery,
  });

  /// Show the location picker as a modal bottom sheet
  static Future<LocationDetails?> show(
    BuildContext context, {
    String? title,
    String? initialQuery,
  }) async {
    LocationDetails? result;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationPickerBottomSheet(
        title: title,
        initialQuery: initialQuery,
        onLocationSelected: (location) {
          result = location;
          Navigator.pop(context);
        },
      ),
    );
    return result;
  }

  @override
  State<LocationPickerBottomSheet> createState() => _LocationPickerBottomSheetState();
}

class _LocationPickerBottomSheetState extends State<LocationPickerBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final LocationAutocompleteService _locationService = LocationAutocompleteService();
  final FocusNode _focusNode = FocusNode();
  
  List<LocationPrediction> _predictions = [];
  LocationDetails? _currentLocation;
  bool _isLoading = false;
  bool _isLoadingCurrentLocation = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    // Auto-focus search field
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _predictions = []);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final predictions = await _locationService.search(query);
      if (mounted) {
        setState(() {
          _predictions = predictions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectPrediction(LocationPrediction prediction) async {
    setState(() => _isLoading = true);
    
    try {
      final details = await _locationService.getPlaceDetails(
        prediction.placeId,
        lat: prediction.latitude,
        lng: prediction.longitude,
      );
      
      if (mounted && details != null) {
        widget.onLocationSelected(details);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingCurrentLocation = true);
    
    try {
      final location = await _locationService.getCurrentLocation();
      if (mounted && location != null) {
        widget.onLocationSelected(location);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCurrentLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title ?? 'Select Location',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: (value) {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                  _search(value);
                });
              },
              decoration: InputDecoration(
                hintText: 'Search for a location...',
                hintStyle: const TextStyle(color: AppColors.textGray),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textGray),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _predictions = []);
                            },
                          )
                        : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Current location button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: _isLoadingCurrentLocation ? null : _getCurrentLocation,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _isLoadingCurrentLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          )
                        : const Icon(Icons.my_location, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Use current location',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const Divider(height: 24),
          
          // Results list
          Expanded(
            child: _predictions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 64,
                          color: AppColors.textGray.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Start typing to search'
                              : 'No results found',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _predictions.length,
                    itemBuilder: (context, index) {
                      final prediction = _predictions[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          prediction.mainText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        subtitle: prediction.secondaryText.isNotEmpty
                            ? Text(
                                prediction.secondaryText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGray,
                                ),
                              )
                            : null,
                        onTap: () => _selectPrediction(prediction),
                      );
                    },
                  ),
          ),
          
          SizedBox(height: bottomPadding),
        ],
      ),
    );
  }
}