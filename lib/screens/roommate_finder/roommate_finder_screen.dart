import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:roomix/constants/app_colors.dart';
import 'package:roomix/models/chat_message_model.dart';
import 'package:roomix/models/roommate_profile_model.dart';
import 'package:roomix/providers/roommate_provider.dart';
import 'package:roomix/widgets/filter_bottom_sheet.dart';
import 'package:roomix/widgets/sort_chip.dart';
import 'package:roomix/widgets/bookmark_button.dart';
import 'package:roomix/screens/roommate_finder/profile_creation_screen.dart';
import 'package:roomix/screens/roommate_finder/chat_screen.dart';
import 'package:roomix/utils/smooth_navigation.dart';

class RoommateFinderScreen extends StatefulWidget {
  const RoommateFinderScreen({super.key});

  @override
  State<RoommateFinderScreen> createState() => _RoommateFinderScreenState();
}

class _RoommateFinderScreenState extends State<RoommateFinderScreen> {
  int _selectedTabIndex = 0;
  late TextEditingController _searchController;
  Timer? _searchDebounceTimer;
  String _filterGender = 'All';
  String _filterYear = 'All';
  String _sortBy = 'Best Match';
  double _minBudget = 0;
  double _maxBudget = 50000;
  double _selectedMinBudget = 0;
  double _selectedMaxBudget = 50000;
  Set<String> _selectedLifestyle = {};
  Set<String> _selectedInterests = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RoommateProvider>();
      provider.getMyProfile();
      provider.getMatches();
      provider.getConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {});
    });
  }

  List<RoommateProfile> _applyFilters(List<RoommateProfile> matches) {
    var filtered = matches.toList();
    
    // Search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((m) =>
        m.userName.toLowerCase().contains(query) ||
        m.college.toLowerCase().contains(query) ||
        m.courseYear.toLowerCase().contains(query)
      ).toList();
    }
    
    // Gender filter
    if (_filterGender != 'All') {
      filtered = filtered
          .where((m) => m.gender.toLowerCase() == _filterGender.toLowerCase())
          .toList();
    }
    
    // Year filter
    if (_filterYear != 'All') {
      filtered = filtered.where((m) => m.courseYear == _filterYear).toList();
    }
    
    // Budget filter
    filtered = filtered.where((m) => 
      (m.preferences['budget']?['min'] ?? 0) >= _selectedMinBudget &&
      (m.preferences['budget']?['max'] ?? 100000) <= _selectedMaxBudget
    ).toList();

    // Lifestyle filter
    if (_selectedLifestyle.isNotEmpty) {
      filtered = filtered.where((m) =>
        _selectedLifestyle.every((lifestyle) =>
          (m.preferences['lifestyle'] as List<dynamic>?)?.contains(lifestyle) ?? false
        )
      ).toList();
    }

    // Apply sorting
    _applySorting(filtered);
    return filtered;
  }

  void _applySorting(List<RoommateProfile> items) {
    switch (_sortBy) {
      case 'Year':
        items.sort((a, b) => a.courseYear.compareTo(b.courseYear));
        break;
      case 'College':
        items.sort((a, b) => a.college.compareTo(b.college));
        break;
      case 'Best Match':
      default:
        items.sort((a, b) => (b.compatibility ?? 0).compareTo(a.compatibility ?? 0));
        break;
    }
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_filterGender != 'All') count++;
    if (_filterYear != 'All') count++;
    if (_selectedLifestyle.isNotEmpty) count++;
    if (_selectedMinBudget > _minBudget || _selectedMaxBudget < _maxBudget) count++;
    return count;
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        const lifestyleOptions = {
          'Early Riser': 'early_riser',
          'Night Owl': 'night_owl',
          'Quiet': 'quiet',
          'Social': 'social',
          'Clean': 'clean',
          'Relaxed': 'relaxed',
        };

        return FilterBottomSheet(
          title: 'Filter Roommates',
          sections: [
            FilterSection(
              title: 'Gender',
              type: 'radio',
              filterKey: 'gender',
              options: ['All', 'boys', 'girls', 'other'],
            ),
            FilterSection(
              title: 'Year',
              type: 'radio',
              filterKey: 'year',
              options: ['All', '1st Year', '2nd Year', '3rd Year', '4th Year', 'PG / Masters'],
            ),
            FilterSection(
              title: 'Budget',
              type: 'range',
              filterKey: 'budget',
              minValue: _minBudget,
              maxValue: _maxBudget,
            ),
            FilterSection(
              title: 'Lifestyle',
              type: 'checkbox',
              options: lifestyleOptions.keys.toList(),
            ),
          ],
          initialFilters: {
            'gender': _filterGender,
            'year': _filterYear,
            'budget_min': _selectedMinBudget,
            'budget_max': _selectedMaxBudget,
            for (final entry in lifestyleOptions.entries)
              if (_selectedLifestyle.contains(entry.value)) entry.key: true,
          },
          onApply: (filters) {
            setState(() {
              _filterGender = (filters['gender'] as String?) ?? 'All';
              _filterYear = (filters['year'] as String?) ?? 'All';
              _selectedMinBudget =
                  (filters['budget_min'] as num?)?.toDouble() ?? _minBudget;
              _selectedMaxBudget =
                  (filters['budget_max'] as num?)?.toDouble() ?? _maxBudget;
              _selectedLifestyle = lifestyleOptions.entries
                  .where((entry) => filters[entry.key] == true)
                  .map((entry) => entry.value)
                  .toSet();
            });
          },
          onReset: () {
            setState(() {
              _filterGender = 'All';
              _filterYear = 'All';
              _selectedLifestyle.clear();
              _selectedMinBudget = _minBudget;
              _selectedMaxBudget = _maxBudget;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Find Room Partner',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        actions: [
          Consumer<RoommateProvider>(
            builder: (context, provider, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (provider.profileComplete) {
                        _showProfileMenu(context, provider);
                      } else {
                        SmoothNavigation.push(
                          context,
                          const ProfileCreationScreen(),
                        );
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: CircleAvatar(
                        backgroundColor: AppColors.primaryLight,
                        child: Icon(
                          provider.profileComplete ? Icons.person : Icons.add,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  if (_getActiveFilterCount() > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _getActiveFilterCount().toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: AppColors.background,
        child: Consumer<RoommateProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              );
            }

            if (!provider.profileComplete) {
              return _buildNoProfileState(context);
            }

            return Column(
              children: [
                // Tab bar
                Container(
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTabIndex = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTabIndex == 0
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Matches (${provider.matches.length})',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTabIndex == 0
                                      ? AppColors.primary
                                      : AppColors.textGray,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTabIndex = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTabIndex == 1
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    'Chats',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedTabIndex == 1
                                          ? AppColors.primary
                                          : AppColors.textGray,
                                    ),
                                  ),
                                  if (provider.conversations.any((c) => c.unreadCount > 0))
                                    Positioned(
                                      right: -20,
                                      top: -8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: AppColors.error,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${provider.conversations.where((c) => c.unreadCount > 0).length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
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
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _selectedTabIndex == 0
                      ? _buildMatchesTab(context, provider)
                      : _buildChatsTab(context, provider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoProfileState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person_add_rounded,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Create Your Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start by creating your profile to find\ncompatible roommates',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textGray,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: AppColors.primaryGradient,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  SmoothNavigation.push(
                    context,
                    const ProfileCreationScreen(),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Create Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesTab(BuildContext context, RoommateProvider provider) {
    final filtered = _applyFilters(provider.matches);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 64,
              color: AppColors.textGray.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No matches found',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search profiles...',
                hintStyle: TextStyle(
                  color: AppColors.textGray,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.primary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textGray),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),

        // Sort chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SortChip(
                label: 'Best Match',
                isActive: _sortBy == 'Best Match',
                onTap: () {
                  setState(() {
                    _sortBy = 'Best Match';
                  });
                },
              ),
              const SizedBox(width: 8),
              SortChip(
                label: 'Year',
                isActive: _sortBy == 'Year',
                onTap: () {
                  setState(() {
                    _sortBy = 'Year';
                  });
                },
              ),
              const SizedBox(width: 8),
              SortChip(
                label: 'College',
                isActive: _sortBy == 'College',
                onTap: () {
                  setState(() {
                    _sortBy = 'College';
                  });
                },
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showFilterBottomSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune, size: 16, color: AppColors.textGray),
                      const SizedBox(width: 4),
                      Text(
                        'Filter${_getActiveFilterCount() > 0 ? ' (' + _getActiveFilterCount().toString() + ')' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Matches list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final match = filtered[index];
              return _buildMatchCard(context, match, provider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(
    BuildContext context,
    RoommateProfile match,
    RoommateProvider provider,
  ) {
    final compatibility = match.compatibility ?? _calculateCompatibility(match, provider.myProfile);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        match.userEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$compatibility% match',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    BookmarkButton(
                      itemId: match.userId,
                      type: 'roommate',
                      itemTitle: match.userName,
                      itemImage: null,
                      metadata: {
                        'email': match.userEmail,
                        'bio': match.bio,
                        'compatibility': compatibility,
                        'college': match.college,
                        'year': match.courseYear,
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              match.bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textGray,
              ),
            ),
            const SizedBox(height: 12),
            if (match.interests.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: match.interests.take(3).map((interest) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      interest,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  SmoothNavigation.push(
                    context,
                    ChatScreen(
                      conversationId: match.userId,
                      userName: match.userName,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Message',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatsTab(BuildContext context, RoommateProvider provider) {
    if (provider.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: AppColors.textGray.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.conversations.length,
      itemBuilder: (context, index) {
        final conversation = provider.conversations[index];
        return _buildConversationTile(context, conversation, provider);
      },
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    ChatConversation conversation,
    RoommateProvider provider,
  ) {
    return GestureDetector(
      onTap: () {
        SmoothNavigation.push(
          context,
          ChatScreen(
            conversationId: conversation.userId,
            userName: conversation.userName,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Text(
                conversation.userName.isNotEmpty
                    ? conversation.userName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.userName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ),
            if (conversation.unreadCount > 0)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, RoommateProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context);
                SmoothNavigation.push(
                  context,
                  const ProfileCreationScreen(isEditing: true),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppColors.error),
              title: const Text('Delete Profile', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, RoommateProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Profile?', style: TextStyle(color: AppColors.textDark)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: AppColors.textGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textGray)),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteProfile();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  int _calculateCompatibility(
    RoommateProfile match,
    RoommateProfile? currentUser,
  ) {
    if (currentUser == null) {
      return 70;
    }

    final currentInterests = currentUser.interests.toSet();
    final matchInterests = match.interests.toSet();
    if (currentInterests.isEmpty || matchInterests.isEmpty) {
      return 70;
    }

    final shared = currentInterests.intersection(matchInterests).length;
    final total = currentInterests.union(matchInterests).length;
    final score = (shared / total * 100).round();
    return score.clamp(40, 98);
  }
}
