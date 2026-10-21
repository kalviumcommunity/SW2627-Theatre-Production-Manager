import 'package:flutter/material.dart';

import '../../productions/models/production_model.dart';
import '../../productions/services/production_service.dart';
import '../models/audition_model.dart';
import '../services/audition_service.dart';
import 'add_audition_screen.dart';

class AuditionDetailsScreen extends StatefulWidget {
  final Audition audition;
  final AuditionService? auditionService;
  final ProductionService? productionService;

  const AuditionDetailsScreen({
    super.key,
    required this.audition,
    this.auditionService,
    this.productionService,
  });

  @override
  State<AuditionDetailsScreen> createState() => _AuditionDetailsScreenState();
}

class _AuditionDetailsScreenState extends State<AuditionDetailsScreen> {
  late Audition _audition;
  late final AuditionService _service;
  late final ProductionService _productionService;

  Production? _loadedProduction;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _audition = widget.audition;
    _service = widget.auditionService ?? AuditionService();
    _productionService = widget.productionService ?? ProductionService();
    _loadLinkedProduction();
  }

  Future<void> _loadLinkedProduction() async {
    if (_audition.productionId.trim().isEmpty) return;

    try {
      final productions = await _productionService.getProductions().timeout(
        const Duration(seconds: 2),
      );
      if (!mounted) return;
      final match = productions.where(
        (p) => p.id == _audition.productionId.trim(),
      );
      setState(() {
        _loadedProduction = match.isNotEmpty ? match.first : null;
      });
    } catch (_) {}
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

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case AuditionStatus.completed:
        bg = Colors.green.withValues(alpha: 0.12);
        fg = Colors.green.shade800;
        icon = Icons.check_circle_outline;
        break;
      case AuditionStatus.cancelled:
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red.shade800;
        icon = Icons.cancel_outlined;
        break;
      case AuditionStatus.scheduled:
      default:
        bg = const Color(0xFFC8963E).withValues(alpha: 0.15);
        fg = const Color(0xFF9E6E1C);
        icon = Icons.schedule;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToEdit() async {
    final updated = await Navigator.of(context).push<Audition>(
      MaterialPageRoute(
        builder: (context) => AddAuditionScreen(
          initialAudition: _audition,
          auditionService: _service,
          productionService: widget.productionService,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _audition = updated;
      });
      _loadLinkedProduction();
    }
  }

  Future<void> _confirmCancel() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Audition'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel "${_audition.title}"?'),
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
            child: const Text('Keep Audition'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Cancel Audition'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isCancelling = true;
      });

      try {
        final reason = reasonController.text.trim();
        await _service.cancelAudition(
          _audition.id,
          reason: reason.isNotEmpty ? reason : null,
        );

        if (!mounted) return;
        setState(() {
          _audition = _audition.copyWith(
            status: AuditionStatus.cancelled,
            cancellationReason: reason.isNotEmpty ? reason : null,
          );
          _isCancelling = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audition "${_audition.title}" cancelled'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isCancelling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel audition: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startTimeStr = _formatTime(_audition.startTime);
    final endTimeStr = _formatTime(_audition.endTime);
    final dateStr = _formatDate(_audition.startTime);
    final durationStr = _formatDuration(_audition.duration);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Audition Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(_audition),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Audition',
            onPressed: _audition.isCancelled ? null : _navigateToEdit,
          ),
          if (!_audition.isCancelled)
            IconButton(
              icon: _isCancelling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel_outlined, color: Colors.redAccent),
              tooltip: 'Cancel Audition',
              onPressed: _isCancelling ? null : _confirmCancel,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatusBadge(_audition.status),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B1E3F)
                                  .withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.how_to_reg_rounded,
                              color: Color(0xFF8B1E3F),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _audition.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Linked Production Info
                      Row(
                        children: [
                          const Icon(
                            Icons.theater_comedy_outlined,
                            size: 18,
                            color: Color(0xFF8B1E3F),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _loadedProduction != null
                                  ? '${_loadedProduction!.title} (${_loadedProduction!.status})'
                                  : _audition.productionId.isNotEmpty
                                  ? 'Production: ${_audition.productionId}'
                                  : 'No Production Specified',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Cancellation Banner if Cancelled
                if (_audition.isCancelled) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.cancel,
                          color: Colors.red.shade700,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Audition Cancelled',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_audition.cancellationReason != null &&
                                  _audition.cancellationReason!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Reason: ${_audition.cancellationReason}',
                                  style: TextStyle(
                                    color: Colors.red.shade800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Date, Time, Venue Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        theme: theme,
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: dateStr,
                      ),
                      const Divider(height: 20),
                      _buildInfoRow(
                        theme: theme,
                        icon: Icons.access_time_outlined,
                        label: 'Time Window',
                        value: '$startTimeStr - $endTimeStr ($durationStr)',
                      ),
                      const Divider(height: 20),
                      _buildInfoRow(
                        theme: theme,
                        icon: Icons.location_on_outlined,
                        label: 'Venue / Space',
                        value: _audition.venue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Eligibility & Requirements Card
                if (_audition.requirements.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.rule_folder_outlined,
                              color: Color(0xFF8B1E3F),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Eligibility & Requirements',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _audition.requirements,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Description & Notes Card
                if (_audition.description.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              color: Color(0xFF8B1E3F),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Description & Notes',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _audition.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Back Button
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(_audition),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to Auditions List'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
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

  Widget _buildInfoRow({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF8B1E3F)),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
