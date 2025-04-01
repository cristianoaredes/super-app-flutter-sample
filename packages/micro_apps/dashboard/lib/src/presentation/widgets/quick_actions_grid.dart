import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/quick_action.dart';


class QuickActionsGrid extends StatelessWidget {
  final List<QuickAction> quickActions;

  const QuickActionsGrid({
    super.key,
    required this.quickActions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ações Rápidas',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 0.8,
              ),
              itemCount: quickActions.length,
              itemBuilder: (context, index) {
                final action = quickActions[index];
                return _QuickActionItem(action: action);
              },
            ),
          ],
        ),
      ),
    );
  }
}


class _QuickActionItem extends StatelessWidget {
  final QuickAction action;

  const _QuickActionItem({required this.action});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 98.0, 
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: action.isEnabled
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16.0),
            child: InkWell(
              onTap: action.isEnabled
                  ? () {
                      
                      final navigationService =
                          GetIt.instance<NavigationService>();
                      navigationService.navigateTo(
                        action.route,
                        params: action.routeParams,
                      );
                    }
                  : null,
              borderRadius: BorderRadius.circular(16.0),
              child: Container(
                width: 60.0,
                height: 60.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Icon(
                  action.icon,
                  size: 32.0,
                  color: action.isEnabled
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4.0),
          Flexible(
            child: Text(
              action.title,
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: action.isEnabled ? null : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
