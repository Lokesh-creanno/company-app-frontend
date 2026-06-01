import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import 'creanno_logo.dart';
import 'aurora_background.dart';

// ─── Tab definition ───────────────────────────────────────────────────────────
class _Tab {
  final IconData icon, activeIcon;
  final String label, path;
  const _Tab({required this.icon, required this.activeIcon, required this.label, required this.path});
}

const _tabs = [
  _Tab(icon: Icons.dashboard_outlined,    activeIcon: Icons.dashboard_rounded,   label: 'Home',       path: '/dashboard'),
  _Tab(icon: Icons.access_time_outlined,  activeIcon: Icons.access_time_filled,  label: 'Attendance', path: '/attendance'),
  _Tab(icon: Icons.task_outlined,         activeIcon: Icons.task_alt_rounded,    label: 'Tasks',      path: '/tasks'),
  _Tab(icon: Icons.receipt_outlined,      activeIcon: Icons.receipt_rounded,     label: 'Claims',     path: '/reimbursements'),
  _Tab(icon: Icons.folder_outlined,       activeIcon: Icons.folder_rounded,      label: 'Docs',       path: '/documents'),
];

// ─── Main Shell ───────────────────────────────────────────────────────────────
class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user  = ref.watch(authStateProvider).value;
    final index = _currentIndex(context);

    return LayoutBuilder(builder: (ctx, constraints) {
      final isWide = constraints.maxWidth >= 720;
      return isWide
          ? _DesktopShell(index: index, user: user, child: child)
          : _MobileShell(index: index, user: user, child: child);
    });
  }
}

// ─── Theme Toggle Button ──────────────────────────────────────────────────────
class _ThemeToggleButton extends ConsumerWidget {
  final bool compact;
  const _ThemeToggleButton({this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode  = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: 'Theme: ${mode.label} — tap to cycle',
      child: GestureDetector(
        onTap: () => ref.read(themeModeProvider.notifier).cycle(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.all(compact ? 6 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 10 : 12),
            gradient: isDark
                ? LinearGradient(
                    colors: [
                      AppColors.auroraViolet.withOpacity(0.3),
                      AppColors.auroraCyan.withOpacity(0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      AppColors.auroraViolet.withOpacity(0.12),
                      AppColors.auroraCyan.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.15)
                  : AppColors.lightBorder.withOpacity(0.8),
              width: 1,
            ),
          ),
          child: Icon(
            mode.icon,
            size: compact ? 16 : 18,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

// ─── Mobile Shell (bottom navigation) ────────────────────────────────────────
class _MobileShell extends ConsumerWidget {
  final int index;
  final dynamic user;
  final Widget child;
  const _MobileShell({required this.index, required this.user, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Aurora animated background ──────────────────────────────────────
          const Positioned.fill(child: AuroraBackground(intensity: 0.85)),
          // ── Page content ────────────────────────────────────────────────────
          child,
        ],
      ),
      drawer: _SideDrawer(user: user),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.65),
                        Colors.black.withOpacity(0.50),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.80),
                        Colors.white.withOpacity(0.65),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.10)
                      : AppColors.lightBorder.withOpacity(0.6),
                  width: 1,
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(_tabs[i].path),
              backgroundColor: Colors.transparent,
              elevation: 0,
              destinations: _tabs.map((tab) => NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.activeIcon),
                label: tab.label,
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Desktop Shell (side navigation rail) ────────────────────────────────────
class _DesktopShell extends ConsumerWidget {
  final int index;
  final dynamic user;
  final Widget child;
  const _DesktopShell({required this.index, required this.user, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExtended = MediaQuery.of(context).size.width >= 1100;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Aurora background (full screen) ─────────────────────────────────
          const Positioned.fill(child: AuroraBackground(intensity: 0.8)),

          // ── Main layout row ──────────────────────────────────────────────────
          Row(
            children: [
              // ── Glass Side Nav ────────────────────────────────────────────
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.55),
                                Colors.black.withOpacity(0.35),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.80),
                                Colors.white.withOpacity(0.55),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      border: Border(
                        right: BorderSide(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : AppColors.lightBorder.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          // Brand logo area
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: isExtended ? 20 : 12, vertical: 20),
                            child: isExtended
                                ? Row(children: [
                                    const CreannoLogo(size: 38),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ShaderMask(
                                              shaderCallback: (b) =>
                                                  AppGradients.aurora.createShader(b),
                                              child: const Text('CREANNO',
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.white,
                                                      letterSpacing: 1.2)),
                                            ),
                                            Text('Workspace',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.textSecondaryOf(context),
                                                    fontWeight: FontWeight.w500)),
                                          ]),
                                    ),
                                    // Theme toggle in extended rail
                                    const _ThemeToggleButton(compact: true),
                                  ])
                                : Column(children: [
                                    const Center(child: CreannoLogo(size: 38)),
                                    const SizedBox(height: 8),
                                    const _ThemeToggleButton(compact: true),
                                  ]),
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Divider(
                              height: 1,
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : AppColors.lightBorder.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Nav destinations
                          Expanded(
                            child: _AdminAwareRail(
                              index: index,
                              user: user,
                              isExtended: isExtended,
                            ),
                          ),

                          // Bottom: user profile + logout
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Divider(
                              height: 1,
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : AppColors.lightBorder.withOpacity(0.5),
                            ),
                          ),
                          _SideNavUserTile(user: user, extended: isExtended),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Main content area ──────────────────────────────────────────
              Expanded(child: child),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Admin-Aware Navigation Rail ─────────────────────────────────────────────
class _AdminAwareRail extends ConsumerWidget {
  final int index;
  final dynamic user;
  final bool isExtended;
  const _AdminAwareRail({required this.index, required this.user, required this.isExtended});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final isOnAdmin = loc.startsWith('/admin');
    final isManager = user?.isManager == true;

    final destinations = <NavigationRailDestination>[
      ..._tabs.map((tab) => NavigationRailDestination(
        icon: Icon(tab.icon),
        selectedIcon: Icon(tab.activeIcon),
        label: Text(tab.label),
        padding: const EdgeInsets.symmetric(vertical: 4),
      )),
      if (isManager)
        const NavigationRailDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings_rounded),
          label: Text('Admin'),
          padding: EdgeInsets.symmetric(vertical: 4),
        ),
    ];

    final effectiveIndex = isOnAdmin && isManager ? _tabs.length : index;

    return NavigationRail(
      extended: isExtended,
      selectedIndex: effectiveIndex.clamp(0, destinations.length - 1),
      onDestinationSelected: (i) {
        if (isManager && i == _tabs.length) {
          context.go('/admin');
        } else {
          context.go(_tabs[i].path);
        }
      },
      backgroundColor: Colors.transparent,
      leading: const SizedBox.shrink(),
      groupAlignment: -0.9,
      destinations: destinations,
    );
  }
}

