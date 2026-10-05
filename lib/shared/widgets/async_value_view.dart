import '../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';

/// Small generic loading/error/empty/data switcher used by every list view,
/// replacing the repetitive @if patterns in the Angular templates.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.loading,
    required this.error,
    required this.data,
    required this.builder,
    this.isEmpty,
    this.emptyMessage = 'No hay datos para mostrar todavía.',
    this.onRetry,
  });

  final bool loading;
  final Object? error;
  final T? data;
  final Widget Function(BuildContext context, T data) builder;
  final bool Function(T data)? isEmpty;
  final String emptyMessage;
  final VoidCallback? onRetry;

  /// True when there is nothing meaningful to show yet — either `data` is
  /// null, or the caller's `isEmpty` callback says so (e.g. an empty list,
  /// or a wrapper state whose inner nullable field is null). Every caller in
  /// this app passes a non-null default state object (empty list, no
  /// summary, etc), so checking `data == null` alone would never be true and
  /// a real `error` would be silently masked as this generic empty state
  /// instead of being shown.
  bool get _hasNoData => data == null || (isEmpty?.call(data as T) ?? false);

  @override
  Widget build(BuildContext context) {
    if (loading && _hasNoData) {
      return Center(child: CircularProgressIndicator());
    }
    if (error != null && _hasNoData) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 40,
              ),
              SizedBox(height: 12),
              Text(context.tr('$error'), textAlign: TextAlign.center),
              if (onRetry != null) ...[
                SizedBox(height: 12),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(context.tr('Reintentar')),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final value = data;
    if (value == null || (isEmpty?.call(value) ?? false)) {
      return Center(
        child: Text(
          context.tr(emptyMessage),
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    return builder(context, value);
  }
}
