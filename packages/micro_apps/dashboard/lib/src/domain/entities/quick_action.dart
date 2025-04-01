import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';


class QuickAction extends Equatable {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String route;
  final Map<String, String>? routeParams;
  final bool isEnabled;
  
  const QuickAction({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    this.routeParams,
    this.isEnabled = true,
  });
  
  @override
  List<Object?> get props => [
    id,
    title,
    description,
    icon,
    route,
    routeParams,
    isEnabled,
  ];
  
  
  QuickAction copyWith({
    String? id,
    String? title,
    String? description,
    IconData? icon,
    String? route,
    Map<String, String>? routeParams,
    bool? isEnabled,
  }) {
    return QuickAction(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      route: route ?? this.route,
      routeParams: routeParams ?? this.routeParams,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
