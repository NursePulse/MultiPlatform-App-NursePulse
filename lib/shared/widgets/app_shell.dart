import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'brand_mark.dart';
import '../../features/iam/application/auth_notifier.dart';
import '../../features/iam/domain/user.dart';

class _NavItem {
  const _NavItem(this.path, this.label, this.icon, {this.visibleFor});

  final String path;
  final String label;
  final IconData icon;
  final List<String>? visibleFor;

  bool visible(User? user) =>
      visibleFor == null || user?.hasAnyRole(visibleFor!) == true;
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
    visibleFor: [kRoleAdmin, kRoleDoctor],
  ),
  _NavItem(
    '/audit',
    'Auditoría',
    Icons.fact_check_rounded,
    visibleFor: [kRoleAdmin, kRoleDoctor],
  ),
  _NavItem(
    '/users',
    'Usuarios',
    Icons.admin_panel_settings_rounded,
    visibleFor: [kRoleAdmin],
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
    final auth = ref.watch(authNotifierProvider);
    final viewMode = ViewModeX.fromRole(auth.user?.primaryRole ?? '');
    final items = _navItems.where((item) => item.visible(auth.user)).toList();
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
            SizedBox(
              width: 240,
              child: _navigation(items, selectedIndex, onSelect),
            ),
            Expanded(
              child: Column(
                children: [
                  header,
                  Expanded(child: _content()),
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
        child: _navigation(items, selectedIndex, (index) {
          Navigator.of(context).pop();
          onSelect(index);
        }),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: switch (widget.currentPath) {
          final path when path.startsWith('/dashboard') => 0,
          final path when path.startsWith('/patients') => 1,
          final path when path.startsWith('/alerts') => 2,
          _ => 3,
        },
        onDestinationSelected: (index) {
          if (index == 3) {
            _scaffoldKey.currentState?.openDrawer();
          } else {
            context.go(['/dashboard', '/patients', '/alerts'][index]);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_rounded),
            label: 'Pacientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_active_rounded),
            label: 'Alertas',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: 'Más',
          ),
        ],
      ),
      body: Column(
        children: [
          header,
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _content() => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: widget.child,
    ),
  );

  Widget _navigation(
    List<_NavItem> items,
    int selectedIndex,
    ValueChanged<int> onSelect,
  ) => Material(
    color: AppTheme.evergreen,
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 24),
            child: BrandWordmark(light: true),
          ),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(items[i].icon),
                title: Text(items[i].label),
                selected: i == selectedIndex,
                selectedTileColor: AppTheme.primarySurface,
                selectedColor: AppTheme.primaryDark,
                textColor: Colors.white,
                iconColor: const Color(0xFFD6E7E3),
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    ),
  );
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
    final roleBadge = CircleAvatar(
      radius: 16,
      backgroundColor: AppTheme.primarySurface,
      child: Text(
        viewMode.shortBadge,
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.primaryDark,
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
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            roleBadge,
            if (isWide) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  username.isEmpty ? viewMode.label : username,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Material(
      color: AppTheme.evergreen,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              if (onOpenDrawer != null)
                IconButton(
                  tooltip: 'Abrir menú',
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: onOpenDrawer,
                )
              else
                const SizedBox(width: 8),
              Expanded(child: const BrandWordmark(light: true)),
              accountMenu,
            ],
          ),
        ),
      ),
    );
  }
}
