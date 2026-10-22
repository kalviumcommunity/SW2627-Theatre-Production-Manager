import 'package:flutter/material.dart';
import 'package:client/services/auth_service.dart';
import 'package:client/services/user_service.dart';
import '../models/venue_model.dart';
import '../services/venue_service.dart';
import '../widgets/venue_card.dart';
import 'add_edit_venue_screen.dart';
import 'venue_details_screen.dart';

class VenuesScreen extends StatefulWidget {
  final bool showAppBar;
  final VenueService? venueService;
  final AuthService? authService;
  final UserService? userService;

  const VenuesScreen({
    super.key,
    this.showAppBar = true,
    this.venueService,
    this.authService,
    this.userService,
  });

  @override
  State<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends State<VenuesScreen> {
  late final VenueService _venueService;
  late final AuthService _authService;
  late final UserService _userService;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _userRole = 'Cast Member';

  @override
  void initState() {
    super.initState();
    _venueService = widget.venueService ?? VenueService();
    _authService = widget.authService ?? AuthService();
    _userService = widget.userService ?? UserService();
    _loadUserRole();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadUserRole() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final profile = await _userService.getUserProfile(user.uid);
        if (mounted && profile != null && profile['role'] != null) {
          setState(() {
            _userRole = profile['role'].toString();
          });
        }
      }
    } catch (_) {}
  }

  bool get _isDirector => _userRole == 'Director';

  void _navigateToAddVenue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AddEditVenueScreen(
          venueService: _venueService,
        ),
      ),
    );
  }

  void _navigateToDetails(Venue venue) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => VenueDetailsScreen(
          venue: venue,
          venueService: _venueService,
          isDirector: _isDirector,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = StreamBuilder<List<Venue>>(
      stream: _venueService.streamVenues(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text('Error loading venues: ${snapshot.error}'),
              ],
            ),
          );
        }

        final allVenues = snapshot.data ?? [];
        final filteredVenues = allVenues.where((v) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return v.name.toLowerCase().contains(q) ||
              v.address.toLowerCase().contains(q) ||
              v.facilities.any((f) => f.toLowerCase().contains(q));
        }).toList();

        return Column(
          children: [
            // Header and search bar
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('venue_search_input'),
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search venues by name, location, or facility...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                    ),
                  ),
                  if (_isDirector) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      key: const Key('add_venue_button'),
                      onPressed: _navigateToAddVenue,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Venue'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8B1E3F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // Venue list
            Expanded(
              child: filteredVenues.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_city_outlined,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No venues match your search.'
                                : 'No venues configured yet.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (_isDirector && _searchQuery.isEmpty) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _navigateToAddVenue,
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Venue'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 720;
                        if (isWide) {
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 450,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: 180,
                            ),
                            itemCount: filteredVenues.length,
                            itemBuilder: (context, index) {
                              final v = filteredVenues[index];
                              return VenueCard(
                                venue: v,
                                onTap: () => _navigateToDetails(v),
                              );
                            },
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredVenues.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final v = filteredVenues[index];
                            return VenueCard(
                              venue: v,
                              onTap: () => _navigateToDetails(v),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Venues', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: content,
      );
    }

    return content;
  }
}
