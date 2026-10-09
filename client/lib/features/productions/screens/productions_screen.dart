import 'package:flutter/material.dart';
import '../models/production_model.dart';
import '../services/production_service.dart';
import '../widgets/production_card.dart';
import 'add_production_screen.dart';
import 'production_details_screen.dart';

class ProductionsScreen extends StatefulWidget {
  final ProductionService? productionService;
  final bool showAppBar;

  const ProductionsScreen({
    super.key,
    this.productionService,
    this.showAppBar = true,
  });

  @override
  State<ProductionsScreen> createState() => _ProductionsScreenState();
}

class _ProductionsScreenState extends State<ProductionsScreen> {
  late final ProductionService _service;
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = widget.productionService ?? ProductionService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _navigateToAddProduction() async {
    final result = await Navigator.of(context).push<Production>(
      MaterialPageRoute(
        builder: (context) => AddProductionScreen(
          productionService: _service,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {});
    }
  }

  Future<void> _navigateToDetails(Production production) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ProductionDetailsScreen(
          production: production,
          productionService: _service,
        ),
      ),
    );

    if (deleted == true && mounted) {
      setState(() {});
    }
  }

  List<Production> _filterProductions(List<Production> list) {
    return list.where((p) {
      // Status filter
      if (_selectedStatusFilter != 'All' && p.status != _selectedStatusFilter) {
        return false;
      }
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = p.title.toLowerCase().contains(query);
        final matchesDesc = p.description.toLowerCase().contains(query);
        final matchesDirector = p.director?.toLowerCase().contains(query) ?? false;
        return matchesTitle || matchesDesc || matchesDirector;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = StreamBuilder<List<Production>>(
      stream: _service.streamProductions(),
      initialData: _service.sampleProductions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load productions',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        final rawProductions = snapshot.data ?? [];
        final filteredList = _filterProductions(rawProductions);

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: CustomScrollView(
            slivers: [
              // Header Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderRow(theme, rawProductions.length),
                      const SizedBox(height: 16),
                      _buildSearchAndFilters(theme),
                    ],
                  ),
                ),
              ),

              // Productions Grid or Empty State
              if (rawProductions.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    theme: theme,
                    title: 'No Productions Yet',
                    subtitle: 'Create your first theatre production to begin organizing rehearsals and stage runs.',
                  ),
                )
              else if (filteredList.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    theme: theme,
                    title: 'No Matching Productions',
                    subtitle: 'Try adjusting your search query or status filter.',
                    isFiltered: true,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      int crossAxisCount = 1;
                      double childAspectRatio = 1.35;

                      if (width >= 1050) {
                        crossAxisCount = 3;
                        childAspectRatio = 1.25;
                      } else if (width >= 650) {
                        crossAxisCount = 2;
                        childAspectRatio = 1.3;
                      } else {
                        crossAxisCount = 1;
                        childAspectRatio = 1.6;
                      }

                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: childAspectRatio,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final prod = filteredList[index];
                            return ProductionCard(
                              production: prod,
                              onTap: () => _navigateToDetails(prod),
                              onDelete: () async {
                                await _service.deleteProduction(prod.id);
                                if (mounted) {
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Deleted "${prod.title}"'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                          childCount: filteredList.length,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (!widget.showAppBar) {
      return Scaffold(
        body: content,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _navigateToAddProduction,
          backgroundColor: const Color(0xFF8B1E3F),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Add Production'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Productions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton.icon(
              onPressed: _navigateToAddProduction,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Production'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B1E3F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: content,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddProduction,
        backgroundColor: const Color(0xFF8B1E3F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Production'),
      ),
    );
  }

  Widget _buildHeaderRow(ThemeData theme, int totalCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Productions Catalog',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total managed: $totalCount',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme) {
    final filters = ['All', ...ProductionStatus.all];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by production name, director, or synopsis...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim();
            });
          },
        ),
        const SizedBox(height: 12),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((status) {
              final isSelected = _selectedStatusFilter == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedStatusFilter = status;
                    });
                  },
                  selectedColor: const Color(0xFF8B1E3F).withValues(alpha: 0.15),
                  checkmarkColor: const Color(0xFF8B1E3F),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xFF8B1E3F) : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF8B1E3F)
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required ThemeData theme,
    required String title,
    required String subtitle,
    bool isFiltered = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF8B1E3F).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered ? Icons.search_off : Icons.theater_comedy_outlined,
                size: 64,
                color: const Color(0xFF8B1E3F),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isFiltered)
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedStatusFilter = 'All';
                  });
                },
                icon: const Icon(Icons.filter_alt_off, size: 18),
                label: const Text('Reset Filters'),
              )
            else
              FilledButton.icon(
                onPressed: _navigateToAddProduction,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Production'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1E3F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
