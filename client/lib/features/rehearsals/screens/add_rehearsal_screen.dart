import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:client/services/auth_service.dart';

import '../../productions/models/production_model.dart';
import '../../productions/services/production_service.dart';
import '../exceptions/rehearsal_exceptions.dart';
import '../models/rehearsal_model.dart';
import '../services/rehearsal_service.dart';

class AddRehearsalScreen extends StatefulWidget {
  final RehearsalService? rehearsalService;
  final ProductionService? productionService;
  final AuthService? authService;
  final Rehearsal? initialRehearsal;
  final String? initialProductionId;
  final bool checkProductionExists;

  const AddRehearsalScreen({
    super.key,
    this.rehearsalService,
    this.productionService,
    this.authService,
    this.initialRehearsal,
    this.initialProductionId,
    this.checkProductionExists = true,
  });

  @override
  State<AddRehearsalScreen> createState() => _AddRehearsalScreenState();
}

class _AddRehearsalScreenState extends State<AddRehearsalScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _productionIdController;
  late final TextEditingController _venueController;
  late final TextEditingController _notesController;

  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String? _timeError;
  VenueConflictException? _venueConflict;

  bool _isSaving = false;
  List<Production> _availableProductions = [];
  bool _loadingProductions = false;

  late final RehearsalService _service;
  late final ProductionService _productionService;
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _service = widget.rehearsalService ?? RehearsalService();
    _productionService = widget.productionService ?? ProductionService();
    _authService = widget.authService ?? AuthService();

    final init = widget.initialRehearsal;
    _titleController = TextEditingController(text: init?.title ?? 'Rehearsal');
    _productionIdController = TextEditingController(
      text: init?.productionId ?? widget.initialProductionId ?? '',
    );
    _venueController = TextEditingController(
      text: init?.venueName.isNotEmpty == true
          ? init!.venueName
          : (init?.venueId ?? ''),
    );
    _notesController = TextEditingController(text: init?.notes ?? '');

    final now = DateTime.now();
    _selectedDate =
        init?.startTime ?? DateTime(now.year, now.month, now.day + 1);
    _startTime = init != null
        ? TimeOfDay(hour: init.startTime.hour, minute: init.startTime.minute)
        : const TimeOfDay(hour: 14, minute: 0);
    _endTime = init != null
        ? TimeOfDay(hour: init.endTime.hour, minute: init.endTime.minute)
        : const TimeOfDay(hour: 16, minute: 30);

    _loadAvailableProductions();
  }

  Future<void> _loadAvailableProductions() async {
    // Only attempt loading if productionService was provided or in real app runtime with Firebase initialized
    final hasInjectedService = widget.productionService != null;
    final isFirebaseReady = Firebase.apps.isNotEmpty;
    if (!hasInjectedService && !isFirebaseReady) return;

    setState(() {
      _loadingProductions = true;
    });
    try {
      final productions = await _productionService.getProductions().timeout(
        const Duration(seconds: 2),
      );
      if (mounted) {
        setState(() {
          _availableProductions = productions;
          _loadingProductions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingProductions = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _productionIdController.dispose();
    _venueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime get _calculatedStartDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
  }

  DateTime get _calculatedEndDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );
  }

  bool _validateTimes() {
    final start = _calculatedStartDateTime;
    final end = _calculatedEndDateTime;

    if (!end.isAfter(start)) {
      setState(() {
        _timeError = 'End time must be after start time (rehearsal duration cannot be zero or negative).';
      });
      return false;
    }

    if (_timeError != null) {
      setState(() {
        _timeError = null;
      });
    }
    return true;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final minDate = DateTime(now.year - 2);
    final maxDate = DateTime(now.year + 5);
    final firstDate = _selectedDate.isBefore(minDate) ? _selectedDate : minDate;
    final lastDate = _selectedDate.isAfter(maxDate) ? _selectedDate : maxDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select Rehearsal Date',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _venueConflict = null;
        _validateTimes();
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Select Start Call Time',
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;
        _venueConflict = null;
        _validateTimes();
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: 'Select Rehearsal End Time',
    );

    if (picked != null) {
      setState(() {
        _endTime = picked;
        _venueConflict = null;
        _validateTimes();
      });
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _onSave() async {
    if (_isSaving) return;

    final isFormValid = _formKey.currentState?.validate() ?? false;
    final areTimesValid = _validateTimes();

    if (!isFormValid || !areTimesValid) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the errors in the form before saving.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _venueConflict = null;
    });

    final isEditing =
        widget.initialRehearsal != null &&
        widget.initialRehearsal!.id.isNotEmpty;

    final startDateTime = _calculatedStartDateTime;
    final endDateTime = _calculatedEndDateTime;
    final venueText = _venueController.text.trim();
    final productionIdText = _productionIdController.text.trim();

    // Determine creator UID
    String creatorUid = 'cast-member';
    try {
      final user = _authService.currentUser;
      if (user?.uid.isNotEmpty == true) {
        creatorUid = user!.uid;
      } else if (widget.initialRehearsal?.creatorUid.isNotEmpty == true) {
        creatorUid = widget.initialRehearsal!.creatorUid;
      }
    } catch (_) {
      if (widget.initialRehearsal?.creatorUid.isNotEmpty == true) {
        creatorUid = widget.initialRehearsal!.creatorUid;
      }
    }

    final rehearsal = Rehearsal(
      id: widget.initialRehearsal?.id ?? '',
      productionId: productionIdText,
      title: _titleController.text.trim(),
      venueId: venueText,
      venueName: venueText,
      startTime: startDateTime,
      endTime: endDateTime,
      creatorUid: creatorUid,
      notes: _notesController.text.trim(),
      createdAt: widget.initialRehearsal?.createdAt ?? DateTime.now(),
    );

    try {
      final Rehearsal saved;
      if (isEditing) {
        await _service.updateRehearsal(
          rehearsal,
          checkProductionExists: widget.checkProductionExists,
        );
        saved = rehearsal;
      } else {
        saved = await _service.createRehearsal(
          rehearsal,
          checkProductionExists: widget.checkProductionExists,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Rehearsal "${saved.title}" updated successfully!'
                : 'Rehearsal "${saved.title}" scheduled successfully!',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF8B1E3F),
        ),
      );

      Navigator.of(context).pop(saved);
    } on VenueConflictException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _venueConflict = e;
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.amber.shade900,
          duration: const Duration(seconds: 5),
        ),
      );
    } on RehearsalValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Failed to update rehearsal: $e'
                : 'Failed to schedule rehearsal: $e',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing =
        widget.initialRehearsal != null &&
        widget.initialRehearsal!.id.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Rehearsal' : 'Schedule Rehearsal',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form header card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B1E3F).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8B1E3F).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_repeat_rounded,
                          color: Color(0xFF8B1E3F),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isEditing
                                ? 'Edit Rehearsal Session'
                                : 'New Rehearsal Session',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF8B1E3F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Venue Conflict Alert Banner
                  if (_venueConflict != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      key: const Key('venue_conflict_alert'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.shade700,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber.shade900,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Venue Conflict Detected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _venueConflict!.message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.brown.shade800,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Please choose a different call time or stage space.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Rehearsal Title (Required)
                  TextFormField(
                    key: const Key('rehearsal_title_input'),
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Rehearsal Title *',
                      hintText: 'e.g. Full Run-Through, Act I Scene 2',
                      prefixIcon: const Icon(
                        Icons.event_note_outlined,
                        size: 20,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Rehearsal title is required and cannot be empty.';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),

                  // Production Selection / ID (Required)
                  TextFormField(
                    key: const Key('rehearsal_production_input'),
                    controller: _productionIdController,
                    decoration: InputDecoration(
                      labelText: 'Production ID *',
                      hintText: 'e.g. prod-001 or select from below',
                      prefixIcon: const Icon(
                        Icons.theater_comedy_outlined,
                        size: 20,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _loadingProductions
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Production ID is required.';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),

                  // Quick production selection chips if productions are loaded
                  if (_availableProductions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            'Quick select:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ..._availableProductions.map((p) {
                            final isSelected =
                                _productionIdController.text.trim() == p.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ActionChip(
                                label: Text(p.title),
                                avatar: isSelected
                                    ? const Icon(Icons.check, size: 14)
                                    : null,
                                onPressed: () {
                                  setState(() {
                                    _productionIdController.text = p.id;
                                  });
                                },
                                backgroundColor: isSelected
                                    ? const Color(0xFF8B1E3F)
                                          .withValues(alpha: 0.15)
                                    : theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.4),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Venue Input (Required)
                  TextFormField(
                    key: const Key('rehearsal_venue_input'),
                    controller: _venueController,
                    decoration: InputDecoration(
                      labelText: 'Venue *',
                      hintText: 'e.g. Main Auditorium, Studio A, Black Box',
                      prefixIcon: const Icon(
                        Icons.location_on_outlined,
                        size: 20,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Venue is required.';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),

                  // Date Picker Tile
                  _buildDatePickerTile(theme),
                  const SizedBox(height: 10),

                  // Start and End Time Pickers
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimePickerTile(
                          theme: theme,
                          label: 'Start Time',
                          time: _startTime,
                          icon: Icons.play_arrow_outlined,
                          onTap: _pickStartTime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimePickerTile(
                          theme: theme,
                          label: 'End Time',
                          time: _endTime,
                          icon: Icons.stop_outlined,
                          onTap: _pickEndTime,
                        ),
                      ),
                    ],
                  ),

                  // Time range validation error message
                  if (_timeError != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      key: const Key('time_range_error'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _timeError!,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Rehearsal Notes (Optional)
                  TextFormField(
                    key: const Key('rehearsal_notes_input'),
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Rehearsal Notes & Scene Run',
                      hintText: 'Scenes covered, character calls, props, choreography notes...',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignLabelWithHint: true,
                    ),
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                        FilledButton.icon(
                          key: const Key('save_rehearsal_button'),
                          onPressed: _isSaving ? null : _onSave,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check, size: 16),
                          label: Text(
                            _isSaving
                                ? 'Saving Rehearsal...'
                                : 'Save Rehearsal',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF8B1E3F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildDatePickerTile(ThemeData theme) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: Color(0xFF8B1E3F),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rehearsal Date',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(_selectedDate),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerTile({
    required ThemeData theme,
    required String label,
    required TimeOfDay time,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF8B1E3F)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimeOfDay(time),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