// ─── Side Nav User Tile ───────────────────────────────────────────────────────
class _SideNavUserTile extends ConsumerWidget {
  final dynamic user;
  final bool extended;
  const _SideNavUserTile({this.user, required this.extended});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = user?.firstName?.isNotEmpty == true
        ? user!.firstName[0].toUpperCase()
        : '?';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.all(extended ? 16 : 8),
      child: extended
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? LinearGradient(colors: [
                            Colors.white.withOpacity(0.08),
                            Colors.white.withOpacity(0.04),
                          ])
                        : LinearGradient(colors: [
                            Colors.white.withOpacity(0.75),
                            Colors.white.withOpacity(0.50),
                          ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.10)
                          : AppColors.lightBorder.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(children: [
                    _Avatar(initial: initial, photoUrl: user?.profilePhoto),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(user?.firstName ?? '',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimaryOf(context)),
                              overflow: TextOverflow.ellipsis),
                          Text(
                              user?.role?.toString().toUpperCase() ?? '',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondaryOf(context),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4)),
                        ])),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded,
                          size: 18, color: AppColors.error),
                      tooltip: 'Logout',
                      onPressed: () {
                        ref.read(authStateProvider.notifier).logout();
                        context.go('/login');
                      },
                    ),
                  ]),
                ),
              ),
            )
          : Column(children: [
              _Avatar(
                  initial: initial,
                  photoUrl: user?.profilePhoto,
                  size: 36),
              const SizedBox(height: 6),
              IconButton(
                icon: const Icon(Icons.logout_rounded,
                    size: 16, color: AppColors.error),
                tooltip: 'Logout',
                onPressed: () {
                  ref.read(authStateProvider.notifier).logout();
                  context.go('/login');
                },
              ),
            ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initial;
  final String? photoUrl;
  final double size;
  const _Avatar({required this.initial, this.photoUrl, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        shape: BoxShape.circle,
        boxShadow: AppGlass.violetGlow(intensity: 0.25),
      ),
      child: photoUrl != null
          ? ClipOval(child: Image.network(photoUrl!, fit: BoxFit.cover))
          : Center(
              child: Text(initial,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.38,
                      fontWeight: FontWeight.w800))),
    );
  }
}

