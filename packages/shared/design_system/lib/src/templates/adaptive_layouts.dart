import 'package:flutter/material.dart';
import 'responsive_grid.dart';


class AdaptiveLayout extends StatelessWidget {
  final Widget? mobile;
  final Widget? tablet;
  final Widget? desktop;

  const AdaptiveLayout({
    Key? key,
    this.mobile,
    this.tablet,
    this.desktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, breakpoint) {
        switch (breakpoint) {
          case BreakpointSize.xs:
            return mobile ?? const SizedBox.shrink();
          case BreakpointSize.sm:
            return tablet ?? mobile ?? const SizedBox.shrink();
          case BreakpointSize.md:
          case BreakpointSize.lg:
          case BreakpointSize.xl:
            return desktop ?? tablet ?? mobile ?? const SizedBox.shrink();
        }
      },
    );
  }
}


class AdaptiveTwoColumnLayout extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double spacing;
  final double leftFlex;
  final double rightFlex;
  
  const AdaptiveTwoColumnLayout({
    Key? key,
    required this.left,
    required this.right,
    this.spacing = 16.0,
    this.leftFlex = 1.0,
    this.rightFlex = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, breakpoint) {
        
        if (breakpoint == BreakpointSize.xs) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              SizedBox(height: spacing),
              right,
            ],
          );
        }
        
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: (leftFlex * 100).toInt(),
              child: left,
            ),
            SizedBox(width: spacing),
            Expanded(
              flex: (rightFlex * 100).toInt(),
              child: right,
            ),
          ],
        );
      },
    );
  }
}


class AdaptiveThreeColumnLayout extends StatelessWidget {
  final Widget left;
  final Widget middle;
  final Widget right;
  final double spacing;
  
  const AdaptiveThreeColumnLayout({
    Key? key,
    required this.left,
    required this.middle,
    required this.right,
    this.spacing = 16.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, breakpoint) {
        
        if (breakpoint == BreakpointSize.xs) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              SizedBox(height: spacing),
              middle,
              SizedBox(height: spacing),
              right,
            ],
          );
        }
        
        
        if (breakpoint == BreakpointSize.sm) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  SizedBox(width: spacing),
                  Expanded(child: middle),
                ],
              ),
              SizedBox(height: spacing),
              right,
            ],
          );
        }
        
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            SizedBox(width: spacing),
            Expanded(child: middle),
            SizedBox(width: spacing),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}
