import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/providers/owner_listings_provider.dart';
import 'package:roomix/services/cloudinary_upload_service.dart';
import 'package:roomix/widgets/location_autocomplete_field.dart';
import 'package:roomix/services/location_autocomplete_service.dart';
import 'package:roomix/models/room_model.dart';
import 'package:roomix/models/university_model.dart';
import 'package:roomix/services/firebase_service.dart';
import 'package:roomix/services/telegram_service.dart';

class AddRoomScreen extends StatefulWidget {
  final RoomModel? existingRoom; // For editing existing room

  const AddRoomScreen({super.key, this.existingRoom});

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _pricePerPersonController = TextEditingController();
  final _contactController = TextEditingController();
  final _universityController = TextEditingController();
  final _telegramController = TextEditingController();

  String _selectedType = 'Single';
  final List<String> _roomTypes = ['Single', 'Shared', 'Double', 'Triple'];
  final List<String> _selectedAmenities = [];
  final List<String> _availableAmenities = [
    'WiFi',
    'AC',
    'Attached Bathroom',
    'Geyser',
    'Parking',
    'TV',
    'Washing Machine',
    'Kitchen',
    'Fridge',
    'Power Backup',
  ];

  final List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isListingBlocked = false;
  String? _listingBlockMessage;
  bool _isEditing = false;
  List<UniversityModel> _universities = [];

  // Location details
  LocationDetails? _selectedLocation;
  double? _latitude;
  double? _longitude;

  final _storageService = CloudinaryUploadService();

