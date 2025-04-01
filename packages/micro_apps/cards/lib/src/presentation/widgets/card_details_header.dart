import 'package:flutter/material.dart' hide Card;
import 'package:shared_utils/shared_utils.dart';

import '../../domain/entities/card.dart';

class CardDetailsHeader extends StatelessWidget {
  final Card card;

  const CardDetailsHeader({
    Key? key,
    required this.card,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2.0,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  card.brand.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  card.isBlocked ? Icons.lock : Icons.lock_open,
                  color: Colors.white,
                  size: 24.0,
                ),
              ],
            ),
            const SizedBox(height: 24.0),
            Text(
              card.maskedNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24.0,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 24.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TITULAR',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.0,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      card.holderName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'VALIDADE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.0,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      card.expirationDate.toBR,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
