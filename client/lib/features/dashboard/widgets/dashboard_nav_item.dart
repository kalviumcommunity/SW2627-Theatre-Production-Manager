import 'package:flutter/material.dart';

class DashboardNavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String description;

  const DashboardNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.description,
  });
}

const List<DashboardNavItem> kDashboardNavItems = [
  DashboardNavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    description: 'Overview of theatre productions, rehearsals, and schedules.',
  ),
  DashboardNavItem(
    label: 'Productions',
    icon: Icons.theater_comedy_outlined,
    selectedIcon: Icons.theater_comedy_rounded,
    description: 'Production management, script breakdowns, and scene assignments will be available soon.',
  ),
  DashboardNavItem(
    label: 'Auditions',
    icon: Icons.how_to_reg_outlined,
    selectedIcon: Icons.how_to_reg_rounded,
    description: 'Audition notices, registration, and casting calls are under active development.',
  ),
  DashboardNavItem(
    label: 'Cast',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    description: 'Cast rosters, contact sheets, and character role assignments will be managed here.',
  ),
  DashboardNavItem(
    label: 'Rehearsals',
    icon: Icons.event_repeat_outlined,
    selectedIcon: Icons.event_repeat_rounded,
    description: 'Rehearsal schedules, run notes, and attendance tracking will be available soon.',
  ),
  DashboardNavItem(
    label: 'Venues',
    icon: Icons.location_city_outlined,
    selectedIcon: Icons.location_city_rounded,
    description: 'Stage venues, space capacities, and booking conflict management are coming soon.',
  ),
  DashboardNavItem(
    label: 'Schedule',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    description: 'Master theatre calendar and consolidated production timelines will appear here.',
  ),
  DashboardNavItem(
    label: 'Notifications',
    icon: Icons.notifications_none_outlined,
    selectedIcon: Icons.notifications_rounded,
    description: 'Automated rehearsal alerts and schedule announcements are being implemented.',
  ),
];
