import 'package:flutter/material.dart';

class RoleBadge extends StatelessWidget {
  final String role;
  final bool isCompact;

  const RoleBadge({
    super.key,
    required this.role,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = role.trim().toLowerCase();

    Color bgColor;
    Color textColor;
    Color borderColor;
    IconData icon;

    if (normalized.contains('director')) {
      bgColor = const Color(0xFFFBEAEB);
      textColor = const Color(0xFF8B1E3F);
      borderColor = const Color(0xFFE8B2BC);
      icon = Icons.theater_comedy_rounded;
    } else if (normalized.contains('cast')) {
      bgColor = const Color(0xFFF3E8FF);
      textColor = const Color(0xFF6B21A8);
      borderColor = const Color(0xFFD8B4FE);
      icon = Icons.star_rounded;
    } else if (normalized.contains('coordinator')) {
      bgColor = const Color(0xFFE6F4EA);
      textColor = const Color(0xFF137333);
      borderColor = const Color(0xFFA8DAB5);
      icon = Icons.event_note_rounded;
    } else {
      bgColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurfaceVariant;
      borderColor = theme.colorScheme.outlineVariant;
      icon = Icons.badge_outlined;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isCompact ? 14 : 16,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            role.isEmpty ? 'Member' : role,
            style: TextStyle(
              color: textColor,
              fontSize: isCompact ? 12 : 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
