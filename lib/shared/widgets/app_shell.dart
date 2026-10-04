import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../features/iam/application/auth_notifier.dart';
import '../../features/iam/application/view_mode_notifier.dart';
import '../../features/iam/domain/user.dart';

class _NavItem {
  const _NavItem(this.path, this.label, this.icon, {this.visibleFor});

  final String path;
  final String label;
  final IconData icon;

  /// null means always visible.
  final List<ViewMode>? visibleFor;

  bool visible(ViewMode mode) =>
      visibleFor == null || visibleFor!.contains(mode);
}

const _navItems = [
  _NavItem('/dashboard', 'Dashboard', Icons.grid_view_rounded),
  _NavItem('/patients', 'Pacientes', Icons.groups_rounded),
  _NavItem('/vital-signs', 'Signos vitales', Icons.monitor_heart_rounded),
  _NavItem('/clinical-events', 'Eventos clínicos', Icons.description_rounded),
  _NavItem('/sbar', 'Traspasos SBAR', Icons.swap_horiz_rounded),
  _NavItem('/alerts', 'Alertas', Icons.notifications_active_rounded),
  _NavItem(
    '/reports',
    'Reportes',
    Icons.bar_chart_rounded,
    visibleFor: [ViewMode.headAdminNurse],
  ),
  _NavItem(
    '/audit',
    'Auditoría',
    Icons.fact_check_rounded,
    visibleFor: [ViewMode.headAdminNurse],
  ),
  _NavItem(
    '/users',
    'Usuarios',
    Icons.admin_panel_settings_rounded,
    visibleFor: [ViewMode.headAdminNurse],
  ),
  _NavItem('/subscriptions', 'Suscripciones', Icons.workspace_premium_rounded),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.currentPath});

  final Widget child;
  final String currentPath;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(viewModeProvider);
    final auth = ref.watch(authNotifierProvider);
    final items = _navItems.where((item) => item.visible(viewMode)).toList();
    final selectedIndex = items.indexWhere(
      (item) => widget.currentPath.startsWith(item.path),
    );
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    void onSelect(int index) => context.go(items[index].path);

    final header = _ShellHeader(
      viewMode: viewMode,
      username: auth.user?.username ?? '',
      isWide: isWide,
      onSignOut: () => ref.read(authNotifierProvider.notifier).signOut(),
      onOpenDrawer: isWide
          ? null
          : () => _scaffoldKey.currentState?.openDrawer(),
    );

    if (isWide) {
      return Scaffold(
        key: _scaffoldKey,
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1200,
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: onSelect,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.favorite_rounded, size: 32),
              ),
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  header,
                  const Divider(height: 1),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text(
                  AppConfig.appName,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              for (var i = 0; i < items.length; i++)
                ListTile(
                  leading: Icon(items[i].icon),
                  title: Text(items[i].label),
                  selected: i == selectedIndex,
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelect(i);
                  },
                ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          header,
          const Divider(height: 1),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.viewMode,
    required this.username,
    required this.isWide,
    required this.onSignOut,
    required this.onOpenDrawer,
  });

  final ViewMode viewMode;
  final String username;
  final bool isWide;
  final VoidCallback onSignOut;
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roleBadge = CircleAvatar(
      radius: 10,
      backgroundColor: scheme.primary,
      child: Text(
        viewMode.shortBadge,
        style: TextStyle(
          fontSize: 9,
          color: scheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    // A single account menu showing the real role and sign-out — mirrors
    // header.html's "operator-chip" dropdown. This badge is a read-only
    // display of the authenticated user's actual role: it must never let the
    // user pick a different one, since that would desync the nav from what
    // the backend actually authorizes.
    final accountMenu = PopupMenuButton<void>(
      tooltip: 'Cuenta',
      offset: const Offset(0, 40),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(username, style: Theme.of(context).textTheme.titleSmall),
              Text(
                viewMode.label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: onSignOut,
          child: const Text('Cerrar sesión'),
        ),
      ],
      child: isWide
          ? Chip(
              avatar: roleBadge,
              label: Text(
                username.isEmpty ? viewMode.label : username,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : Padding(padding: const EdgeInsets.all(8), child: roleBadge),
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            if (onOpenDrawer != null)
              IconButton(icon: const Icon(Icons.menu), onPressed: onOpenDrawer)
            else
              const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppConfig.appName,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            accountMenu,
          ],
        ),
      ),
    );
  }
}
