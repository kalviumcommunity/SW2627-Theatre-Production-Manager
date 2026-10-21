import 'package:flutter/material.dart';

import '../../productions/services/production_service.dart';
import '../models/rehearsal_model.dart';
import '../services/rehearsal_service.dart';
import '../widgets/rehearsal_card.dart';
import 'add_rehearsal_screen.dart';
import 'rehearsal_details_screen.dart';

class RehearsalsScreen extends StatefulWidget {
  final RehearsalService? rehearsalService;
  final ProductionService? productionService;
  final bool showAppBar;
  final String? initialProductionFilter;

  const RehearsalsScreen({
    super.key,
    this.rehearsalService,
    this.productionService,
    this.showAppBar = true,
    this.initialProductionFilter,
  });

  @override
  State<RehearsalsScreen> createState() => _RehearsalsScreenState();
}

class _RehearsalsScreenState extends State<RehearsalsScreen> {
  late RehearsalService _service;
  late Stream<List<Rehearsal>> _rehearsalsStream;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedProductionFilter;

  @override
  void initState() {
    super.initState();
    _service = widget.rehearsalService ?? RehearsalService();
    _selectedProductionFilter = widget.initialProductionFilter;
    _rehearsalsStream = _service.streamRehearsals();
  }

  @override
  void didUpdateWidget(RehearsalsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProductionFilter != oldWidget.initialProductionFilter) {
      _selectedProductionFilter = widget.initialProductionFilter;
    }
    if (widget.rehearsalService != oldWidget.rehearsalService) {
      _service = widget.rehearsalService ?? RehearsalService();
      _rehearsalsStream = _service.streamRehearsals();
    }
  }

  void _refreshStream() {
    setState(() {
      _rehearsalsStream = _service.streamRehearsals();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _navigateToAddRehearsal() async {
    final result = await Navigator.of(context).push<Rehearsal>(
      MaterialPageRoute(
        builder: (context) => AddRehearsalScreen(
          rehearsalService: _service,
          productionService: widget.productionService,
          initialProductionId: _selectedProductionFilter,
        ),
      ),
    );

    if (result != null && mounted) {
      _refreshStream();
    }
  }

  Future<void> _navigateToDetails(Rehearsal rehearsal) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => RehearsalDetailsScreen(
          rehearsal: rehearsal,
          rehearsalService: _service,
          productionService: widget.productionService,
        ),
      ),
    );

    if (result == true && mounted) {
      _refreshStream();
    }
  }

  Future<void> _navigateToEdit(Rehearsal rehearsal) async {
    final result = await Navigator.of(context).push<Rehearsal>(
      MaterialPageRoute(
        builder: (context) => AddRehearsalScreen(
          initialRehearsal: rehearsal,
          rehearsalService: _service,
          productionService: widget.productionService,
        ),
      ),
    );

    if (result != null && mounted) {
      _refreshStream();
    }
  }

  Future<void> _deleteRehearsal(Rehearsal rehearsal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rehearsal'),
        content: Text('Are you sure you want to delete "${rehearsal.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteRehearsal(rehearsal.id);
      if (!mounted) return;
      _refreshStream();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${rehearsal.title}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete "${rehearsal.title}": $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  List<Rehearsal> _filterRehearsals(List<Rehearsal> rehearsals) {
    return rehearsals.where((r) {
      // Production filter
      if (_selectedProductionFilter != null &&
          _selectedProductionFilter!.isNotEmpty &&
          r.productionId != _selectedProductionFilter) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = r.title.toLowerCase().contains(query);
        final matchesVenue = r.venue.toLowerCase().contains(query);
        final matchesNotes = r.notes.toLowerCase().contains(query);
        final matchesProd = r.productionId.toLowerCase().contains(query);
        if (!matchesTitle && !matchesVenue && !matchesNotes && !matchesProd) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = StreamBuilder<List<Rehearsal>>(
      stream: _rehearsalsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load rehearsals',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${snapshot.error}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _refreshStream,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Try Again'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1E3F),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final rawList = snapshot.data ?? [];
        final filteredList = _filterRehearsals(rawList);

        return RefreshIndicator(
          onRefresh: () async {
            _refreshStream();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderRow(theme, rawList.length),
                      const SizedBox(height: 16),
                      _buildSearchAndFilters(theme, rawList),
                    ],
                  ),
                ),
              ),

              if (rawList.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    theme: theme,
                    title: 'No Rehearsals Scheduled',
                    subtitle: 'Schedule your first rehearsal run-through to coordinate call times and stage spaces.',
                  ),
                )
              else if (filteredList.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(
                    theme: theme,
                    title: 'No Matching Rehearsals',
                    subtitle:
                        'Try adjusting your search query or production filter.',
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

                      if (width >= 1050) {
                        crossAxisCount = 3;
                      } else if (width >= 650) {
                        crossAxisCount = 2;
                      } else {
                        crossAxisCount = 1;
                      }

                      if (crossAxisCount == 1) {
                        return SliverList(
                          delegate: SliverChildBuilderDelegate((
                            itemContext,
                            index,
                          ) {
                            final item = filteredList[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: RehearsalCard(
                                rehearsal: item,
                                onTap: () => _navigateToDetails(item),
                                onEdit: () => _navigateToEdit(item),
                                onDelete: () => _deleteRehearsal(item),
                              ),
                            );
                          }, childCount: filteredList.length),
                        );
                      }

                      final childAspectRatio = crossAxisCount == 2
                          ? 1.30
                          : 1.35;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: childAspectRatio,
                        ),
                        delegate: SliverChildBuilderDelegate((
                          itemContext,
                          index,
                        ) {
                          final item = filteredList[index];
                          return RehearsalCard(
                            rehearsal: item,
                            onTap: () => _navigateToDetails(item),
                            onEdit: () => _navigateToEdit(item),
                            onDelete: () => _deleteRehearsal(item),
                          );
                        }, childCount: filteredList.length),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );

    final fab = FloatingActionButton.extended(
      key: const Key('add_rehearsal_fab'),
      onPressed: _navigateToAddRehearsal,
      backgroundColor: const Color(0xFF8B1E3F),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Schedule Rehearsal'),
    );

    if (!widget.showAppBar) {
      return Scaffold(body: content, floatingActionButton: fab);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rehearsals',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: MediaQuery.sizeOf(context).width < 500
                ? IconButton(
                    key: const Key('appbar_schedule_rehearsal_button'),
                    onPressed: _navigateToAddRehearsal,
                    icon: const Icon(Icons.add),
                    tooltip: 'Schedule Rehearsal',
                  )
                : FilledButton.icon(
                    key: const Key('appbar_schedule_rehearsal_button'),
                    onPressed: _navigateToAddRehearsal,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Schedule Rehearsal'),
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
      floatingActionButton: fab,
    );
  }

  Widget _buildHeaderRow(ThemeData theme, int totalCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rehearsal Schedule',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Total scheduled: $totalCount',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(
    ThemeData theme,
    List<Rehearsal> allRehearsals,
  ) {
    // Unique production IDs present in rehearsals plus any active selection
    final productionIds = {
      if (_selectedProductionFilter != null &&
          _selectedProductionFilter!.trim().isNotEmpty)
        _selectedProductionFilter!.trim(),
      ...allRehearsals
          .map((r) => r.productionId.trim())
          .where((id) => id.isNotEmpty),
    }.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText:
                'Search by rehearsal title, venue, notes, or production...',
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
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
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

        // Production filter chips if available
        if (productionIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: const Text('All Productions'),
                    selected: _selectedProductionFilter == null,
                    onSelected: (selected) {
                      setState(() {
                        _selectedProductionFilter = null;
                      });
                    },
                    selectedColor: const Color(0xFF8B1E3F)
                        .withValues(alpha: 0.15),
                    checkmarkColor: const Color(0xFF8B1E3F),
                    labelStyle: TextStyle(
                      color: _selectedProductionFilter == null
                          ? const Color(0xFF8B1E3F)
                          : theme.colorScheme.onSurface,
                      fontWeight: _selectedProductionFilter == null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
                ...productionIds.map((pId) {
                  final isSelected = _selectedProductionFilter == pId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(pId),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedProductionFilter = selected ? pId : null;
                        });
                      },
                      selectedColor: const Color(0xFF8B1E3F)
                          .withValues(alpha: 0.15),
                      checkmarkColor: const Color(0xFF8B1E3F),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? const Color(0xFF8B1E3F)
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B1E3F).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered ? Icons.search_off : Icons.event_repeat_rounded,
                size: 38,
                color: const Color(0xFF8B1E3F),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('empty_schedule_rehearsal_button'),
                onPressed: _navigateToAddRehearsal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Schedule Rehearsal'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1E3F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const Key('clear_filters_button'),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedProductionFilter = null;
                      });
                    },
                    icon: const Icon(Icons.filter_alt_off, size: 16),
                    label: const Text('Clear Filters'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('filtered_schedule_rehearsal_button'),
                    onPressed: _navigateToAddRehearsal,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Schedule Rehearsal'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1E3F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
