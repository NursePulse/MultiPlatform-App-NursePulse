import '../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'brand_mark.dart';
import 'language_selector.dart';
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

final _navItems = [
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
      isMonitoring:
          widget.currentPath.startsWith('/patients/') &&
          widget.currentPath.endsWith('/monitoring'),
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/patients');
        }
      },
      onSignOut: () => ref.read(authNotifierProvider.notifier).signOut(),
      onOpenDrawer: isWide
          ? null
          : () => _scaffoldKey.currentState?.openDrawer(),
    );

    if (isWide) {
      return Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
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
      resizeToAvoidBottomInset: false,
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
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: context.tr('Inicio'),
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_rounded),
            label: context.tr('Pacientes'),
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_active_rounded),
            label: context.tr('Alertas'),
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: context.tr('Más'),
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
      constraints: BoxConstraints(maxWidth: 1200),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: widget.child,
      ),
    ),
  );

  Widget _navigation(
    List<_NavItem> items,
    int selectedIndex,
    ValueChanged<int> onSelect,
  ) => Material(
    color:
        Theme.of(context).extension<RoleAppearance>()?.header ??
        AppTheme.evergreen,
    child: SafeArea(
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 24),
            child: BrandWordmark(light: true),
          ),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(items[i].icon),
                title: Text(context.tr(items[i].label)),
                selected: i == selectedIndex,
                selectedTileColor: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                selectedColor: Theme.of(context).colorScheme.primary,
                textColor: Colors.white,
                iconColor: Color(0xFFD6E7E3),
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
    required this.isMonitoring,
    required this.onBack,
    required this.onSignOut,
    required this.onOpenDrawer,
  });

  final ViewMode viewMode;
  final String username;
  final bool isWide;
  final bool isMonitoring;
  final VoidCallback onBack;
  final VoidCallback onSignOut;
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final roleBadge = CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        context.tr(viewMode.shortBadge),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.primary,
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
      tooltip: context.tr('Cuenta'),
      offset: Offset(0, 40),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(username, style: Theme.of(context).textTheme.titleSmall),
              Text(
                context.tr(viewMode.label),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: onSignOut,
          child: Text(context.tr('Cerrar sesión')),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            roleBadge,
            if (isWide) ...[
              SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 200),
                child: Text(
                  username.isEmpty ? context.tr(viewMode.label) : username,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Material(
      color:
          Theme.of(context).extension<RoleAppearance>()?.header ??
          AppTheme.evergreen,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              if (isMonitoring)
                IconButton(
                  tooltip: context.tr('Volver a pacientes'),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                )
              else if (onOpenDrawer != null)
                IconButton(
                  tooltip: context.tr('Abrir menú'),
                  icon: Icon(Icons.menu, color: Colors.white),
                  onPressed: onOpenDrawer,
                )
              else
                SizedBox(width: 8),
              Expanded(
                child: isMonitoring
                    ? Text(
                        context.tr('Seguimiento'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : const BrandWordmark(light: true),
              ),
              LanguageSelector(light: true),
              accountMenu,
            ],
          ),
        ),
      ),
    );
  }
}
