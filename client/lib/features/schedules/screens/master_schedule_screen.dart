import 'package:flutter/material.dart';
import 'package:client/features/auditions/models/audition_model.dart';
import 'package:client/features/auditions/screens/audition_details_screen.dart';
import 'package:client/features/auditions/services/audition_service.dart';
import 'package:client/features/productions/services/production_service.dart';
import 'package:client/features/rehearsals/models/rehearsal_model.dart';
import 'package:client/features/rehearsals/screens/rehearsal_details_screen.dart';
import 'package:client/features/rehearsals/services/rehearsal_service.dart';
import 'package:client/services/auth_service.dart';
import 'package:client/services/user_service.dart';
import '../models/schedule_event_model.dart';
import '../services/schedule_service.dart';
import '../widgets/schedule_event_card.dart';

class MasterScheduleScreen extends StatefulWidget {
  final bool showAppBar;
  final ScheduleService? scheduleService;
  final AuthService? authService;
  final UserService? userService;
  final ProductionService? productionService;
  final RehearsalService? rehearsalService;
  final AuditionService? auditionService;

  const MasterScheduleScreen({
    super.key,
    this.showAppBar = true,
    this.scheduleService,
    this.authService,
    this.userService,
    this.productionService,
    this.rehearsalService,
    this.auditionService,
  });

  @override
  State<MasterScheduleScreen> createState() => _MasterScheduleScreenState();
}

class _MasterScheduleScreenState extends State<MasterScheduleScreen> {
  late final ScheduleService _scheduleService;
  late final AuthService _authService;
  late final UserService _userService;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _userRole = 'Cast Member';
  String? _userId;

  DateTime? _selectedDate;
  String _activeFilter = 'All'; // 'All', 'Upcoming', 'Today', 'Rehearsals', 'Auditions'

  List<ScheduleEvent> _events = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _userService = widget.userService ?? UserService();
    _scheduleService = widget.scheduleService ??
        ScheduleService(
          productionService: widget.productionService,
          rehearsalService: widget.rehearsalService,
          auditionService: widget.auditionService,
        );

    _initUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initUserData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        _userId = user.uid;
        final profile = await _userService.getUserProfile(user.uid);
        if (profile != null && profile['role'] != null) {
          _userRole = profile['role'].toString();
        }
      }
    } catch (_) {}

    await _loadEvents();
  }

  bool get _isDirector => _userRole == 'Director';

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _scheduleService.getScheduleEvents(
        userId: _userId,
        isDirector: _isDirector,
        dateFilter: _selectedDate,
      );

      if (mounted) {
        setState(() {
          _events = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF8B1E3F),
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadEvents();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
    _loadEvents();
  }

  void _onEventTap(ScheduleEvent event) {
    if (event.isRehearsal && event.originalObject is Rehearsal) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => RehearsalDetailsScreen(
            rehearsal: event.originalObject as Rehearsal,
            rehearsalService: widget.rehearsalService,
            productionService: widget.productionService,
          ),
        ),
      ).then((_) => _loadEvents());
    } else if (event.isAudition && event.originalObject is Audition) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => AuditionDetailsScreen(
            audition: event.originalObject as Audition,
            auditionService: widget.auditionService,
            productionService: widget.productionService,
          ),
        ),
      ).then((_) => _loadEvents());
    }
  }

  List<ScheduleEvent> get _filteredEvents {
    return _events.where((e) {
      // Tab filter
      if (_activeFilter == 'Upcoming' && !e.isUpcoming) return false;
      if (_activeFilter == 'Today' && !e.isToday) return false;
      if (_activeFilter == 'Rehearsals' && !e.isRehearsal) return false;
      if (_activeFilter == 'Auditions' && !e.isAudition) return false;

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return e.title.toLowerCase().contains(q) ||
            e.productionTitle.toLowerCase().contains(q) ||
            e.venue.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Column(
      children: [
        // Controls: Search bar & Date picker action
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('schedule_search_input'),
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search schedule by title, show, or venue...',
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
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    key: const Key('schedule_date_picker_button'),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}'
                          : 'Date',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  if (_selectedDate != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Clear Date Filter',
                      onPressed: _clearDateFilter,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Filter Chips: All, Upcoming, Today, Rehearsals, Auditions
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'All',
                    'Upcoming',
                    'Today',
                    'Rehearsals',
                    'Auditions',
                  ].map((filter) {
                    final isSel = _activeFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSel,
                        selectedColor:
                            const Color(0xFF8B1E3F).withValues(alpha: 0.15),
                        checkmarkColor: const Color(0xFF8B1E3F),
                        labelStyle: TextStyle(
                          color: isSel
                              ? const Color(0xFF8B1E3F)
                              : theme.colorScheme.onSurface,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _activeFilter = filter;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Events Agenda View
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 12),
                          Text('Error loading schedule: $_errorMessage'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _loadEvents,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _filteredEvents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 64,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty || _selectedDate != null
                                    ? 'No schedule events found for this filter.'
                                    : 'No events scheduled yet.',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadEvents,
                          child: LayoutBuilder(
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
                                    mainAxisExtent: 165,
                                  ),
                                  itemCount: _filteredEvents.length,
                                  itemBuilder: (context, index) {
                                    final event = _filteredEvents[index];
                                    return ScheduleEventCard(
                                      event: event,
                                      onTap: () => _onEventTap(event),
                                    );
                                  },
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredEvents.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final event = _filteredEvents[index];
                                  return ScheduleEventCard(
                                    event: event,
                                    onTap: () => _onEventTap(event),
                                  );
                                },
                              );
                            },
                          ),
                        ),
        ),
      ],
    );

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Master Schedule',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loadEvents,
            ),
          ],
        ),
        body: content,
      );
    }

    return content;
  }
}
