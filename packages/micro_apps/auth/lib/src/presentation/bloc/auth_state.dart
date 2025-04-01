import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';


abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}


class AuthInitialState extends AuthState {
  const AuthInitialState();
}


class AuthLoadingState extends AuthState {
  const AuthLoadingState();
}


class AuthenticatedState extends AuthState {
  final User user;
  
  const AuthenticatedState({required this.user});
  
  @override
  List<Object?> get props => [user];
}


class UnauthenticatedState extends AuthState {
  const UnauthenticatedState();
}


class AuthErrorState extends AuthState {
  final String message;
  
  const AuthErrorState({required this.message});
  
  @override
  List<Object?> get props => [message];
}


class RegisterSuccessState extends AuthState {
  final User user;
  
  const RegisterSuccessState({required this.user});
  
  @override
  List<Object?> get props => [user];
}


class ResetPasswordSuccessState extends AuthState {
  const ResetPasswordSuccessState();
}
