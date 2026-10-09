import 'dart:async';
import 'package:flutter/material.dart';
import 'package:client/features/auth/screens/login_screen.dart';
import 'package:client/features/dashboard/widgets/coming_soon_view.dart';
import 'package:client/features/dashboard/widgets/dashboard_nav_item.dart';
import 'package:client/features/dashboard/widgets/dashboard_navigation.dart';
import 'package:client/features/dashboard/widgets/metric_card.dart';
import 'package:client/features/dashboard/widgets/role_badge.dart';
import 'package:client/features/dashboard/widgets/upcoming_rehearsals_card.dart';
import 'package:client/services/auth_service.dart';
import 'package:client/services/user_service.dart';

class DashboardScreen extends StatefulWidget {
  final AuthService? authService;
  final UserService? userService;

  const DashboardScreen({
    super.key,
    this.authService,
    this.userService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final AuthService _authService;
  late final UserService _userService;

  int _selectedNavIndex = 0;
  bool _isLoggingOut = false;

  String _userName = '';
  String _userRole = 'Cast Member';
  String _userEmail = '';
  StreamSubscription<Map<String, dynamic>?>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _userService = widget.userService ?? UserService();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  void _loadUserProfile() {
    final user = _authService.currentUser;
    if (user == null) {
      _userName = '';
      _userRole = 'Cast Member';
      _userEmail = '';
      return;
    }

    _userEmail = user.email ?? '';
    // Fallback from auth user displayName or email prefix
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      _userName = user.displayName!.trim();
    } else if (user.email != null && user.email!.contains('@')) {
      final emailPrefix = user.email!.split('@').first;
      _userName = emailPrefix.isNotEmpty
          ? '${emailPrefix[0].toUpperCase()}${emailPrefix.substring(1)}'
          : 'Member';
    } else {
      _userName = 'Member';
    }

    // Stream profile from Firestore
    try {
      _profileSubscription = _userService.streamUserProfile(user.uid).listen(
        (data) {
          if (!mounted || data == null) return;
          setState(() {
            if (data['name'] != null && data['name'].toString().trim().isNotEmpty) {
              _userName = data['name'].toString().trim();
            }
            if (data['role'] != null && data['role'].toString().trim().isNotEmpty) {
              _userRole = data['role'].toString().trim();
            }
            if (data['email'] != null && data['email'].toString().trim().isNotEmpty) {
              _userEmail = data['email'].toString().trim();
            }
          });
        },
        onError: (_) {
          // Fallback values retained on error
        },
      );
    } catch (_) {
      // Retain fallback if Firestore is unavailable
    }
  }

  Future<void> _onLogoutPressed() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoggingOut = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthService.getErrorMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onNavigateTo(int index) {
    setState(() {
      _selectedNavIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWideScreen = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: isWideScreen ? null : _buildMobileAppBar(theme),
      drawer: isWideScreen
          ? null
          : DashboardDrawer(
              selectedIndex: _selectedNavIndex,
              onDestinationSelected: _onNavigateTo,
              userName: _userName,
              userRole: _userRole,
              userEmail: _userEmail,
              onLogout: _onLogoutPressed,
              isLoggingOut: _isLoggingOut,
            ),
      body: Row(
        children: [
          if (isWideScreen)
            DashboardSidebar(
              selectedIndex: _selectedNavIndex,
              onDestinationSelected: _onNavigateTo,
              userName: _userName,
              userRole: _userRole,
              userEmail: _userEmail,
              onLogout: _onLogoutPressed,
              isLoggingOut: _isLoggingOut,
            ),
          Expanded(
            child: Column(
              children: [
                if (isWideScreen) _buildDesktopTopBar(theme),
                Expanded(
                  child: _selectedNavIndex == 0
                      ? _buildDashboardView(theme)
                      : ComingSoonView(
                          title: '${kDashboardNavItems[_selectedNavIndex].label} Module',
                          description: kDashboardNavItems[_selectedNavIndex].description,
                          icon: kDashboardNavItems[_selectedNavIndex].selectedIcon,
                          onBackToDashboard: () => _onNavigateTo(0),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(ThemeData theme) {
    return AppBar(
      title: const Text(
        'Theatre Production Manager',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 6.0),
          child: RoleBadge(role: _userRole, isCompact: true),
        ),
        FilledButton.icon(
          onPressed: _isLoggingOut ? null : _onLogoutPressed,
          icon: _isLoggingOut
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.logout, size: 16),
          label: Text(_isLoggingOut ? 'Logging out...' : 'Logout'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8B1E3F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDesktopTopBar(ThemeData theme) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App Title / Screen breadcrumb
          Row(
            children: [
              Text(
                'Theatre Production Manager',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
              const SizedBox(width: 8),
              Text(
                kDashboardNavItems[_selectedNavIndex].label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF8B1E3F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // User Profile & Logout Action
          Row(
            children: [
              RoleBadge(role: _userRole),
              const SizedBox(width: 16),
              PopupMenuButton<String>(
                tooltip: 'Account Menu',
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF8B1E3F),
                        foregroundColor: Colors.white,
                        child: Text(
                          _userName.isNotEmpty
                              ? _userName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                              : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _userName.isEmpty ? 'Account' : _userName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName.isEmpty ? 'Theatre Member' : _userName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_userEmail.isNotEmpty)
                          Text(
                            _userEmail,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: const Row(
                      children: [
                        Icon(Icons.logout, size: 18),
                        SizedBox(width: 10),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'logout') {
                    _onLogoutPressed();
                  }
                },
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _isLoggingOut ? null : _onLogoutPressed,
                icon: _isLoggingOut
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.logout, size: 16),
                label: Text(_isLoggingOut ? 'Logging out...' : 'Logout'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1E3F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Welcome Banner
          _buildWelcomeBanner(theme),
          const SizedBox(height: 24),

          // Overview Summary Cards Grid
          _buildOverviewCards(theme),
          const SizedBox(height: 24),

          // Upcoming Rehearsals and Theatre Hub
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: UpcomingRehearsalsCard(
                        firestore: _userService.firestore,
                        onViewAllPressed: () => _onNavigateTo(4), // Rehearsals tab
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 4,
                      child: _buildTheatreHubCard(theme),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    UpcomingRehearsalsCard(
                      firestore: _userService.firestore,
                      onViewAllPressed: () => _onNavigateTo(4),
                    ),
                    const SizedBox(height: 24),
                    _buildTheatreHubCard(theme),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(ThemeData theme) {
    final hasName = _userName.trim().isNotEmpty;
    final welcomeTitle = hasName ? 'Welcome, $_userName!' : 'Welcome!';
    final welcomeSubtitle = hasName
        ? 'You are logged in as $_userRole. Here is the latest overview of your productions and stage commitments.'
        : 'You are logged in.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B1E3F),
            const Color(0xFF5A1027),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B1E3F).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.theater_comedy, color: Color(0xFFF3C64F), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _userRole,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  welcomeTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  welcomeSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Dramatic stage mask emblem
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.theater_comedy,
              size: 56,
              color: Color(0xFFF3C64F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        int crossAxisCount = 4;
        if (cardWidth < 550) {
          crossAxisCount = 1;
        } else if (cardWidth < 900) {
          crossAxisCount = 2;
        }

        final cards = [
          MetricCard(
            title: 'Total Productions',
            value: '—',
            subtitle: 'No active productions',
            icon: Icons.theater_comedy,
            accentColor: const Color(0xFF8B1E3F),
            onTap: () => _onNavigateTo(1),
          ),
          MetricCard(
            title: 'Upcoming Rehearsals',
            value: '—',
            subtitle: 'None scheduled this week',
            icon: Icons.event_repeat_rounded,
            accentColor: const Color(0xFFC8963E),
            onTap: () => _onNavigateTo(4),
          ),
          MetricCard(
            title: 'Auditions',
            value: '—',
            subtitle: 'No open auditions',
            icon: Icons.how_to_reg_rounded,
            accentColor: const Color(0xFF6B21A8),
            onTap: () => _onNavigateTo(2),
          ),
          MetricCard(
            title: 'Venues',
            value: '—',
            subtitle: 'No booked venues',
            icon: Icons.location_city_rounded,
            accentColor: const Color(0xFF00695C),
            onTap: () => _onNavigateTo(5),
          ),
        ];

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.7,
          children: cards,
        );
      },
    );
  }

  Widget _buildTheatreHubCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC8963E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Color(0xFFB37D2B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Navigation',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Direct access to key modules',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildQuickActionTile(
            theme: theme,
            icon: Icons.calendar_month_outlined,
            title: 'Master Schedule',
            subtitle: 'View upcoming dates & conflict checks',
            onTap: () => _onNavigateTo(6), // Schedule
          ),
          const SizedBox(height: 12),
          _buildQuickActionTile(
            theme: theme,
            icon: Icons.groups_outlined,
            title: 'Cast Roster',
            subtitle: 'Actors, character roles & contact info',
            onTap: () => _onNavigateTo(3), // Cast
          ),
          const SizedBox(height: 12),
          _buildQuickActionTile(
            theme: theme,
            icon: Icons.notifications_none_outlined,
            title: 'Notifications & Alerts',
            subtitle: 'Call time changes & announcements',
            onTap: () => _onNavigateTo(7), // Notifications
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B1E3F).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF8B1E3F).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFF8B1E3F),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: Rehearsal and audition schedules will sync across all cast & crew members in real time.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8B1E3F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF8B1E3F)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
