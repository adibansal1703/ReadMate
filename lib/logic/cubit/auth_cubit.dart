import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readmate/resources/api_auth_repository.dart';
import 'package:readmate/resources/api_book_repository.dart';
import 'package:readmate/logic/cubit/challenge_cubit.dart';
import 'package:readmate/logic/cubit/book_cubit.dart';
import 'package:readmate/main.dart';

abstract class AuthCubitState {}

class AuthInitial extends AuthCubitState {}
class AuthLoading extends AuthCubitState {}
class Authenticated extends AuthCubitState {
  final ApiUser user;
  final String? message;
  final String? error;
  Authenticated(this.user, {this.message, this.error});
}
class PasswordRecovery extends AuthCubitState {}
class AwaitingEmailConfirmation extends AuthCubitState {
  final String identifier;
  final String password;
  final String? message;
  AwaitingEmailConfirmation(this.identifier, this.password, {this.message});
}
class Unauthenticated extends AuthCubitState {
  final String? message;
  final bool isEmailUnconfirmed;
  Unauthenticated({this.message, this.isEmailUnconfirmed = false});
}
class AuthError extends AuthCubitState {
  final String message;
  AuthError(this.message);
}
class UserNotFound extends AuthCubitState {
  final String identifier;
  UserNotFound(this.identifier);
}

class AuthCubit extends Cubit<AuthCubitState> {
  final ApiAuthRepository _repository;
  StreamSubscription? _subscription;
  Timer? _pollingTimer;

  AuthCubit(this._repository) : super(AuthInitial()) {
    _init();
  }

  void _init() {
    final user = _repository.currentUser;
    if (user != null) {
      emit(Authenticated(user));
      _onAuthenticated();
    } else {
      emit(Unauthenticated());
    }

    _subscription = _repository.authStateChanges.listen((user) async {
      if (user != null) {
        _pollingTimer?.cancel();
        emit(Authenticated(user));
        await _onAuthenticated();
      } else {
        emit(Unauthenticated());
      }
    });
  }

  void resetToUnauthenticated() {
    _pollingTimer?.cancel();
    emit(Unauthenticated());
  }

  Future<void> _onAuthenticated() async {
    try {
      debugPrint("[API_DEBUG] Auth SUCCESS. Starting critical sync sequence...");
      
      bookCubit.setInitialSyncComplete(false);
      
      debugPrint("[API_DEBUG] Sync Part 1: Backing up local data...");
      await bookCubit.syncLocalToCloud();
      
      debugPrint("[API_DEBUG] Sync Part 2: Fetching cloud state...");
      await bookCubit.fetchFromCloud();
      
      bookCubit.setInitialSyncComplete(true);
      
      debugPrint("[API_DEBUG] Critical sync sequence FINISHED.");
    } catch (e) {
      debugPrint("[API_DEBUG] CRITICAL SYNC FAILURE: $e");
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    emit(AuthLoading());
    try {
      final res = await _repository.signUp(
        email: email, 
        password: password, 
        username: username,
      );

      if (res['is_verified'] == false) {
        emit(AwaitingEmailConfirmation(email, password, message: 'Confirmation link sent to your email!'));
        startPollingConfirmation(email, password);
      }
    } catch (e) {
      emit(AuthError(_handleError(e)));
    }
  }

  void startPollingConfirmation(String identifier, String password) {
    debugPrint("[AUTH_POLL] Starting 4-second auto-login polling for $identifier...");
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      signIn(identifier: identifier, password: password, isSilent: true);
    });
  }

  Future<void> resendVerificationCode(String email) async {
    try {
      await _repository.resendVerificationCode(email);
      if (state is AwaitingEmailConfirmation) {
        final current = state as AwaitingEmailConfirmation;
        emit(AwaitingEmailConfirmation(current.identifier, current.password, message: 'New confirmation link sent to your email!'));
      }
    } catch (e) {
      emit(AuthError(_handleError(e)));
    }
  }

  Future<void> signIn({
    required String identifier,
    required String password,
    bool isSilent = false,
  }) async {
    if (!isSilent) emit(AuthLoading());
    try {
      final user = await _repository.signIn(identifier: identifier, password: password);
      _pollingTimer?.cancel();
      emit(Authenticated(user));
      await _onAuthenticated();
    } catch (e) {
      if (e is UnverifiedUserException) {
        if (!isSilent) {
          emit(AuthError('Email Not Confirmed: Please check your inbox (${e.email}) and click the confirmation link to activate your account.'));
        }
      } else {
        if (!isSilent) {
          _pollingTimer?.cancel();
        }
        final err = e.toString();
        if (err.contains('not found')) {
          if (!isSilent) emit(UserNotFound(identifier));
        } else {
          if (!isSilent) emit(AuthError(_handleError(e)));
        }
      }
    }
  }

  Future<void> forgotPassword(String email) async {
    emit(AuthLoading());
    try {
      final isRegistered = await _repository.isEmailRegistered(email);
      if (!isRegistered) {
        emit(AuthError('This email is not registered. Please create an account first.'));
        return;
      }
      await _repository.resetPasswordForEmail(email);
      emit(Unauthenticated(message: 'Password reset link sent! Please check your email.'));
    } catch (e) {
      emit(AuthError(_handleError(e)));
    }
  }

  Future<void> updatePassword(String newPassword) async {
    emit(AuthLoading());
    try {
      await _repository.updatePassword(newPassword);
      emit(Unauthenticated(message: 'Password updated successfully! Please login with your new password.'));
    } catch (e) {
      emit(AuthError(_handleError(e)));
    }
  }

  Future<void> signOut() async {
    final currentState = state;
    _pollingTimer?.cancel();
    try {
      debugPrint("Performing final sync before logout...");
      await bookCubit.syncLocalToCloud();
      debugPrint("Final sync complete.");
      
      await _repository.signOut();
      bookCubit.clearAllData(); 
      await challengeCubit.clear(); 
      emit(Unauthenticated());
    } catch (e) {
      debugPrint("Sign-out failed due to sync error: $e");
      if (currentState is Authenticated) {
        emit(Authenticated(currentState.user, error: "Logout failed: We couldn't back up your data. Please check your internet connection to avoid data loss."));
      } else {
        emit(AuthError("Sign-out failed: Data sync error."));
      }
    }
  }

  Future<void> deleteAccount(String password) async {
    final currentUser = (state is Authenticated) ? (state as Authenticated).user : null;
    emit(AuthLoading());
    try {
      await _repository.deleteCurrentUser(password);
      emit(Unauthenticated(message: 'Your account and all data have been permanently deleted.'));
    } catch (e) {
      if (currentUser != null) {
        emit(Authenticated(currentUser, error: _handleError(e)));
      } else {
        emit(AuthError(_handleError(e)));
      }
    }
  }

  String _handleError(dynamic e) {
    if (e is TimeoutException) {
      return e.message ?? 'Connection timed out. Please check if "npm start" is running on server.';
    }
    final errorStr = e.toString();
    if (errorStr.contains('Invalid login credentials')) {
      return 'Wrong email/username or password.';
    }
    if (errorStr.contains('SocketException') || errorStr.contains('Connection refused')) {
      return 'Cannot reach backend server. Make sure "npm start" is running on Node.js server.';
    }
    return errorStr.replaceFirst(RegExp(r'^(Exception): '), '');
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _pollingTimer?.cancel();
    return super.close();
  }
}
