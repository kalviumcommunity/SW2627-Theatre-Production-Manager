import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/venue_model.dart';
import '../services/venue_service.dart';

class AddEditVenueScreen extends StatefulWidget {
  final Venue? venue;
  final VenueService? venueService;

  const AddEditVenueScreen({
    super.key,
    this.venue,
    this.venueService,
  });

  bool get isEditing => venue != null;

  @override
  State<AddEditVenueScreen> createState() => _AddEditVenueScreenState();
}

class _AddEditVenueScreenState extends State<AddEditVenueScreen> {
  final _formKey = GlobalKey<FormState>();
  late final VenueService _venueService;

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _capacityController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _facilityInputController;

  final List<String> _facilities = [];
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _venueService = widget.venueService ?? VenueService();
    _nameController = TextEditingController(text: widget.venue?.name ?? '');
    _addressController = TextEditingController(text: widget.venue?.address ?? '');
    _capacityController = TextEditingController(
      text: widget.venue != null ? widget.venue!.capacity.toString() : '',
    );
    _descriptionController =
        TextEditingController(text: widget.venue?.description ?? '');
    _facilityInputController = TextEditingController();

    if (widget.venue != null) {
      _facilities.addAll(widget.venue!.facilities);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
    _descriptionController.dispose();
    _facilityInputController.dispose();
    super.dispose();
  }

  void _addFacility() {
    final text = _facilityInputController.text.trim();
    if (text.isNotEmpty && !_facilities.contains(text)) {
      setState(() {
        _facilities.add(text);
        _facilityInputController.clear();
      });
    }
  }

  void _removeFacility(String facility) {
    setState(() {
      _facilities.remove(facility);
    });
  }

  Future<void> _saveVenue() async {
    if (!_formKey.currentState!.validate()) return;

    final capacity = int.tryParse(_capacityController.text.trim());
    if (capacity == null || capacity <= 0) {
      setState(() {
        _errorMessage = 'Capacity must be a positive integer.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final venue = Venue(
        id: widget.venue?.id ?? '',
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        capacity: capacity,
        description: _descriptionController.text.trim(),
        facilities: _facilities,
        createdAt: widget.venue?.createdAt,
      );

      if (widget.isEditing) {
        await _venueService.updateVenue(venue);
      } else {
        await _venueService.createVenue(venue);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final title = widget.isEditing ? 'Edit Venue' : 'Add New Venue';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
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
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Venue Name
                  Text(
                    'Venue Name *',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('venue_name_input'),
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Main Auditorium, Studio A',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Venue name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Location / Address
                  Text(
                    'Address / Location',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('venue_address_input'),
                    controller: _addressController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Building B, 2nd Floor, Room 204',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin_drop_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Capacity
                  Text(
                    'Capacity (Seats/People) *',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('venue_capacity_input'),
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'e.g. 150',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Capacity is required.';
                      }
                      final parsed = int.tryParse(val.trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Capacity must be greater than zero.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Description
                  Text(
                    'Description / Notes',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('venue_description_input'),
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Acoustics, access instructions, technical specifications...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Facilities
                  Text(
                    'Facilities & Equipment',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('venue_facility_input'),
                          controller: _facilityInputController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Grand Piano, Lighting Grid',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addFacility(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: const Key('add_facility_button'),
                        onPressed: _addFacility,
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF8B1E3F),
                        ),
                      ),
                    ],
                  ),
                  if (_facilities.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _facilities.map((facility) {
                        return Chip(
                          label: Text(facility),
                          onDeleted: () => _removeFacility(facility),
                          deleteIconColor: theme.colorScheme.error,
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const Key('save_venue_button'),
                      onPressed: _isSaving ? null : _saveVenue,
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
                          : Text(widget.isEditing ? 'Save Changes' : 'Create Venue'),
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
