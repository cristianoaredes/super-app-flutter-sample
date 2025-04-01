import 'package:flutter/material.dart';


class PixActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;
  
  const PixActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Theme.of(context).colorScheme.primary;
    
    return Column(
      children: [
        Material(
          color: themeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.0),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              width: 60.0,
              height: 60.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Icon(
                icon,
                size: 32.0,
                color: themeColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          title,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            color: themeColor,
          ),
        ),
      ],
    );
  }
}
