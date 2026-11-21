import '../../../../core/failures.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<({bool success, Failure? failure})> call({
    required String email,
    required String password,
  }) async {
    if (!email.contains('@') || password.length < 6) {
      return (
        success: false,
        failure: const LocalFailure('Email atau kata sandi tidak valid'),
      );
    }

    try {
      await repository.login(email: email, password: password);
      return (success: true, failure: null);
    } catch (e) {
      return (success: false, failure: LocalFailure(e.toString()));
    }
  }
}
