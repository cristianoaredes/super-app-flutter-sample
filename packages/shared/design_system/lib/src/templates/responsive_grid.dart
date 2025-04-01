import 'package:flutter/material.dart';
import '../atoms/spacing.dart';

enum BreakpointSize {
  xs, 
  sm, 
  md, 
  lg, 
  xl, 
}


class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, BreakpointSize) builder;

  const ResponsiveBuilder({
    Key? key,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final breakpoint = _getBreakpoint(width);
        return builder(context, breakpoint);
      },
    );
  }

  BreakpointSize _getBreakpoint(double width) {
    if (width < 600) return BreakpointSize.xs;
    if (width < 960) return BreakpointSize.sm;
    if (width < 1280) return BreakpointSize.md;
    if (width < 1920) return BreakpointSize.lg;
    return BreakpointSize.xl;
  }
}


class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final Map<BreakpointSize, int> columns;

  const ResponsiveGrid({
    Key? key,
    required this.children,
    this.spacing = BankSpacing.md,
    this.columns = const {
      BreakpointSize.xs: 1,
      BreakpointSize.sm: 2,
      BreakpointSize.md: 3,
      BreakpointSize.lg: 4,
      BreakpointSize.xl: 6,
    },
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, breakpoint) {
        final columnCount = columns[breakpoint] ?? 1;
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 1.0,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}
