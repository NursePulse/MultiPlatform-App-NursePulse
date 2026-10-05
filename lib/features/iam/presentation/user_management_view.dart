import '../../../shared/widgets/list_page_body.dart';
import '../../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/page_title.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/status_chip.dart';
import '../application/users_notifier.dart';
import '../domain/user.dart';
import '../domain/user_management_rules.dart';

class UserManagementView extends ConsumerWidget {
  const UserManagementView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usersNotifierProvider);
    final actor = ref.watch(userManagementActorProvider);
    final allowed = UserManagementRules.canManage(actor);
    final notifier = ref.read(usersNotifierProvider.notifier);
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListPageBody(
          header: [
            PageTitle('Usuarios'),
            if (state.loading || state.saving) LinearProgressIndicator(),
          ],
          child: RefreshIndicator(
            onRefresh: notifier.load,
            child: ListView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              children: !allowed
                  ? [Text(context.tr('Solo Admin puede administrar usuarios.'))]
                  : [
                      Text(context.tr('${state.users.length} cuentas')),
                      if (state.error != null) ...[
                        Text(
                          context.tr(state.error!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          key: ValueKey('users-retry'),
                          onPressed: state.loading || state.saving
                              ? null
                              : notifier.load,
                          child: Text(context.tr('Reintentar')),
                        ),
                      ],
                      if (state.warning != null) ...[
                        Text(
                          context.tr(state.warning!),
                          key: ValueKey('users-warning'),
                        ),
                        TextButton(
                          key: ValueKey('users-verify'),
                          onPressed: state.loading || state.saving
                              ? null
                              : notifier.load,
                          child: Text(context.tr('Actualizar listado')),
                        ),
                      ],
                      if (state.updatedUserId != null && state.warning == null)
                        Text(context.tr('Rol actualizado.')),
                      if (state.users.isEmpty &&
                          !state.loading &&
                          state.error == null)
                        Text(context.tr('No hay usuarios registrados.')),
                      for (final user in state.users)
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: RoleAppearance.forRole(
                                        ViewModeX.fromRole(user.primaryRole),
                                      ).soft,
                                      foregroundColor: RoleAppearance.forRole(
                                        ViewModeX.fromRole(user.primaryRole),
                                      ).accent,
                                      child: Icon(Icons.person_outline),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        context.tr(
                                          UserManagementRules.isSelf(
                                                actor!,
                                                user,
                                              )
                                              ? '${user.username} (Tú)'
                                              : user.username,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                if (user.displayName != user.username)
                                  Text(user.displayName),
                                SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (user.roles.isEmpty)
                                      Text(context.tr('Sin rol reconocido')),
                                    for (final role in user.roles)
                                      StatusChip(
                                        label: UserManagementRules.label(role),
                                        palette: ChipPalette(
                                          RoleAppearance.forRole(
                                            ViewModeX.fromRole(role),
                                          ).soft,
                                          RoleAppearance.forRole(
                                            ViewModeX.fromRole(role),
                                          ).accent,
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                if (UserManagementRules.isSelf(actor, user))
                                  Text(
                                    context.tr(
                                      'No puedes cambiar tu propio rol.',
                                    ),
                                  )
                                else
                                  OutlinedButton.icon(
                                    key: ValueKey('user-edit-${user.id}'),
                                    icon: Icon(Icons.edit_rounded),
                                    onPressed:
                                        state.loading ||
                                            state.saving ||
                                            state.unverifiedIds.contains(
                                              user.id,
                                            )
                                        ? null
                                        : () => showDialog<bool>(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (_) =>
                                                _RoleDialog(user: user),
                                          ),
                                    label: Text(
                                      context.tr(
                                        state.savingId == user.id
                                            ? 'Aplicando…'
                                            : state.unverifiedIds.contains(
                                                user.id,
                                              )
                                            ? 'Pendiente de verificar'
                                            : 'Cambiar rol',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleDialog extends ConsumerStatefulWidget {
  const _RoleDialog({required this.user});
  final User user;
  @override
  ConsumerState<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends ConsumerState<_RoleDialog> {
  late String _selected = widget.user.primaryRole;
  String? _error;
  bool _submitting = false;

  Future<void> _apply() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(usersNotifierProvider.notifier).updateRoles(
        widget.user.id,
        [_selected],
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = describeUserManagementError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersNotifierProvider);
    final allowed = UserManagementRules.canManage(
      ref.watch(userManagementActorProvider),
    );
    final busy = _submitting || state.saving;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(context.tr('Rol de ${widget.user.username}')),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (value) {
                if (busy || !allowed) return;
                if (value != null) setState(() => _selected = value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final role in UserManagementRules.roles)
                    RadioListTile<String>(
                      key: ValueKey('user-role-$role'),
                      value: role,
                      enabled: !busy && allowed,
                      title: Text(context.tr(UserManagementRules.label(role))),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Text(
                context.tr(_error!),
                key: ValueKey('user-role-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!allowed)
              Text(context.tr('Solo Admin puede administrar usuarios.')),
          ],
        ),
        actions: [
          TextButton(
            key: ValueKey('user-role-cancel'),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(context.tr('Cancelar')),
          ),
          FilledButton(
            key: ValueKey('user-role-apply'),
            onPressed:
                busy ||
                    !allowed ||
                    !UserManagementRules.roles.contains(_selected) ||
                    _selected == widget.user.primaryRole
                ? null
                : _apply,
            child: Text(context.tr(busy ? 'Aplicando…' : 'Aplicar')),
          ),
        ],
      ),
    );
  }
}
