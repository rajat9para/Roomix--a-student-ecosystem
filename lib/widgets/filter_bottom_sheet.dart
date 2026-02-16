import 'package:flutter/material.dart';
import 'package:roomix/constants/app_colors.dart';

class FilterBottomSheet extends StatefulWidget {
  /// Title of the filter bottom sheet
  final String title;
  
  /// Called when Apply button is pressed with the selected filters
  final Function(Map<String, dynamic>) onApply;
  
  /// Called when Reset button is pressed
  final VoidCallback onReset;
  
  /// Initial filters to display
  final Map<String, dynamic>? initialFilters;
  
  /// List of filter sections (categories, price range, etc.)
  final List<FilterSection> sections;

  const FilterBottomSheet({
    Key? key,
    required this.title,
    required this.onApply,
    required this.onReset,
    required this.sections,
    this.initialFilters,
  }) : super(key: key);

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class FilterSection {
  final String title;
  final String type; // 'checkbox', 'range', 'radio', 'custom'
  /// Optional key to uniquely identify this section in selectedFilters
  final String? filterKey;
  final List<String>? options;
  final double? minValue, maxValue;
  final Function(dynamic)? onChanged;
  final Widget? customWidget;

  FilterSection({
    required this.title,
    required this.type,
    this.filterKey,
    this.options,
    this.minValue,
    this.maxValue,
    this.onChanged,
    this.customWidget,
  });
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Map<String, dynamic> selectedFilters;

  @override
  void initState() {
    super.initState();
    selectedFilters = widget.initialFilters ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
          // Header
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: AppColors.textGray,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Divider
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Filter sections - scrollable
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...widget.sections.map((section) => _buildFilterSection(section)).toList(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.border.withOpacity(0.5),
                  width: 1,
                ),
              ),
              color: AppColors.background,
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Reset button
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      widget.onReset();
                      setState(() {
                        selectedFilters.clear();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Apply button
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      widget.onApply(selectedFilters);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Apply',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _radioKey(FilterSection section) => section.filterKey ?? section.title;

  String _rangeMinKey(FilterSection section) =>
      '${section.filterKey ?? 'range'}_min';

  String _rangeMaxKey(FilterSection section) =>
      '${section.filterKey ?? 'range'}_max';

  double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return fallback;
  }

  Widget _buildFilterSection(FilterSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        
        if (section.type == 'checkbox' && section.options != null)
          _buildCheckboxFilters(section.options!)
        else if (section.type == 'range')
          _buildRangeSlider(section)
        else if (section.type == 'radio' && section.options != null)
          _buildRadioFilters(section)
        else if (section.type == 'custom' && section.customWidget != null)
          section.customWidget!,
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCheckboxFilters(List<String> options) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selectedFilters[option] ?? false;
        return GestureDetector(
          onTap: () {
            setState(() {
              selectedFilters[option] = !isSelected;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.primaryLight
                  : Colors.white,
              border: Border.all(
                color: isSelected 
                    ? AppColors.primary
                    : AppColors.border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.transparent,
                    border: isSelected ? null : Border.all(
                      color: AppColors.border,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  option,
                  style: TextStyle(
                    color: isSelected 
                        ? AppColors.primary
                        : AppColors.textGray,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRangeSlider(FilterSection section) {
    final minValue = section.minValue ?? 0;
    final maxValue = section.maxValue ?? 100;
    final minKey = _rangeMinKey(section);
    final maxKey = _rangeMaxKey(section);
    final currentMin = _asDouble(selectedFilters[minKey], minValue);
    final currentMax = _asDouble(selectedFilters[maxKey], maxValue);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '₹${currentMin.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '₹${currentMax.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RangeSlider(
          values: RangeValues(currentMin, currentMax),
          min: minValue,
          max: maxValue,
          onChanged: (RangeValues values) {
            setState(() {
              selectedFilters[minKey] = values.start;
              selectedFilters[maxKey] = values.end;
            });
          },
          activeColor: AppColors.primary,
          inactiveColor: AppColors.border,
        ),
      ],
    );
  }

  Widget _buildRadioFilters(FilterSection section) {
    final options = section.options ?? const <String>[];
    final key = _radioKey(section);
    return Column(
      children: options.map((option) {
        final isSelected = selectedFilters[key] == option;
        return GestureDetector(
          onTap: () {
            setState(() {
              selectedFilters[key] = option;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryLight
                  : Colors.white,
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textGray,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
