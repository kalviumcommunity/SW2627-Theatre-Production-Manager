import 'package:flutter/material.dart';

import '../models/audition_model.dart';

class AuditionCard extends StatelessWidget {
  final Audition audition;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  const AuditionCard({
    super.key,
    required this.audition,
    this.onTap,
    this.onEdit,
    this.onCancel,
  });

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

  Widget _buildStatusBadge(ThemeData theme) {
    Color bg;
    Color fg;
    IconData icon;

    switch (audition.status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            audition.status,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startTimeStr = _formatTime(audition.startTime);
    final endTimeStr = _formatTime(audition.endTime);
    final dateStr = _formatDate(audition.startTime);
    final durationStr = _formatDuration(audition.duration);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: Icon, Title & Status, Actions popup menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B1E3F).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.how_to_reg_rounded,
                      color: Color(0xFF8B1E3F),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          audition.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildStatusBadge(theme),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                audition.productionId.isNotEmpty
                                    ? 'Prod: ${audition.productionId}'
                                    : 'No Production',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onEdit != null || onCancel != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'edit' && onEdit != null) {
                          onEdit!();
                        } else if (value == 'cancel' && onCancel != null) {
                          onCancel!();
                        }
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Edit Audition'),
                              ],
                            ),
                          ),
                        if (onCancel != null && !audition.isCancelled)
                          const PopupMenuItem(
                            value: 'cancel',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cancel_outlined,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Cancel Audition',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Venue
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      audition.venue,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date & Time Row using responsive Wrap to prevent narrow viewport overflow
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Color(0xFF8B1E3F),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dateStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_outlined,
                          size: 14,
                          color: Color(0xFF8B1E3F),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$startTimeStr - $endTimeStr',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        durationStr,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
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
    );
  }
}
