import 'package:flutter/material.dart' hide Card;

import '../../domain/entities/card.dart';


class CardItem extends StatelessWidget {
  final Card card;
  final VoidCallback onTap;

  const CardItem({
    super.key,
    required this.card,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = _getCardColor(card.brand);
    final textColor = _getTextColor(cardColor);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200.0,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cardColor,
              cardColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.4),
              blurRadius: 8.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            
            Positioned(
              top: 16.0,
              left: 16.0,
              child: Icon(
                Icons.credit_card,
                size: 40.0,
                color: textColor,
              ),
            ),

            
            Positioned(
              top: 16.0,
              right: 16.0,
              child: Text(
                card.brand,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            
            Positioned(
              top: 70.0,
              left: 16.0,
              right: 16.0,
              child: Text(
                card.maskedNumber,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.0,
                ),
              ),
            ),

            
            Positioned(
              bottom: 16.0,
              left: 16.0,
              right: 16.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TITULAR',
                        style: TextStyle(
                          color: textColor.withOpacity(0.8),
                          fontSize: 10.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        card.holderName,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'VALIDADE',
                        style: TextStyle(
                          color: textColor.withOpacity(0.8),
                          fontSize: 10.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        '${card.expirationDate.month.toString().padLeft(2, '0')}/${card.expirationDate.year.toString().substring(2)}',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            
            if (card.isBlocked || !card.isActive)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          card.isBlocked ? Icons.lock : Icons.block,
                          color: Colors.white,
                          size: 48.0,
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          card.isBlocked
                              ? 'CARTÃO BLOQUEADO'
                              : 'CARTÃO INATIVO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCardColor(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return const Color(0xFF1A1F71);
      case 'mastercard':
        return const Color(0xFF3D3D3D);
      case 'amex':
      case 'american express':
        return const Color(0xFF2E77BB);
      case 'elo':
        return const Color(0xFF00A4E0);
      case 'hipercard':
        return const Color(0xFFB3131B);
      default:
        return const Color(0xFF2E3192);
    }
  }

  Color _getTextColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
  }
}
