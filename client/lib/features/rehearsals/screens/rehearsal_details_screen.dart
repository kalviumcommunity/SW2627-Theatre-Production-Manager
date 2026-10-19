import 'package:flutter/material.dart';
import '../models/rehearsal_model.dart';
import '../services/rehearsal_service.dart';
import '../../productions/services/production_service.dart';
import 'add_rehearsal_screen.dart';

class RehearsalDetailsScreen extends StatefulWidget {
  final Rehearsal rehearsal;
  final RehearsalService? rehearsalService;
  final ProductionService? productionService;

  const RehearsalDetailsScreen({
    super.key,
    required this.rehearsal,
    this.rehearsalService,
    this.productionService,
  });

  @override
  State<RehearsalDetailsScreen> createState() => _RehearsalDetailsScreenState();
}

class _RehearsalDetailsScreenState extends State<RehearsalDetailsScreen> {
  late Rehearsal _rehearsal;
  late final RehearsalService _service;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _rehearsal = widget.rehearsal;
    _service = widget.rehearsalService ?? RehearsalService();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthName = months[dt.month - 1];
    return '${dt.day} $monthName ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rehearsal'),
        content: Text(
          'Are you sure you want to delete "${_rehearsal.title}"? This will free the venue slot for other rehearsals.',
        ),
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

    if (confirmed == true && mounted) {
      setState(() {
        _isDeleting = true;
      });
      try {
        await _service.deleteRehearsal(_rehearsal.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${_rehearsal.title}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isDeleting = false;
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete rehearsal: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _navigateToEdit() async {
    final updated = await Navigator.of(context).push<Rehearsal>(
      MaterialPageRoute(
        builder: (context) => AddRehearsalScreen(
          initialRehearsal: _rehearsal,
          rehearsalService: _service,
          productionService: widget.productionService,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _rehearsal = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = _formatDate(_rehearsal.startTime);
    final startTimeStr = _formatTime(_rehearsal.startTime);
    final endTimeStr = _formatTime(_rehearsal.endTime);
    final durationStr = _formatDuration(_rehearsal.duration);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rehearsal Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Rehearsal',
            onPressed: _isDeleting ? null : _navigateToEdit,
          ),
          IconButton(
            icon: _isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete Rehearsal',
            onPressed: _isDeleting ? null : _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B1E3F).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.event_repeat_rounded,
                              color: Color(0xFF8B1E3F),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _rehearsal.title,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC8963E).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: Color(0xFFB37D2B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _rehearsal.venue.isNotEmpty
                                            ? _rehearsal.venue
                                            : 'Unassigned Venue',
                                        style: const TextStyle(
                                          color: Color(0xFF915F17),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Timing & Schedule Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Call Time & Schedule',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              theme: theme,
                              icon: Icons.calendar_today_outlined,
                              label: 'Date',
                              value: dateStr,
                            ),
                          ),
                          Expanded(
                            child: _buildInfoItem(
                              theme: theme,
                              icon: Icons.access_time_rounded,
                              label: 'Time Window',
                              value: '$startTimeStr – $endTimeStr',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              theme: theme,
                              icon: Icons.timelapse_rounded,
                              label: 'Duration',
                              value: durationStr,
                            ),
                          ),
                          Expanded(
                            child: _buildInfoItem(
                              theme: theme,
                              icon: Icons.theater_comedy_outlined,
                              label: 'Production ID',
                              value: _rehearsal.productionId.isNotEmpty
                                  ? _rehearsal.productionId
                                  : 'Not specified',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Notes Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rehearsal Notes & Scene Run',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _rehearsal.notes.isNotEmpty
                            ? _rehearsal.notes
                            : 'No notes provided for this rehearsal session.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _rehearsal.notes.isNotEmpty
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Back Navigation Button
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to Rehearsals List'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    );
  }

  Widget _buildInfoItem({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
