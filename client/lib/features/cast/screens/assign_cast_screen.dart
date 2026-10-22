import 'package:flutter/material.dart';
import 'package:client/features/productions/models/production_model.dart';
import 'package:client/features/productions/services/production_service.dart';
import '../models/cast_assignment_model.dart';
import '../services/cast_service.dart';

class AssignCastScreen extends StatefulWidget {
  final CastAssignment? assignment;
  final String? initialProductionId;
  final CastService? castService;
  final ProductionService? productionService;

  const AssignCastScreen({
    super.key,
    this.assignment,
    this.initialProductionId,
    this.castService,
    this.productionService,
  });

  bool get isEditing => assignment != null;

  @override
  State<AssignCastScreen> createState() => _AssignCastScreenState();
}

class _AssignCastScreenState extends State<AssignCastScreen> {
  final _formKey = GlobalKey<FormState>();

  late final CastService _castService;
  late final ProductionService _productionService;

  String? _selectedProductionId;
  String? _selectedUserId;

  late final TextEditingController _roleController;
  late final TextEditingController _actorNameController;
  late final TextEditingController _actorEmailController;
  late final TextEditingController _notesController;

  String _selectedStatus = CastAssignmentStatus.assigned;
  bool _isSaving = false;
  String? _errorMessage;

  List<Production> _productions = [];
  List<EligibleUser> _eligibleUsers = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _castService = widget.castService ?? CastService();
    _productionService = widget.productionService ?? ProductionService();

    final init = widget.assignment;
    _selectedProductionId = init?.productionId ?? widget.initialProductionId;
    _selectedUserId = init?.userId;

    _roleController = TextEditingController(text: init?.characterRole ?? '');
    _actorNameController = TextEditingController(text: init?.actorName ?? '');
    _actorEmailController = TextEditingController(text: init?.actorEmail ?? '');
    _notesController = TextEditingController(text: init?.notes ?? '');
    if (init != null) {
      _selectedStatus = init.status;
    }

    _loadDependencies();
  }

  @override
  void dispose() {
    _roleController.dispose();
    _actorNameController.dispose();
    _actorEmailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDependencies() async {
    try {
      final prods = await _productionService.getProductions();
      final users = await _castService.getEligibleUsers();

      if (mounted) {
        setState(() {
          _productions = prods;
          _eligibleUsers = users;
          _isLoadingData = false;

          if (_selectedProductionId == null && prods.isNotEmpty) {
            _selectedProductionId = prods.first.id;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  void _onEligibleUserSelected(EligibleUser? user) {
    if (user != null) {
      setState(() {
        _selectedUserId = user.uid;
        _actorNameController.text = user.name;
        _actorEmailController.text = user.email;
      });
    }
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProductionId == null || _selectedProductionId!.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please select a production.';
      });
      return;
    }

    final userId = (_selectedUserId != null && _selectedUserId!.trim().isNotEmpty)
        ? _selectedUserId!.trim()
        : 'user-${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final assignment = CastAssignment(
        id: widget.assignment?.id ?? '',
        productionId: _selectedProductionId!.trim(),
        userId: userId,
        characterRole: _roleController.text.trim(),
        actorName: _actorNameController.text.trim(),
        actorEmail: _actorEmailController.text.trim(),
        status: _selectedStatus,
        notes: _notesController.text.trim(),
        assignedAt: widget.assignment?.assignedAt,
      );

      if (widget.isEditing) {
        await _castService.updateCastAssignment(assignment);
      } else {
        await _castService.assignCastMember(assignment);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DuplicateRoleException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.isEditing ? 'Edit Cast Assignment' : 'Assign Role';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            key: const Key('assignment_error_banner'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: theme.colorScheme.error),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                        color: theme.colorScheme.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Production Selector
                        Text(
                          'Production *',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        if (_productions.isNotEmpty)
                          DropdownButtonFormField<String>(
                            key: const Key('cast_production_dropdown'),
                            isExpanded: true,
                            initialValue: _selectedProductionId,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.theater_comedy),
                            ),
                            items: _productions.map((p) {
                              return DropdownMenuItem(
                                value: p.id,
                                child: Text(p.title),
                              );
                            }).toList(),
                            onChanged: widget.isEditing
                                ? null
                                : (val) {
                                    setState(() {
                                      _selectedProductionId = val;
                                    });
                                  },
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Production is required.';
                              }
                              return null;
                            },
                          )
                        else
                          TextFormField(
                            initialValue: _selectedProductionId ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Production ID *',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) => _selectedProductionId = val.trim(),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Production ID is required.';
                              }
                              return null;
                            },
                          ),
                        const SizedBox(height: 18),

                        // Character Role
                        Text(
                          'Character / Part Name *',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('character_role_input'),
                          controller: _roleController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Romeo, Juliet, Mercutio, Stage Manager',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.star_outline),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Character role is required.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Eligible User Quick-Select (if available)
                        if (_eligibleUsers.isNotEmpty) ...[
                          Text(
                            'Select Registered Cast Member (Optional)',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            key: const Key('eligible_user_dropdown'),
                            initialValue: _selectedUserId,
                            decoration: const InputDecoration(
                              hintText: 'Choose from registered cast...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.how_to_reg_outlined),
                            ),
                            items: _eligibleUsers.map((u) {
                              return DropdownMenuItem(
                                value: u.uid,
                                child: Text('${u.name} (${u.email})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              final u = _eligibleUsers.firstWhere(
                                (item) => item.uid == val,
                                orElse: () => EligibleUser(uid: '', name: ''),
                              );
                              if (u.uid.isNotEmpty) {
                                _onEligibleUserSelected(u);
                              }
                            },
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Actor Name
                        Text(
                          'Actor / Member Name *',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('actor_name_input'),
                          controller: _actorNameController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Jane Doe',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Actor name is required.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Actor Email
                        Text(
                          'Actor Contact Email',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('actor_email_input'),
                          controller: _actorEmailController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. actor@theatre.org',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Status
                        Text(
                          'Role Status',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          key: const Key('cast_status_dropdown'),
                          isExpanded: true,
                          initialValue: _selectedStatus,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.assignment_turned_in_outlined),
                          ),
                          items: CastAssignmentStatus.all.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(s),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedStatus = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 18),

                        // Notes
                        Text(
                          'Notes / Casting Details',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('cast_notes_input'),
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Costume measurements, conflict restrictions, vocal range...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            key: const Key('save_cast_assignment_button'),
                            onPressed: _isSaving ? null : _saveAssignment,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF8B1E3F),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(widget.isEditing
                                    ? 'Update Assignment'
                                    : 'Confirm Assignment'),
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