// ─── Side Drawer (mobile) ─────────────────────────────────────────────────────
class _SideDrawer extends ConsumerWidget {
  final dynamic user;
  const _SideDrawer({this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = user?.firstName?.isNotEmpty == true
        ? user!.firstName[0].toUpperCase()
        : '?';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24))),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(
                      colors: [
                        AppColors.darkSurface.withOpacity(0.92),
                        AppColors.darkBg.withOpacity(0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.92),
                        AppColors.lightSurfaceVar.withOpacity(0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : AppColors.lightBorder.withOpacity(0.4),
                  width: 1,
                ),
              ),
            ),
            child: Column(children: [
              // Header with aurora gradient
              Container(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                decoration: const BoxDecoration(gradient: AppGradients.hero),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // CREANNO logo + brand + theme toggle
                      Row(children: [
                        const CreannoLogoLight(size: 36),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('CREANNO',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5)),
                        ),
                        const _ThemeToggleButton(compact: true),
                      ]),
                      const SizedBox(height: 16),
                      // User info row
                      Row(children: [
                        _Avatar(
                            initial: initial,
                            photoUrl: user?.profilePhoto,
                            size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(user?.fullName ?? '',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(user?.email ?? '',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 11),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1),
                                ),
                                child: Text(
                                    user?.role?.toString().toUpperCase() ?? '',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5)),
                              ),
                            ])),
                      ]),
                    ]),
              ),

              const SizedBox(height: 8),

              // Navigation items
              ..._tabs.map((tab) {
                final loc = GoRouterState.of(context).matchedLocation;
                final active = loc.startsWith(tab.path);
                return _DrawerNavItem(
                    tab: tab,
                    active: active,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(tab.path);
                    });
              }),

              if (user?.isManager == true) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    height: 24,
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : AppColors.lightBorder.withOpacity(0.5),
                  ),
                ),
                _DrawerNavItem(
                  tab: const _Tab(
                      icon: Icons.people_outline,
                      activeIcon: Icons.people_rounded,
                      label: 'Team',
                      path: '/employees'),
                  active: GoRouterState.of(context)
                      .matchedLocation
                      .startsWith('/employees'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/employees');
                  },
                ),
                _DrawerNavItem(
                  tab: const _Tab(
                      icon: Icons.admin_panel_settings_outlined,
                      activeIcon: Icons.admin_panel_settings_rounded,
                      label: 'Admin Panel',
                      path: '/admin'),
                  active: GoRouterState.of(context)
                      .matchedLocation
                      .startsWith('/admin'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/admin');
                  },
                ),
              ],

              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : AppColors.lightBorder.withOpacity(0.4),
                ),
              ),
              ListTile(
                leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.logout_rounded,
                        color: AppColors.error, size: 18)),
                title: const Text('Logout',
                    style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                onTap: () {
                  ref.read(authStateProvider.notifier).logout();
                  Navigator.pop(context);
                  context.go('/login');
                },
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DrawerNavItem extends StatelessWidget {
  final _Tab tab;
  final bool active;
  final VoidCallback onTap;
  const _DrawerNavItem(
      {required this.tab, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: active
            ? AppColors.primary.withOpacity(isDark ? 0.18 : 0.10)
            : Colors.transparent,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: active ? AppGradients.primary : null,
            color: active
                ? null
                : (isDark
                    ? Colors.white.withOpacity(0.06)
                    : AppColors.lightSurfaceVar),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(active ? tab.activeIcon : tab.icon,
              color: active ? Colors.white : AppColors.textSecondaryOf(context),
              size: 18),
        ),
        title: Text(tab.label,
            style: TextStyle(
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? AppColors.primary
                    : AppColors.textPrimaryOf(context),
                fontSize: 14)),
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        dense: true,
      ),
    );
  }
}
