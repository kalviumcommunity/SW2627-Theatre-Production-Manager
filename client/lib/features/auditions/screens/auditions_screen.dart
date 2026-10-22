import 'package:flutter/material.dart';

import '../../productions/services/production_service.dart';
import '../models/audition_model.dart';
import '../services/audition_service.dart';
import '../widgets/audition_card.dart';
import 'add_audition_screen.dart';
import 'audition_details_screen.dart';

class AuditionsScreen extends StatefulWidget {
  final AuditionService? auditionService;
  final ProductionService? productionService;
  final bool showAppBar;
  final String? initialProductionFilter;

  const AuditionsScreen({
    super.key,
    this.auditionService,
    this.productionService,
    this.showAppBar = true,
    this.initialProductionFilter,
  });

  @override
  State<AuditionsScreen> createState() => _AuditionsScreenState();
}

class _AuditionsScreenState extends State<AuditionsScreen> {
  late AuditionService _service;
  late Stream<List<Audition>> _auditionsStream;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedProductionFilter;

  @override
  void initState() {
    super.initState();
    _service = widget.auditionService ?? AuditionService();
    _selectedProductionFilter = widget.initialProductionFilter;
    _auditionsStream = _service.streamAuditions();
  }

  @override
  void didUpdateWidget(AuditionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.auditionService != oldWidget.auditionService) {
      _service = widget.auditionService ?? AuditionService();
      _auditionsStream = _service.streamAuditions();
    }
    if (widget.initialProductionFilter != oldWidget.initialProductionFilter) {
      setState(() {
        _selectedProductionFilter = widget.initialProductionFilter;
      });
    }
  }

  void _refreshStream() {
    setState(() {
      _auditionsStream = _service.streamAuditions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _navigateToAddAudition() async {
    final result = await Navigator.of(context).push<Audition>(
      MaterialPageRoute(
        builder: (context) => AddAuditionScreen(
          auditionService: _service,
          productionService: widget.productionService,
          initialProductionId: _selectedProductionFilter,
        ),
      ),
    );

    if (result != null && mounted) {
      _refreshStream();
    }
  }

  Future<void> _navigateToDetails(Audition audition) async {
    final result = await Navigator.of(context).push<Audition>(
      MaterialPageRoute(
        builder: (context) => AuditionDetailsScreen(
          audition: audition,
          auditionService: _service,
          productionService: widget.productionService,
        ),
      ),
    );

    if (result != null && mounted) {
      _refreshStream();
    }
  }

  Future<void> _navigateToEdit(Audition audition) async {
    final result = await Navigator.of(context).push<Audition>(
      MaterialPageRoute(
        builder: (context) => AddAuditionScreen(
          initialAudition: audition,
          auditionService: _service,
          productionService: widget.productionService,
        ),
      ),
    );

    if (result != null && mounted) {
      _refreshStream();
    }
  }

  Future<void> _cancelAudition(Audition audition) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Audition'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel "${audition.title}"?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Cancel Audition'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final reason = reasonController.text.trim();
      await _service.cancelAudition(
        audition.id,
        reason: reason.isNotEmpty ? reason : null,
      );
      if (!mounted) return;
      _refreshStream();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancelled "${audition.title}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel audition: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Audition> _applyFilters(List<Audition> allAuditions) {
    return allAuditions.where((a) {
      // Production filter
      if (_selectedProductionFilter != null &&
          _selectedProductionFilter!.isNotEmpty) {
        if (a.productionId != _selectedProductionFilter) {
          return false;
        }
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = a.title.toLowerCase().contains(q);
        final matchesVenue = a.venue.toLowerCase().contains(q);
        final matchesProd = a.productionId.toLowerCase().contains(q);
        final matchesReq = a.requirements.toLowerCase().contains(q);
        return matchesTitle || matchesVenue || matchesProd || matchesReq;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'Auditions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddAudition,
        backgroundColor: const Color(0xFF8B1E3F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Schedule Audition'),
      ),
      body: StreamBuilder<List<Audition>>(
        stream: _auditionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load auditions',
                      style: theme.textTheme.titleMedium,
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
                    FilledButton(
                      onPressed: _refreshStream,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allAuditions = snapshot.data ?? [];
          final filteredAuditions = _applyFilters(allAuditions);

          return LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;

              return Column(
                children: [
                  // Search & Filter header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search bar
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search auditions by title, venue...',
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
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim();
                            });
                          },
                        ),

                        // Active filter chips
                        if (_selectedProductionFilter != null &&
                            _selectedProductionFilter!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Chip(
                                avatar: const Icon(
                                  Icons.theater_comedy,
                                  size: 16,
                                  color: Color(0xFF8B1E3F),
                                ),
                                label: Text(
                                  'Production: $_selectedProductionFilter',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  setState(() {
                                    _selectedProductionFilter = null;
                                  });
                                },
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedProductionFilter = null;
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                                icon: const Icon(
                                  Icons.filter_alt_off,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Clear Filters',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Content: List or Empty
                  Expanded(
                    child: filteredAuditions.isEmpty
                        ? _buildEmptyState(theme, allAuditions.isNotEmpty)
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              isNarrow ? 80 : 24,
                            ),
                            itemCount: filteredAuditions.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final audition = filteredAuditions[index];
                              return AuditionCard(
                                audition: audition,
                                onTap: () => _navigateToDetails(audition),
                                onEdit: audition.isCancelled
                                    ? null
                                    : () => _navigateToEdit(audition),
                                onCancel: audition.isCancelled
                                    ? null
                                    : () => _cancelAudition(audition),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool hasUnfilteredAuditions) {
    final isFiltered =
        _searchQuery.isNotEmpty ||
        (_selectedProductionFilter != null &&
            _selectedProductionFilter!.isNotEmpty);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8B1E3F).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.how_to_reg_outlined,
                size: 48,
                color: Color(0xFF8B1E3F),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered
                  ? 'No Auditions Match Your Filter'
                  : 'No Auditions Scheduled Yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Try modifying your search query or clear the active production filter.'
                  : 'Start casting for your productions by scheduling your first audition session.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (isFiltered)
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _selectedProductionFilter = null;
                  });
                },
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Clear Filters'),
              )
            else
              FilledButton.icon(
                onPressed: _navigateToAddAudition,
                icon: const Icon(Icons.add),
                label: const Text('Schedule Audition'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1E3F),
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
