import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/page_title.dart';
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
        child: Column(
          children: [
            const PageTitle('Usuarios'),
            if (state.loading || state.saving) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: notifier.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: !allowed
                      ? [const Text('Solo Admin puede administrar usuarios.')]
                      : [
                          Text('${state.users.length} cuentas'),
                          if (state.error != null) ...[
                            Text(
                              state.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            TextButton(
                              key: const ValueKey('users-retry'),
                              onPressed: state.loading || state.saving
                                  ? null
                                  : notifier.load,
                              child: const Text('Reintentar'),
                            ),
                          ],
                          if (state.warning != null) ...[
                            Text(
                              state.warning!,
                              key: const ValueKey('users-warning'),
                            ),
                            TextButton(
                              key: const ValueKey('users-verify'),
                              onPressed: state.loading || state.saving
                                  ? null
                                  : notifier.load,
                              child: const Text('Actualizar listado'),
                            ),
                          ],
                          if (state.updatedUserId != null &&
                              state.warning == null)
                            const Text('Rol actualizado.'),
                          if (state.users.isEmpty &&
                              !state.loading &&
                              state.error == null)
                            const Text('No hay usuarios registrados.'),
                          for (final user in state.users)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      UserManagementRules.isSelf(actor!, user)
                                          ? '${user.username} (Tú)'
                                          : user.username,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    if (user.displayName != user.username)
                                      Text(user.displayName),
                                    Text(
                                      user.roles.isEmpty
                                          ? 'Sin rol reconocido'
                                          : user.roles
                                                .map(UserManagementRules.label)
                                                .join(', '),
                                    ),
                                    if (UserManagementRules.isSelf(actor, user))
                                      const Text(
                                        'No puedes cambiar tu propio rol.',
                                      )
                                    else
                                      OutlinedButton.icon(
                                        key: ValueKey('user-edit-${user.id}'),
                                        icon: const Icon(Icons.edit_rounded),
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
                                          state.savingId == user.id
                                              ? 'Aplicando…'
                                              : state.unverifiedIds.contains(
                                                  user.id,
                                                )
                                              ? 'Pendiente de verificar'
                                              : 'Cambiar rol',
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
          ],
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
        title: Text('Rol de ${widget.user.username}'),
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
                      title: Text(UserManagementRules.label(role)),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                key: const ValueKey('user-role-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!allowed) const Text('Solo Admin puede administrar usuarios.'),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('user-role-cancel'),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('user-role-apply'),
            onPressed:
                busy ||
                    !allowed ||
                    !UserManagementRules.roles.contains(_selected) ||
                    _selected == widget.user.primaryRole
                ? null
                : _apply,
            child: Text(busy ? 'Aplicando…' : 'Aplicar'),
          ),
        ],
      ),
    );
  }
}
