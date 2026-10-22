import 'package:flutter/material.dart';
import 'package:client/features/productions/models/production_model.dart';
import 'package:client/features/productions/services/production_service.dart';
import 'package:client/services/auth_service.dart';
import 'package:client/services/user_service.dart';
import '../models/cast_assignment_model.dart';
import '../services/cast_service.dart';
import '../widgets/cast_member_card.dart';
import 'assign_cast_screen.dart';

class CastScreen extends StatefulWidget {
  final bool showAppBar;
  final String? initialProductionFilter;
  final CastService? castService;
  final ProductionService? productionService;
  final AuthService? authService;
  final UserService? userService;

  const CastScreen({
    super.key,
    this.showAppBar = true,
    this.initialProductionFilter,
    this.castService,
    this.productionService,
    this.authService,
    this.userService,
  });

  @override
  State<CastScreen> createState() => _CastScreenState();
}

class _CastScreenState extends State<CastScreen> {
  late final CastService _castService;
  late final ProductionService _productionService;
  late final AuthService _authService;
  late final UserService _userService;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedProductionId;
  String _userRole = 'Cast Member';

  List<Production> _productions = [];
  Map<String, String> _productionTitles = {};

  @override
  void initState() {
    super.initState();
    _castService = widget.castService ?? CastService();
    _productionService = widget.productionService ?? ProductionService();
    _authService = widget.authService ?? AuthService();
    _userService = widget.userService ?? UserService();

    _selectedProductionId = widget.initialProductionFilter;

    _loadUserRole();
    _loadProductions();
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

  Future<void> _loadProductions() async {
    try {
      final prods = await _productionService.getProductions();
      if (mounted) {
        setState(() {
          _productions = prods;
          _productionTitles = {for (var p in prods) p.id: p.title};
        });
      }
    } catch (_) {}
  }

  void _navigateToAssignRole([CastAssignment? assignment]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AssignCastScreen(
          assignment: assignment,
          initialProductionId: _selectedProductionId,
          castService: _castService,
          productionService: _productionService,
        ),
      ),
    );
  }

  Future<void> _removeAssignment(CastAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Role Assignment'),
        content: Text(
          'Are you sure you want to remove "${assignment.actorName}" from the role of "${assignment.characterRole}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _castService.removeCastAssignment(assignment.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cast assignment removed.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove assignment: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = StreamBuilder<List<CastAssignment>>(
      stream: _castService.streamCastAssignments(
        productionId: _selectedProductionId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text('Error loading cast roster: ${snapshot.error}'),
              ],
            ),
          );
        }

        final assignments = snapshot.data ?? [];
        final filteredAssignments = assignments.where((a) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          final prodTitle =
              _productionTitles[a.productionId]?.toLowerCase() ?? '';
          return a.characterRole.toLowerCase().contains(q) ||
              a.actorName.toLowerCase().contains(q) ||
              a.actorEmail.toLowerCase().contains(q) ||
              prodTitle.contains(q);
        }).toList();

        return Column(
          children: [
            // Controls: search + production filter dropdown + assign button
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.surface,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('cast_search_input'),
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search cast by role or actor name...',
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
                          key: const Key('assign_role_button'),
                          onPressed: () => _navigateToAssignRole(),
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: const Text('Assign Role'),
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
                  if (_productions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('All Productions'),
                            selected: _selectedProductionId == null,
                            onSelected: (selected) {
                              setState(() {
                                _selectedProductionId = null;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ..._productions.map((p) {
                            final isSel = _selectedProductionId == p.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text(p.title),
                                selected: isSel,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedProductionId =
                                        selected ? p.id : null;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // Summary bar: Total assigned roles count
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              child: Row(
                children: [
                  Text(
                    '${filteredAssignments.length} Assigned Role${filteredAssignments.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_selectedProductionId != null &&
                      _productionTitles.containsKey(_selectedProductionId)) ...[
                    const SizedBox(width: 6),
                    Text(
                      '• ${_productionTitles[_selectedProductionId]}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8B1E3F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // List of assignments
            Expanded(
              child: filteredAssignments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.groups_outlined,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No cast members match your search.'
                                : 'No cast members assigned yet.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (_isDirector && _searchQuery.isEmpty) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _navigateToAssignRole(),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Assign First Role'),
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
                            itemCount: filteredAssignments.length,
                            itemBuilder: (context, index) {
                              final a = filteredAssignments[index];
                              return CastMemberCard(
                                assignment: a,
                                productionTitle: _productionTitles[a.productionId],
                                isDirector: _isDirector,
                                onEdit: () => _navigateToAssignRole(a),
                                onRemove: () => _removeAssignment(a),
                              );
                            },
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredAssignments.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final a = filteredAssignments[index];
                            return CastMemberCard(
                              assignment: a,
                              productionTitle: _productionTitles[a.productionId],
                              isDirector: _isDirector,
                              onEdit: () => _navigateToAssignRole(a),
                              onRemove: () => _removeAssignment(a),
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
          title: const Text('Cast Management',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: content,
      );
    }

    return content;
  }
}
