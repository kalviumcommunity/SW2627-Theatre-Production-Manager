import 'package:flutter/material.dart';
import '../models/schedule_event_model.dart';

class ScheduleEventCard extends StatelessWidget {
  final ScheduleEvent event;
  final VoidCallback onTap;

  const ScheduleEventCard({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRehearsal = event.isRehearsal;
    final typeColor = isRehearsal
        ? const Color(0xFF8B1E3F) // Crimson for rehearsals
        : const Color(0xFF6B21A8); // Purple for auditions

    final isCancelled = event.status.toLowerCase() == 'cancelled';
    final isCompleted = event.status.toLowerCase() == 'completed';

    Color statusBg = Colors.grey.withValues(alpha: 0.1);
    Color statusFg = Colors.grey.shade700;
    if (isCancelled) {
      statusBg = theme.colorScheme.errorContainer;
      statusFg = theme.colorScheme.error;
    } else if (isCompleted) {
      statusBg = Colors.green.withValues(alpha: 0.12);
      statusFg = Colors.green.shade800;
    } else {
      statusBg = const Color(0xFFC8963E).withValues(alpha: 0.15);
      statusFg = const Color(0xFF9E6E1C);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Type badge + Status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isRehearsal ? Icons.event_repeat : Icons.how_to_reg,
                          size: 14,
                          color: typeColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          event.typeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      event.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusFg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                event.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Production
              Row(
                children: [
                  Icon(
                    Icons.theater_comedy_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.productionTitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Time & Venue
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 15,
                    color: const Color(0xFF8B1E3F),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    event.formattedTimeRange,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8B1E3F),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.venue,
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
      ),
    );
  }
}
