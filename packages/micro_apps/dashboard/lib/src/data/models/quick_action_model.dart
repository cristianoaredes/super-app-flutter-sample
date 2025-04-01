import 'package:flutter/material.dart';

import '../../domain/entities/quick_action.dart';


class QuickActionModel extends QuickAction {
  const QuickActionModel({
    required super.id,
    required super.title,
    required super.description,
    required super.icon,
    required super.route,
    super.routeParams,
    super.isEnabled,
  });
  
  
  factory QuickActionModel.fromJson(Map<String, dynamic> json) {
    return QuickActionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      icon: _getIconFromString(json['icon'] as String),
      route: json['route'] as String,
      routeParams: json['route_params'] != null
          ? Map<String, String>.from(json['route_params'] as Map<String, dynamic>)
          : null,
      isEnabled: json['is_enabled'] as bool? ?? true,
    );
  }
  
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': _getStringFromIcon(icon),
      'route': route,
      'route_params': routeParams,
      'is_enabled': isEnabled,
    };
  }
  
  
  @override
  QuickActionModel copyWith({
    String? id,
    String? title,
    String? description,
    IconData? icon,
    String? route,
    Map<String, String>? routeParams,
    bool? isEnabled,
  }) {
    return QuickActionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      route: route ?? this.route,
      routeParams: routeParams ?? this.routeParams,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
  
  
  static IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'pix':
        return Icons.pix;
      case 'payment':
        return Icons.payment;
      case 'transfer':
        return Icons.swap_horiz;
      case 'deposit':
        return Icons.add_circle_outline;
      case 'withdraw':
        return Icons.money_off;
      case 'card':
        return Icons.credit_card;
      case 'loan':
        return Icons.attach_money;
      case 'investment':
        return Icons.trending_up;
      case 'insurance':
        return Icons.security;
      default:
        return Icons.circle;
    }
  }
  
  
  static String _getStringFromIcon(IconData icon) {
    if (icon == Icons.pix) return 'pix';
    if (icon == Icons.payment) return 'payment';
    if (icon == Icons.swap_horiz) return 'transfer';
    if (icon == Icons.add_circle_outline) return 'deposit';
    if (icon == Icons.money_off) return 'withdraw';
    if (icon == Icons.credit_card) return 'card';
    if (icon == Icons.attach_money) return 'loan';
    if (icon == Icons.trending_up) return 'investment';
    if (icon == Icons.security) return 'insurance';
    return 'circle';
  }
}
