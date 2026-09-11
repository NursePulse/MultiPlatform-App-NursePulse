import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/page_title.dart';
import '../application/auth_notifier.dart';
import '../application/users_notifier.dart';
import '../domain/user.dart';

const _allRoles = [kRoleNurse, kRoleHeadAdminNurse];

String _roleLabel(String role) => switch (role) {
  kRoleHeadAdminNurse => 'Jefe de Enfermería',
  _ => 'Enfermera/o',
};

class UserManagementView extends ConsumerStatefulWidget {
  const UserManagementView({super.key});

  @override
  ConsumerState<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends ConsumerState<UserManagementView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(usersNotifierProvider.notifier).load());
  }

  Future<void> _editRoles(User user) async {
    var selected = user.primaryRole;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Rol de ${user.username}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final role in _allRoles)
                RadioListTile<String>(
                  value: role,
                  groupValue: selected,
                  title: Text(_roleLabel(role)),
                  onChanged: (value) => setState(() => selected = value!),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await ref
          .read(usersNotifierProvider.notifier)
          .updateRoles(user.id, [result]);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rol actualizado.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeDioError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersNotifierProvider);
    return Scaffold(
      body: Column(
        children: [
          const PageTitle('Usuarios'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(usersNotifierProvider.notifier).load(),
              child: AsyncValueView<UsersState>(
                loading: state.loading,
                error: state.error,
                data: state,
                isEmpty: (s) => s.users.isEmpty,
                onRetry: () => ref.read(usersNotifierProvider.notifier).load(),
                builder: (context, s) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: s.users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = s.users[index];
                    final isSelf =
                        user.id == ref.read(authNotifierProvider).user?.id;
                    return Card(
                      child: ListTile(
                        title: Text(
                          isSelf ? '${user.username} (Tú)' : user.username,
                        ),
                        subtitle: Text(user.roles.map(_roleLabel).join(', ')),
                        trailing: isSelf
                            ? const Tooltip(
                                message: 'No puedes cambiar tu propio rol',
                                child: Icon(Icons.lock_outline_rounded),
                              )
                            : IconButton(
                                icon: const Icon(Icons.edit_rounded),
                                onPressed: () => _editRoles(user),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
