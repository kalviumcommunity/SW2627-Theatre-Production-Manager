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
    description: 'Create, edit, and manage theatre productions and timelines.',
  ),
  DashboardNavItem(
    label: 'Auditions',
    icon: Icons.how_to_reg_outlined,
    selectedIcon: Icons.how_to_reg_rounded,
    description: 'Schedule and manage audition calls, notices, and casting sessions.',
  ),
  DashboardNavItem(
    label: 'Cast',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    description: 'Manage cast rosters, character roles, and actor assignments.',
  ),
  DashboardNavItem(
    label: 'Rehearsals',
    icon: Icons.event_repeat_outlined,
    selectedIcon: Icons.event_repeat_rounded,
    description: 'Organize rehearsal sessions, schedules, venues, and run notes.',
  ),
  DashboardNavItem(
    label: 'Venues',
    icon: Icons.location_city_outlined,
    selectedIcon: Icons.location_city_rounded,
    description: 'Manage stage venues, capacities, and booking conflict detection.',
  ),
  DashboardNavItem(
    label: 'Schedule',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    description: 'Consolidated master schedule across all theatre productions and events.',
  ),
  DashboardNavItem(
    label: 'Notifications',
    icon: Icons.notifications_none_outlined,
    selectedIcon: Icons.notifications_rounded,
    description: 'Real-time schedule changes, announcements, and call time alerts.',
  ),
];
