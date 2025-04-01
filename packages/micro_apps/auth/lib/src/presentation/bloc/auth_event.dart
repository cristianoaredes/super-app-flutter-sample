import 'package:equatable/equatable.dart';


abstract class AuthEvent extends Equatable {
  const AuthEvent();
  
  @override
  List<Object?> get props => [];
}


class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}


class LoginWithEmailAndPasswordEvent extends AuthEvent {
  final String email;
  final String password;
  
  const LoginWithEmailAndPasswordEvent({
    required this.email,
    required this.password,
  });
  
  @override
  List<Object?> get props => [email, password];
}


class LoginWithGoogleEvent extends AuthEvent {
  const LoginWithGoogleEvent();
}


class LoginWithAppleEvent extends AuthEvent {
  const LoginWithAppleEvent();
}


class LogoutEvent extends AuthEvent {
  const LogoutEvent();
}


class RegisterEvent extends AuthEvent {
  final String name;
  final String email;
  final String password;
  
  const RegisterEvent({
    required this.name,
    required this.email,
    required this.password,
  });
  
  @override
  List<Object?> get props => [name, email, password];
}


class ResetPasswordEvent extends AuthEvent {
  final String email;
  
  const ResetPasswordEvent({
    required this.email,
  });
  
  @override
  List<Object?> get props => [email];
}
