import 'package:flutter/material.dart';

/// Keep filters reachable in short windows without pushing the list out of
/// the viewport. Both regions can scroll independently when the keyboard opens.
class ListPageBody extends StatelessWidget {
  const ListPageBody({super.key, required this.header, required this.child});
  final List<Widget> header;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.6),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: header,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}
