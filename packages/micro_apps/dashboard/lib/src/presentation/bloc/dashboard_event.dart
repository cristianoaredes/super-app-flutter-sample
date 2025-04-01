import 'package:equatable/equatable.dart';


abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  
  @override
  List<Object?> get props => [];
}


class LoadDashboardEvent extends DashboardEvent {
  const LoadDashboardEvent();
}


class RefreshDashboardEvent extends DashboardEvent {
  const RefreshDashboardEvent();
}


class LoadTransactionEvent extends DashboardEvent {
  final String transactionId;
  
  const LoadTransactionEvent({required this.transactionId});
  
  @override
  List<Object?> get props => [transactionId];
}
