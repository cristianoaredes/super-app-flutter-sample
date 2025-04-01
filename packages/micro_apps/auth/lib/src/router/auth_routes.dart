import 'package:go_router/go_router.dart';

import '../presentation/pages/login_page.dart';
import '../presentation/pages/register_page.dart';
import '../presentation/pages/reset_password_page.dart';


class AuthRoutes {
  static const String loginPath = '/login';
  static const String registerPath = '/register';
  static const String resetPasswordPath = '/reset-password';

  
  static List<GoRoute> get routes => [
        GoRoute(
          path: loginPath,
          name: 'login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: registerPath,
          name: 'register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: resetPasswordPath,
          name: 'reset-password',
          builder: (context, state) => const ResetPasswordPage(),
        ),
      ];
}
