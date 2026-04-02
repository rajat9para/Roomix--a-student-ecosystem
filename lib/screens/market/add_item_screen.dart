import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:roomix/providers/market_provider.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/models/market_item_model.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/services/cloudinary_upload_service.dart';
import 'package:roomix/services/telegram_service.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _contactController;

  String? _selectedCategory;
  String? _selectedCondition;
  bool _isLoading = false;

  final List<File> _imageFiles = []; // Up to 4 images
  final ImagePicker _picker = ImagePicker();
  final CloudinaryUploadService _storageService = CloudinaryUploadService();

  final List<String> _categories = [
    'Electronics',
    'Books',
    'Furniture',
    'Clothing',
    'Stationery',
    'Cycles',
    'Others',
  ];

  final List<String> _conditions = ['New', 'Like New', 'Good', 'Fair', 'Poor'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _priceController = TextEditingController();
    _descriptionController = TextEditingController();
    _contactController = TextEditingController();

    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final telegramContact = user?.telegramPhone;
    if (telegramContact != null && telegramContact.isNotEmpty) {
      _contactController.text = telegramContact;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_imageFiles.length >= 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maximum 4 images allowed')));
      return;
    }

    final remaining = 4 - _imageFiles.length;
    final picked = await _picker.pickMultiImage(
      imageQuality: 80,
      limit: remaining,
    );

    if (picked.isNotEmpty) {
      setState(() {
        for (final xfile in picked) {
          if (_imageFiles.length < 4) {
            _imageFiles.add(File(xfile.path));
          }
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    if (_selectedCondition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select item condition')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // CRITICAL: Use FirebaseAuth UID directly to prevent stale cached data
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) throw Exception('User not logged in');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      final sellerName = user?.name ?? firebaseUser.displayName ?? 'Unknown';
      final sellerId = firebaseUser.uid;

      if (_contactController.text.trim().isEmpty &&
          user?.telegramPhone != null &&
          user!.telegramPhone!.trim().isNotEmpty) {
        _contactController.text = user.telegramPhone!.trim();
      }

      // Upload all images
      List<String> imageUrls = [];
      for (int i = 0; i < _imageFiles.length; i++) {
        final url = await _storageService.uploadImage(
          file: _imageFiles[i],
          folder: 'market_items',
        );
        if (url.isNotEmpty) {
          imageUrls.add(url);
        }
      }

      final item = MarketItemModel(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        condition: _selectedCondition!,
        category: _selectedCategory!,
        image: imageUrls.isNotEmpty ? imageUrls.first : null,
        images: imageUrls,
        sellerContact: TelegramService.formatPhone(_contactController.text),
        sellerName: sellerName,
        sellerId: sellerId,
        sold: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await Provider.of<MarketProvider>(context, listen: false).addItem(item);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item listed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('List Item'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Title *'),
                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDecoration(
                      'e.g., Engineering Mathematics Book',
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Price (₹) *'),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('e.g., 500'),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      if (double.tryParse(value!) == null)
                        return 'Invalid price';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Category *'),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: _inputDecoration('Select category'),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Condition *'),
                  DropdownButtonFormField<String>(
                    value: _selectedCondition,
                    decoration: _inputDecoration('Select condition'),
                    items: _conditions
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCondition = v),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Description'),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: _inputDecoration('Describe your item...'),
                  ),
                  const SizedBox(height: 16),

                  // MULTI-IMAGE UPLOAD
                  _buildLabel('Item Photos (up to 4)'),
                  _buildImageGrid(),
                  const SizedBox(height: 16),

                  _buildLabel('Telegram Number *'),
                  TextFormField(
                    controller: _contactController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(
                      'Use the Telegram number from Account Settings',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Required';
                      if (!TelegramService.isValidPhone(text)) {
                        return 'Enter a valid Telegram phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Post Listing',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _imageFiles.length < 4 ? _imageFiles.length + 1 : 4,
      itemBuilder: (context, index) {
        // Add button
        if (index == _imageFiles.length && _imageFiles.length < 4) {
          return GestureDetector(
            onTap: _pickImages,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 28,
                    color: AppColors.primary.withOpacity(0.6),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_imageFiles.length}/4',
                    style: const TextStyle(
                      color: AppColors.textGray,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Image preview with remove button
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _imageFiles[index],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textGray),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