  @override
  void initState() {
    super.initState();
    _loadUniversities();

    // Check if editing
    if (widget.existingRoom != null) {
      _isEditing = true;
      _populateExistingData();
    } else {
      final user = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUser;
      final telegram = user?.telegramPhone?.trim();
      if (telegram != null && telegram.isNotEmpty) {
        _telegramController.text = telegram;
      }
    }

    // Check user role
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      final userRole = currentUser?.role.trim().toLowerCase();
      final ownerType = currentUser?.ownerType?.trim().toLowerCase();

      debugPrint(
        '🔍 ADD_ROOM: User role = "$userRole", ownerType = "$ownerType", id = "${currentUser?.id}"',
      );

      if (userRole == 'student') {
        debugPrint('⛔ ADD_ROOM: User is student — blocking listing');
        setState(() {
          _isListingBlocked = true;
          _listingBlockMessage = 'Only property owners can add PG listings';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only property owners can add PG listings'),
            backgroundColor: AppColors.error,
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      } else if (userRole == 'owner' && ownerType == 'mess_owner') {
        debugPrint('⛔ ADD_ROOM: Mess owner cannot add PG listings');
        setState(() {
          _isListingBlocked = true;
          _listingBlockMessage =
              'Mess owners can add only Mess listings. Choose PG Owner at signup to add PG.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This account can add only Mess listings'),
            backgroundColor: AppColors.error,
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        debugPrint('✅ ADD_ROOM: User is owner/admin — listing allowed');
      }
    });
  }

  void _populateExistingData() {
    final room = widget.existingRoom!;
    _titleController.text = room.title;
    _locationController.text = room.location;
    _priceController.text = room.price.toStringAsFixed(0);
    _pricePerPersonController.text =
        room.pricePerPerson?.toStringAsFixed(0) ?? '';
    _contactController.text = room.contact;
    _universityController.text = room.university;
    _telegramController.text = room.telegramPhone ?? '';
    _selectedType = room.type;
    _selectedAmenities.clear();
    _selectedAmenities.addAll(room.amenities);
    if (room.imageurl.isNotEmpty) {
      _uploadedImageUrls.add(room.imageurl);
    }
    // Also add all images from the images array
    if (room.images.isNotEmpty) {
      for (final url in room.images) {
        if (!_uploadedImageUrls.contains(url)) {
          _uploadedImageUrls.add(url);
        }
      }
    }
    _latitude = room.latitude;
    _longitude = room.longitude;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _pricePerPersonController.dispose();
    _contactController.dispose();
    _universityController.dispose();
    _telegramController.dispose();
    super.dispose();
  }

  Future<void> _loadUniversities() async {
    try {
      final unis = await FirebaseService().getUniversities();
      if (!mounted) return;
      setState(() {
        _universities = unis;
      });
    } catch (e) {
      debugPrint('⚠️ ADD_ROOM: Failed to load universities: $e');
    }
  }

  void _showUniversityPicker() {
    if (_universities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('University options are loading. Please try again.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final searchController = TextEditingController();
    List<UniversityModel> filtered = List<UniversityModel>.from(_universities);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void filter(String query) {
              final q = query.trim().toLowerCase();
              setModalState(() {
                if (q.isEmpty) {
                  filtered = List<UniversityModel>.from(_universities);
                } else {
                  filtered = _universities.where((u) {
                    return u.name.toLowerCase().contains(q) ||
                        u.city.toLowerCase().contains(q) ||
                        u.state.toLowerCase().contains(q);
                  }).toList();
                }
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Select University / Area',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search university name or city...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: filter,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (_, index) {
                          final uni = filtered[index];
                          final subtitle = [
                            uni.city,
                            uni.state,
                          ].where((s) => s.trim().isNotEmpty).join(', ');
                          return ListTile(
                            title: Text(uni.name),
                            subtitle: subtitle.isEmpty ? null : Text(subtitle),
                            onTap: () {
                              setState(() {
                                _universityController.text = uni.name;
                              });
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _pickImages() async {
    if (_isListingBlocked) {
      debugPrint('⛔ PICK_IMAGES: Blocked by role/owner type');
      return;
    }

    debugPrint('📷 PICK_IMAGES: Opening gallery...');
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 80);

    debugPrint('📷 PICK_IMAGES: Picked ${pickedFiles.length} files');

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((f) => File(f.path)));
      });
      debugPrint(
        '📷 PICK_IMAGES: Total selected = ${_selectedImages.length}, starting upload...',
      );
      await _uploadAllImages();
    }
  }

  Future<void> _uploadAllImages() async {
    if (_selectedImages.isEmpty || _isListingBlocked) {
      debugPrint(
        '⛔ UPLOAD: Skipped — isEmpty=${_selectedImages.isEmpty}, isListingBlocked=$_isListingBlocked',
      );
      return;
    }

    debugPrint(
      '⬆️ UPLOAD: Starting upload of ${_selectedImages.length} images (${_uploadedImageUrls.length} already uploaded)',
    );
    setState(() => _isUploading = true);

    try {
      int uploaded = 0;
      for (int i = 0; i < _selectedImages.length; i++) {
        // Skip if already uploaded (index already has a URL)
        if (i < _uploadedImageUrls.length) {
          debugPrint('⬆️ UPLOAD: Image $i already uploaded, skipping');
          continue;
        }

        debugPrint(
          '⬆️ UPLOAD: Uploading image $i — path: ${_selectedImages[i].path}',
        );
        debugPrint(
          '⬆️ UPLOAD: File exists: ${await _selectedImages[i].exists()}, size: ${await _selectedImages[i].length()} bytes',
        );

        final imageUrl = await _storageService.uploadRoomImage(
          file: _selectedImages[i],
        );

        debugPrint('✅ UPLOAD: Image $i uploaded — URL: $imageUrl');
        _uploadedImageUrls.add(imageUrl);
        uploaded++;
      }

      debugPrint(
        '✅ UPLOAD: All done — $uploaded new uploads, total URLs: ${_uploadedImageUrls.length}',
      );

      if (mounted && uploaded > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$uploaded image(s) uploaded successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ UPLOAD FAILED: $e');
      debugPrint('❌ STACK TRACE: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (index < _uploadedImageUrls.length) {
        _uploadedImageUrls.removeAt(index);
      }
    });
  }

  void _onLocationSelected(LocationDetails location) {
    setState(() {
      _selectedLocation = location;
      _locationController.text = location.formattedAddress;
      _latitude = location.latitude;
      _longitude = location.longitude;

      // Auto-fill university/city if available
      if (_universityController.text.isEmpty && location.city != null) {
        _universityController.text = location.city!;
      }
    });
  }

  Future<void> _submitRoom() async {
    debugPrint(
      '🚀 SUBMIT: Starting... isListingBlocked=$_isListingBlocked, isUploading=$_isUploading',
    );

    if (_isListingBlocked) {
      debugPrint(
        '⛔ SUBMIT: Blocked — role/owner type does not allow PG listing',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_listingBlockMessage ?? 'You cannot add PG listings'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      debugPrint('⛔ SUBMIT: Form validation failed');
      return;
    }

    debugPrint(
      '🚀 SUBMIT: selectedImages=${_selectedImages.length}, uploadedUrls=${_uploadedImageUrls.length}',
    );

    if (_uploadedImageUrls.isEmpty && _selectedImages.isEmpty) {
      debugPrint('⛔ SUBMIT: No images at all');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one image'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Block submit if images are still uploading
    if (_isUploading) {
      debugPrint('⛔ SUBMIT: Still uploading, blocking');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for images to finish uploading...'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Ensure all selected images have been uploaded
    if (_uploadedImageUrls.length < _selectedImages.length) {
      debugPrint('⚠️ SUBMIT: Upload count mismatch, retrying upload...');
      // Some images failed to upload — retry
      await _uploadAllImages();
      if (_uploadedImageUrls.length < _selectedImages.length) {
        debugPrint('⛔ SUBMIT: Upload retry failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Some images failed to upload. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    debugPrint('🚀 SUBMIT: All checks passed, creating listing...');
    debugPrint('🚀 SUBMIT: imageUrls = $_uploadedImageUrls');
    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<OwnerListingsProvider>(
        context,
        listen: false,
      );
      final pricePerPersonText = _pricePerPersonController.text.trim();
      final pricePerPerson = pricePerPersonText.isEmpty
          ? null
          : double.tryParse(pricePerPersonText);

      if (_isEditing) {
        // Update existing room
        final success = await provider.updateRoomWithDetails(
          roomId: widget.existingRoom!.id,
          title: _titleController.text.trim(),
          location: _locationController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          priceperperson: pricePerPerson,
          type: _selectedType,
          contact: _contactController.text.trim(),
          amenities: _selectedAmenities,
          university: _universityController.text.trim(),
          telegramContact: _telegramController.text.trim().isEmpty
              ? null
              : TelegramService.formatPhone(_telegramController.text),
          imageUrl: _uploadedImageUrls.isNotEmpty
              ? _uploadedImageUrls.first
              : null,
          latitude: _latitude,
          longitude: _longitude,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create new room
        final success = await provider.addRoom(
          title: _titleController.text.trim(),
          location: _locationController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          priceperperson: pricePerPerson,
          type: _selectedType,
          contact: _contactController.text.trim(),
          amenities: _selectedAmenities,
          university: _universityController.text.trim(),
          telegramContact: _telegramController.text.trim().isEmpty
              ? null
              : TelegramService.formatPhone(_telegramController.text),
          imageUrls: _uploadedImageUrls,
          latitude: _latitude,
          longitude: _longitude,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room listed successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SUBMIT FAILED: $e');
      debugPrint('❌ SUBMIT STACK: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${_isEditing ? "update" : "create"} listing: $e',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            _buildAppBar(),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Picker
                      _buildImagePicker(),
                      const SizedBox(height: 24),

                      // Title Field
                      _buildTextField(
                        controller: _titleController,
                        label: 'PG / Mess Name',
                        hint: 'e.g., Sharma PG, Gupta Mess',
                        icon: Icons.business_rounded,
                      ),
                      const SizedBox(height: 16),

                      // Location Field with Autocomplete
                      _buildLocationField(),
                      const SizedBox(height: 16),

                      // Price Field
                      _buildTextField(
                        controller: _priceController,
                        label: 'Monthly Rent (₹)',
                        hint: 'e.g., 5000',
                        icon: Icons.currency_rupee_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _pricePerPersonController,
                        label: 'Price Per Person (₹)',
                        hint: 'e.g., 2500',
                        icon: Icons.person_outline_rounded,
                        keyboardType: TextInputType.number,
                        required: false,
                      ),
                      const SizedBox(height: 16),

                      // Contact Field
                      _buildTextField(
                        controller: _contactController,
                        label: 'Contact Number',
                        hint: 'e.g., 9876543210',
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      // University Field
                      _buildUniversityField(),
                      const SizedBox(height: 16),

                      // Telegram Phone Number Field
                      _buildTelegramField(),
                      const SizedBox(height: 24),

                      // Room Type Selector
                      _buildTypeSelector(),
                      const SizedBox(height: 24),

                      // Amenities
                      _buildAmenities(),
                      const SizedBox(height: 32),

                      // Submit Button
                      _buildSubmitButton(),
                      const SizedBox(height: 20),
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

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.background,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back, color: AppColors.textDark),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isEditing ? 'Edit PG / Room' : 'Add PG / Room',
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    if (_selectedImages.isEmpty && _uploadedImageUrls.isEmpty) {
      // Empty state — tap to pick
      return GestureDetector(
        onTap: _isUploading || _isListingBlocked ? null : _pickImages,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_rounded,
                size: 50,
                color: AppColors.textGray.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap to add room photos',
                style: TextStyle(color: AppColors.textGray, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'You can select multiple photos',
                style: TextStyle(
                  color: AppColors.textGray.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Multi-image gallery
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Photos (${_selectedImages.length})',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_isUploading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length + 1, // +1 for add button
            itemBuilder: (context, index) {
              if (index == _selectedImages.length) {
                // Add more button
                return GestureDetector(
                  onTap: _isUploading ? null : _pickImages,
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 36,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add More',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final isUploaded = index < _uploadedImageUrls.length;
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(_selectedImages[index], fit: BoxFit.cover),
                      // Upload badge
                      if (isUploaded)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      // Remove button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      // Index badge
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            index == 0 ? 'Cover' : '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        LocationAutocompleteField(
          controller: _locationController,
          hint: 'Search or enter location',
          onLocationSelected: _onLocationSelected,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a location';
            }
            return null;
          },
          showCurrentLocationButton: true,
        ),
        if (_selectedLocation != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location coordinates: ${_latitude?.toStringAsFixed(4) ?? 'N/A'}, ${_longitude?.toStringAsFixed(4) ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!required)
              Text(
                ' (Optional)',
                style: TextStyle(color: AppColors.textGray, fontSize: 14),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textAlign: TextAlign.start,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textGray.withOpacity(0.6)),
            prefixIcon: Icon(icon, color: AppColors.primary),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (required && trimmed.isEmpty) {
              return 'This field is required';
            }

            if (trimmed.isNotEmpty && keyboardType == TextInputType.number) {
              final num = double.tryParse(trimmed);
              if (num == null || num <= 0) {
                return 'Please enter a valid number';
              }
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildUniversityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'University / Area',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ' (Optional)',
              style: TextStyle(color: AppColors.textGray, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _universityController,
          textAlign: TextAlign.start,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: 'Select from list or type area',
            hintStyle: TextStyle(color: AppColors.textGray.withOpacity(0.6)),
            prefixIcon: const Icon(
              Icons.school_rounded,
              color: AppColors.primary,
            ),
            suffixIcon: IconButton(
              onPressed: _showUniversityPicker,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              color: AppColors.primary,
              tooltip: 'Choose from universities',
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTelegramField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Telegram Phone Number',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ' (Optional)',
              style: TextStyle(color: AppColors.textGray, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'For direct messaging from interested tenants',
          style: TextStyle(
            color: AppColors.textGray.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _telegramController,
          keyboardType: TextInputType.phone,
          textAlign: TextAlign.start,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: 'e.g., +91XXXXXXXXXX',
            hintStyle: TextStyle(color: AppColors.textGray.withOpacity(0.6)),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0088CC).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.send, color: Color(0xFF0088CC), size: 20),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF0088CC),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!TelegramService.isValidPhone(value)) {
                return 'Please enter a valid phone number';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Room Type',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _roomTypes.map((type) {
            final isSelected = _selectedType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
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
                child: Text(
                  type,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textDark,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAmenities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Amenities',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_selectedAmenities.length} selected',
              style: TextStyle(color: AppColors.textGray, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableAmenities.map((amenity) {
            final isSelected = _selectedAmenities.contains(amenity);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedAmenities.remove(amenity);
                  } else {
                    _selectedAmenities.add(amenity);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryLight : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.check,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                    Text(
                      amenity,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textGray,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading || _isListingBlocked || _isUploading
            ? null
            : _submitRoom,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isListingBlocked
              ? AppColors.textGray
              : AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isListingBlocked
                        ? Icons.block
                        : _isEditing
                        ? Icons.save_rounded
                        : Icons.add_home_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isListingBlocked
                        ? 'Listing Not Allowed'
                        : _isEditing
                        ? 'Save Changes'
                        : 'List My Room',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
