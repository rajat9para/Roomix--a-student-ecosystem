import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/services/cloudinary_upload_service.dart';
import 'package:roomix/services/firebase_service.dart';
import 'package:roomix/widgets/location_autocomplete_field.dart';
import 'package:roomix/services/location_autocomplete_service.dart';
import 'package:roomix/models/university_model.dart';

class AddMessScreen extends StatefulWidget {
  final Map<String, dynamic>? existingMess; // For editing

  const AddMessScreen({super.key, this.existingMess});

  @override
  State<AddMessScreen> createState() => _AddMessScreenState();
}

class _AddMessScreenState extends State<AddMessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = CloudinaryUploadService();
  final _firebaseService = FirebaseService();

  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _mealsPerDayController = TextEditingController();
  final _timingsController = TextEditingController();
  final _universityController = TextEditingController();
  final _menuPreviewController = TextEditingController();
  final _contactController = TextEditingController();

  String _selectedFoodType = 'Vegetarian';
  final List<String> _foodTypes = ['Vegetarian', 'Non-Vegetarian', 'Both'];

  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isEditing = false;
  bool _isListingBlocked = false;
  String? _listingBlockMessage;
  List<UniversityModel> _universities = [];

  // Location details
  LocationDetails? _selectedLocation;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadUniversities();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      final role = currentUser?.role.trim().toLowerCase();
      final ownerType = currentUser?.ownerType?.trim().toLowerCase();

      if (role == 'student') {
        setState(() {
          _isListingBlocked = true;
          _listingBlockMessage = 'Only property owners can add Mess listings';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only property owners can add Mess listings'),
            backgroundColor: AppColors.error,
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
        return;
      }

      if (role == 'owner' && ownerType == 'pg_owner') {
        setState(() {
          _isListingBlocked = true;
          _listingBlockMessage =
              'PG owners can add only PG listings. Choose Mess Owner at signup to add Mess.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This account can add only PG listings'),
            backgroundColor: AppColors.error,
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });

    if (widget.existingMess != null) {
      _isEditing = true;
      _populateExistingData();
    }
  }

  void _populateExistingData() {
    final mess = widget.existingMess!;
    _nameController.text = mess['name'] ?? '';
    _locationController.text = mess['location'] ?? '';
    _priceController.text = (mess['pricepermonth'] ?? mess['monthlyPrice'] ?? 0)
        .toString();
    _mealsPerDayController.text = (mess['mealsPerDay'] ?? '').toString();
    _timingsController.text = mess['timings'] ?? '';
    _universityController.text = mess['university'] ?? '';
    _contactController.text = mess['contact'] ?? '';
    _selectedFoodType = mess['foodtype'] ?? 'Vegetarian';
    _uploadedImageUrl = mess['imageurl'] ?? mess['image'];

    // Menu preview
    final menu = mess['menu'] as List?;
    if (menu != null && menu.isNotEmpty) {
      _menuPreviewController.text = menu.join(', ');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _mealsPerDayController.dispose();
    _timingsController.dispose();
    _universityController.dispose();
    _menuPreviewController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadUniversities() async {
    try {
      final unis = await _firebaseService.getUniversities();
      if (!mounted) return;
      setState(() {
        _universities = unis;
      });
    } catch (e) {
      debugPrint('⚠️ ADD_MESS: Failed to load universities: $e');
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    setState(() => _isUploading = true);

    try {
      final imageUrl = await _storageService.uploadMessImage(
        file: _selectedImage!,
      );

      setState(() {
        _uploadedImageUrl = imageUrl;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _onLocationSelected(LocationDetails location) {
    setState(() {
      _selectedLocation = location;
      _locationController.text = location.formattedAddress;
      _latitude = location.latitude;
      _longitude = location.longitude;
    });
  }

  Future<void> _submitMess() async {
    if (_isListingBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_listingBlockMessage ?? 'You cannot add Mess listings'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_uploadedImageUrl == null && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload an image first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Parse menu items
      final menuItems = _menuPreviewController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      final mealsPerDay = int.tryParse(_mealsPerDayController.text.trim());

      if (_isEditing) {
        // Update existing mess
        await _firebaseService.updateMess(widget.existingMess!['id'], {
          'name': _nameController.text.trim(),
          'location': _locationController.text.trim(),
          'pricepermonth': double.parse(_priceController.text.trim()),
          if (mealsPerDay != null) 'mealsPerDay': mealsPerDay,
          'foodtype': _selectedFoodType,
          'contact': _contactController.text.trim(),
          'timings': _timingsController.text.trim(),
          'university': _universityController.text.trim(),
          'menu': menuItems,
          if (_uploadedImageUrl != null) 'imageurl': _uploadedImageUrl,
          if (_latitude != null) 'latitude': _latitude,
          if (_longitude != null) 'longitude': _longitude,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mess updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create new mess
        await _firebaseService.createMess(
          name: _nameController.text.trim(),
          location: _locationController.text.trim(),
          pricepermonth: double.parse(_priceController.text.trim()),
          mealsPerDay: mealsPerDay,
          foodtype: _selectedFoodType,
          contact: _contactController.text.trim(),
          menu: menuItems,
          imageurl: _uploadedImageUrl ?? '',
          timings: _timingsController.text.trim(),
          university: _universityController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mess listed successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${_isEditing ? "update" : "create"} listing: $e',
            ),
            backgroundColor: AppColors.error,
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

                      // Name Field
                      _buildTextField(
                        controller: _nameController,
                        label: 'Mess Name',
                        hint: 'e.g., Sharma Tiffin Services',
                        icon: Icons.restaurant_rounded,
                      ),
                      const SizedBox(height: 16),

                      // Location Field
                      _buildLocationField(),
                      const SizedBox(height: 16),

                      // Price Field
                      _buildTextField(
                        controller: _priceController,
                        label: 'Monthly Price (₹)',
                        hint: 'e.g., 3000',
                        icon: Icons.currency_rupee_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _mealsPerDayController,
                        label: 'Meals Per Day',
                        hint: 'e.g., 2 or 3',
                        icon: Icons.restaurant_menu_rounded,
                        keyboardType: TextInputType.number,
                        customValidator: (value) {
                          final meals = int.tryParse(value ?? '');
                          if (meals == null || meals <= 0 || meals > 6) {
                            return 'Enter meals per day between 1 and 6';
                          }
                          return null;
                        },
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

                      // Timings Field — Clock Picker
                      _buildTimingsField(),
                      const SizedBox(height: 16),

                      _buildUniversityField(),
                      const SizedBox(height: 16),

                      // Food Type Selector
                      _buildFoodTypeSelector(),
                      const SizedBox(height: 16),

                      // Menu Preview Field
                      _buildMenuPreviewField(),
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
            _isEditing ? 'Edit Mess' : 'Add Mess',
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
    return GestureDetector(
      onTap: _isUploading || _isListingBlocked ? null : _pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: _isUploading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 12),
                    Text(
                      'Uploading...',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                  ],
                ),
              )
            : _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_selectedImage!, fit: BoxFit.cover),
                    if (_uploadedImageUrl != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Uploaded',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Change button
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Change',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : _uploadedImageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      _uploadedImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.background,
                        child: const Icon(
                          Icons.restaurant,
                          color: AppColors.textGray,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Change',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    size: 50,
                    color: AppColors.textGray.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to add mess photo',
                    style: TextStyle(color: AppColors.textGray, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Show your food or mess',
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
    String? Function(String?)? customValidator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
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
              borderSide: const BorderSide(color: AppColors.border),
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

            if (customValidator != null) {
              return customValidator(trimmed);
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTimingsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Timings',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 8, minute: 0),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: AppColors.textDark,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      final current = _timingsController.text;
                      final closingPart = current.contains(' - ')
                          ? current.split(' - ').last
                          : '';
                      final openingStr = picked.format(context);
                      _timingsController.text = closingPart.isNotEmpty
                          ? '$openingStr - $closingPart'
                          : openingStr;
                      setState(() {});
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wb_sunny_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          _timingsController.text.contains(' - ')
                              ? _timingsController.text.split(' - ').first
                              : (_timingsController.text.isNotEmpty
                                  ? _timingsController.text
                                  : 'Opening'),
                          style: TextStyle(
                            color: _timingsController.text.isNotEmpty
                                ? AppColors.textDark
                                : AppColors.textGray,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('—', style: TextStyle(fontSize: 18, color: AppColors.textGray)),
              ),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 22, minute: 0),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: AppColors.textDark,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      final current = _timingsController.text;
                      final openingPart = current.contains(' - ')
                          ? current.split(' - ').first
                          : current;
                      final closingStr = picked.format(context);
                      _timingsController.text = openingPart.isNotEmpty
                          ? '$openingPart - $closingStr'
                          : '- $closingStr';
                      setState(() {});
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.nightlight_round, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          _timingsController.text.contains(' - ')
                              ? _timingsController.text.split(' - ').last
                              : 'Closing',
                          style: TextStyle(
                            color: _timingsController.text.contains(' - ')
                                ? AppColors.textDark
                                : AppColors.textGray,
                            fontWeight: FontWeight.w600,
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

  Widget _buildFoodTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Food Type',
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
          children: _foodTypes.map((type) {
            final isSelected = _selectedFoodType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedFoodType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.success : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected ? AppColors.success : AppColors.border,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.success.withOpacity(0.3),
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

  Widget _buildMenuPreviewField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Menu Items',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _menuPreviewController,
          maxLines: 4,
          textAlign: TextAlign.start,
          style: const TextStyle(color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: 'e.g., Dal, Rice, Roti, Sabzi, Salad...',
            hintStyle: TextStyle(color: AppColors.textGray.withOpacity(0.6)),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Icon(Icons.menu_book_rounded, color: AppColors.primary),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
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
            if (value == null || value.isEmpty) {
              return 'Please provide menu items';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading || _isListingBlocked ? null : _submitMess,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isListingBlocked
              ? AppColors.textGray
              : AppColors.success,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
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
                        : Icons.check_circle_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isListingBlocked
                        ? 'Listing Not Allowed'
                        : _isEditing
                        ? 'Save Changes'
                        : 'List My Mess',
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
