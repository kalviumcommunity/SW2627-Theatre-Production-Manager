import 'package:flutter/material.dart';
import '../models/production_model.dart';
import '../services/production_service.dart';

class AddProductionScreen extends StatefulWidget {
  final ProductionService? productionService;
  final Production? initialProduction;

  const AddProductionScreen({
    super.key,
    this.productionService,
    this.initialProduction,
  });

  @override
  State<AddProductionScreen> createState() => _AddProductionScreenState();
}

class _AddProductionScreenState extends State<AddProductionScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _directorController;

  late String _status;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _dateError;

  bool _isSaving = false;
  late final ProductionService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.productionService ?? ProductionService();

    final init = widget.initialProduction;
    _titleController = TextEditingController(text: init?.title ?? '');
    _descriptionController = TextEditingController(text: init?.description ?? '');
    _directorController = TextEditingController(text: init?.director ?? '');
    _status = init?.status ?? ProductionStatus.planning;
    _startDate = init?.startDate;
    _endDate = init?.endDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _directorController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5);
    final lastDate = DateTime(now.year + 10);

    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select Start Date',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _validateDates();
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final firstDate = _startDate ?? DateTime(now.year - 5);
    final lastDate = DateTime(now.year + 10);

    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? now),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select End Date',
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _validateDates();
      });
    }
  }

  bool _validateDates() {
    if (_startDate != null && _endDate != null) {
      if (_endDate!.isBefore(_startDate!)) {
        setState(() {
          _dateError = 'End date cannot be earlier than start date.';
        });
        return false;
      }
    }
    if (_dateError != null) {
      setState(() {
        _dateError = null;
      });
    }
    return true;
  }

  Future<void> _onSave() async {
    if (_isSaving) return;

    // Validate text inputs
    final isFormValid = _formKey.currentState?.validate() ?? false;
    final areDatesValid = _validateDates();

    if (!isFormValid || !areDatesValid) {
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
    });

    final isEditing = widget.initialProduction != null && widget.initialProduction!.id.isNotEmpty;

    try {
      final production = Production(
        id: widget.initialProduction?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        director: _directorController.text.trim().isNotEmpty
            ? _directorController.text.trim()
            : null,
        status: _status,
        startDate: _startDate,
        endDate: _endDate,
        createdAt: widget.initialProduction?.createdAt ?? DateTime.now(),
      );

      final Production saved;
      if (isEditing) {
        await _service.updateProduction(production);
        saved = production;
      } else {
        saved = await _service.createProduction(production);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Production "${saved.title}" updated successfully!'
                : 'Production "${saved.title}" saved successfully!',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF8B1E3F),
        ),
      );

      Navigator.of(context).pop(saved);
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
                ? 'Failed to update production: $e'
                : 'Failed to save production: $e',
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
    final isEditing = widget.initialProduction != null && widget.initialProduction!.id.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Production' : 'Add Production',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          Icons.theater_comedy,
                          color: Color(0xFF8B1E3F),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEditing ? 'Edit Theatre Production' : 'New Theatre Production',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF8B1E3F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Production Title (Required)
                  TextFormField(
                    key: const Key('production_title_input'),
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Production Title *',
                      hintText: 'e.g. The Phantom of the Opera',
                      prefixIcon: const Icon(Icons.movie_creation_outlined, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Production title is required and cannot be empty.';
                      }
                      if (value.trim().length < 2) {
                        return 'Title must be at least 2 characters long.';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    key: const Key('production_description_input'),
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description & Synopsis',
                      hintText: 'Provide a brief summary, script notes, or story premise...',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignLabelWithHint: true,
                    ),
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 12),

                  // Director
                  TextFormField(
                    key: const Key('production_director_input'),
                    controller: _directorController,
                    decoration: InputDecoration(
                      labelText: 'Director (Optional)',
                      hintText: 'e.g. Sarah Jenkins',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  // Status Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: 'Production Status',
                      prefixIcon: const Icon(Icons.flag_outlined, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: ProductionStatus.all.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _status = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Date Range Pickers
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDatePickerTile(
                          label: 'Start Date',
                          date: _startDate,
                          icon: Icons.calendar_month,
                          onTap: _pickStartDate,
                          onClear: () {
                            setState(() {
                              _startDate = null;
                              _validateDates();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDatePickerTile(
                          label: 'End Date',
                          date: _endDate,
                          icon: Icons.event_available,
                          onTap: _pickEndDate,
                          onClear: () {
                            setState(() {
                              _endDate = null;
                              _validateDates();
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  // Date validation error message
                  if (_dateError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _dateError!,
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

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        key: const Key('save_production_button'),
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
                          _isSaving ? 'Saving Production...' : 'Save Production',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1E3F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerTile({
    required String label,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final theme = Theme.of(context);
    final hasDate = date != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF8B1E3F)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (hasDate)
                  InkWell(
                    onTap: onClear,
                    child: Icon(
                      Icons.clear,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasDate ? Production.formatDate(date) : 'Select date',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: hasDate ? FontWeight.bold : FontWeight.normal,
                color: hasDate
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
