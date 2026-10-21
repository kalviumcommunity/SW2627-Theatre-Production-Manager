import 'package:flutter/material.dart';
import 'package:client/services/auth_service.dart';

import '../../productions/models/production_model.dart';
import '../../productions/services/production_service.dart';
import '../models/audition_model.dart';
import '../services/audition_service.dart';

class AddAuditionScreen extends StatefulWidget {
  final AuditionService? auditionService;
  final ProductionService? productionService;
  final AuthService? authService;
  final Audition? initialAudition;
  final String? initialProductionId;
  final bool checkProductionExists;

  const AddAuditionScreen({
    super.key,
    this.auditionService,
    this.productionService,
    this.authService,
    this.initialAudition,
    this.initialProductionId,
    this.checkProductionExists = true,
  });

  @override
  State<AddAuditionScreen> createState() => _AddAuditionScreenState();
}

class _AddAuditionScreenState extends State<AddAuditionScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _productionIdController;
  late final TextEditingController _venueController;
  late final TextEditingController _requirementsController;
  late final TextEditingController _descriptionController;

  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String? _timeError;
  String? _saveError;

  bool _isSaving = false;
  List<Production> _availableProductions = [];

  late final AuditionService _service;
  late final ProductionService _productionService;
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _service = widget.auditionService ?? AuditionService();
    _productionService = widget.productionService ?? ProductionService();
    _authService = widget.authService ?? AuthService();

    final init = widget.initialAudition;
    _titleController = TextEditingController(
      text: init?.title ?? 'Audition Call',
    );
    _productionIdController = TextEditingController(
      text: init?.productionId ?? widget.initialProductionId ?? '',
    );
    _venueController = TextEditingController(text: init?.venue ?? '');
    _requirementsController = TextEditingController(
      text: init?.requirements ?? '',
    );
    _descriptionController = TextEditingController(
      text: init?.description ?? '',
    );

    final now = DateTime.now();
    _selectedDate =
        init?.startTime ?? DateTime(now.year, now.month, now.day + 1);
    _startTime = init != null
        ? TimeOfDay(hour: init.startTime.hour, minute: init.startTime.minute)
        : const TimeOfDay(hour: 10, minute: 0);
    _endTime = init != null
        ? TimeOfDay(hour: init.endTime.hour, minute: init.endTime.minute)
        : const TimeOfDay(hour: 14, minute: 0);

    _loadAvailableProductions();
  }

  Future<void> _loadAvailableProductions() async {
    try {
      final productions = await _productionService.getProductions().timeout(
        const Duration(seconds: 2),
      );
      if (mounted) {
        setState(() {
          _availableProductions = productions;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _productionIdController.dispose();
    _venueController.dispose();
    _requirementsController.dispose();
    _descriptionController.dispose();
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
        _timeError = 'End time must be strictly after start time.';
      });
      return false;
    }

    setState(() {
      _timeError = null;
    });
    return true;
  }

  Future<void> _selectDate() async {
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
      helpText: 'Select Audition Date',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _validateTimes();
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Select Start Time',
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
      _validateTimes();
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: 'Select End Time',
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
      _validateTimes();
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour == 0
        ? 12
        : tod.hour > 12
        ? tod.hour - 12
        : tod.hour;
    final minute = tod.minute.toString().padLeft(2, '0');
    final ampm = tod.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  Future<void> _saveAudition() async {
    setState(() {
      _saveError = null;
    });

    if (!_formKey.currentState!.validate()) return;
    if (!_validateTimes()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      String currentUid = 'director-user-default';
      try {
        final user = _authService.currentUser;
        if (user?.uid.isNotEmpty == true) {
          currentUid = user!.uid;
        } else if (widget.initialAudition?.creatorUid.isNotEmpty == true) {
          currentUid = widget.initialAudition!.creatorUid;
        }
      } catch (_) {
        if (widget.initialAudition?.creatorUid.isNotEmpty == true) {
          currentUid = widget.initialAudition!.creatorUid;
        }
      }

      final audition = Audition(
        id: widget.initialAudition?.id ?? '',
        productionId: _productionIdController.text.trim(),
        title: _titleController.text.trim(),
        venue: _venueController.text.trim(),
        startTime: _calculatedStartDateTime,
        endTime: _calculatedEndDateTime,
        requirements: _requirementsController.text.trim(),
        description: _descriptionController.text.trim(),
        creatorUid: widget.initialAudition?.creatorUid.isNotEmpty == true
            ? widget.initialAudition!.creatorUid
            : currentUid,
        status: widget.initialAudition?.status ?? AuditionStatus.scheduled,
      );

      Audition saved;
      if (widget.initialAudition != null) {
        await _service.updateAudition(
          audition,
          checkProductionExists: widget.checkProductionExists,
        );
        saved = audition;
      } else {
        saved = await _service.createAudition(
          audition,
          checkProductionExists: widget.checkProductionExists,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.initialAudition != null
                ? 'Audition updated successfully'
                : 'Audition scheduled successfully',
          ),
          backgroundColor: const Color(0xFF8B1E3F),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = e.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_saveError ?? 'Failed to save audition'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.initialAudition != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Audition' : 'Schedule Audition',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveAudition,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B1E3F),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error Banner if save failed
                  if (_saveError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _saveError!,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Production Selection
                  Text(
                    'Production *',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_availableProductions.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue:
                          _availableProductions.any(
                            (p) => p.id == _productionIdController.text,
                          )
                          ? _productionIdController.text
                          : null,
                      decoration: InputDecoration(
                        hintText: 'Select Production',
                        prefixIcon: const Icon(Icons.theater_comedy_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: _availableProductions.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text(p.title, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _productionIdController.text = val;
                        }
                      },
                      validator: (val) {
                        if (_productionIdController.text.trim().isEmpty) {
                          return 'Please select or enter a production';
                        }
                        return null;
                      },
                    )
                  else
                    TextFormField(
                      controller: _productionIdController,
                      decoration: InputDecoration(
                        hintText: 'Enter Production ID (e.g. prod-1)',
                        prefixIcon: const Icon(Icons.theater_comedy_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Production ID is required';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Audition Title *',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Lead Roles Call, General Ensemble',
                      prefixIcon: const Icon(Icons.how_to_reg_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Audition title is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Venue
                  Text(
                    'Venue / Location *',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _venueController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Studio Hall A, Rehearsal Stage',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Venue is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date
                  Text(
                    'Date *',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: const Color(0xFF8B1E3F),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatDate(_selectedDate),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Change',
                            style: TextStyle(
                              color: const Color(0xFF8B1E3F),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start and End Times
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Time *',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _selectStartTime,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 18,
                                      color: Color(0xFF8B1E3F),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _formatTimeOfDay(_startTime),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Time *',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _selectEndTime,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _timeError != null
                                        ? Colors.redAccent
                                        : theme.colorScheme.outlineVariant,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_filled,
                                      size: 18,
                                      color: Color(0xFF8B1E3F),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _formatTimeOfDay(_endTime),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_timeError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _timeError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Eligibility / Requirements
                  Text(
                    'Eligibility & Requirements',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _requirementsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Open to ages 18-35. Prepare 16 bars of musical theatre, sheet music provided.',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 24.0),
                        child: Icon(Icons.rule_folder_outlined),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description / Notes
                  Text(
                    'Description & Preparation Notes',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Additional notes regarding cold readings, dance calls, or callback dates...',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40.0),
                        child: Icon(Icons.description_outlined),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveAudition,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving
                            ? 'Saving Audition...'
                            : isEditing
                            ? 'Update Audition'
                            : 'Schedule Audition',
                      ),
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
            ),
          ),
        ),
      ),
    );
  }
}
