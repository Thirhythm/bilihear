import 'dart:async';

import 'package:bilihear/core/api/api_exception.dart';
import 'package:bilihear/core/models/bili_user.dart';
import 'package:bilihear/data/repositories/auth_repository.dart';
import 'package:bilihear/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sign-in status of the Bilibili account.
class AuthState {
  const AuthState({
    this.initialized = false,
    this.loading = false,
    this.user,
    this.error,
  });

  final bool initialized;
  final bool loading;
  final BiliUser? user;
  final String? error;

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    bool? initialized,
    bool? loading,
    BiliUser? user,
    String? error,
    bool clearUser = false,
  }) => AuthState(
    initialized: initialized ?? this.initialized,
    loading: loading ?? this.loading,
    user: clearUser ? null : (user ?? this.user),
    error: error,
  );
}

final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Owns the account session and exposes it to the rest of the app.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(refresh);
    return const AuthState();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Reloads the account information from the API.
  Future<void> refresh() async {
    if (!_repository.isLoggedIn) {
      if (ref.mounted) state = const AuthState(initialized: true);
      return;
    }
    if (ref.mounted) {
      state = AuthState(
        initialized: state.initialized,
        loading: true,
        user: state.user,
      );
    }
    try {
      final user = await _repository.fetchCurrentUser();
      if (ref.mounted) state = AuthState(initialized: true, user: user);
    } on BiliApiException catch (error) {
      if (ref.mounted) {
        state = AuthState(
          initialized: true,
          user: state.user,
          error: error.message,
        );
      }
    }
  }

  /// Clears the session both locally and on the server.
  Future<void> logout() async {
    await _repository.logout();
    if (ref.mounted) state = const AuthState(initialized: true);
  }
}

/// Steps of the QR login flow shown by the login page.
enum QrStatus { loading, waiting, scanned, expired, success, failed }

class QrLoginViewState {
  const QrLoginViewState({
    this.status = QrStatus.loading,
    this.qrContent,
    this.message,
  });

  final QrStatus status;

  /// Content to render as a QR code.
  final String? qrContent;
  final String? message;
}

final NotifierProvider<QrLoginController, QrLoginViewState> qrLoginProvider =
    NotifierProvider<QrLoginController, QrLoginViewState>(
      QrLoginController.new,
    );

/// Drives the QR code login: creates a code and polls until it is confirmed.
class QrLoginController extends Notifier<QrLoginViewState> {
  static const Duration _pollInterval = Duration(seconds: 2);

  Timer? _timer;
  String? _key;
  bool _polling = false;

  @override
  QrLoginViewState build() {
    ref.onDispose(() => _timer?.cancel());
    Future.microtask(start);
    return const QrLoginViewState();
  }

  /// Requests a new QR code (also used by the "refresh" button).
  Future<void> start() async {
    _timer?.cancel();
    _polling = false;
    if (ref.mounted) state = const QrLoginViewState();
    try {
      final session = await ref.read(authRepositoryProvider).createQrSession();
      _key = session.key;
      if (!ref.mounted) return;
      state = QrLoginViewState(
        status: QrStatus.waiting,
        qrContent: session.url,
      );
      _schedulePoll();
    } on BiliApiException catch (error) {
      if (ref.mounted) {
        state = QrLoginViewState(
          status: QrStatus.failed,
          message: error.message,
        );
      }
    }
  }

  void _schedulePoll() {
    _timer?.cancel();
    _timer = Timer(_pollInterval, _poll);
  }

  Future<void> _poll() async {
    final key = _key;
    if (key == null || _polling || !ref.mounted) return;
    _polling = true;
    try {
      final result = await ref.read(authRepositoryProvider).pollQrSession(key);
      if (!ref.mounted) return;
      switch (result.status) {
        case QrLoginStatus.waiting:
          state = QrLoginViewState(
            status: QrStatus.waiting,
            qrContent: state.qrContent,
          );
          _schedulePoll();
        case QrLoginStatus.scanned:
          state = QrLoginViewState(
            status: QrStatus.scanned,
            qrContent: state.qrContent,
          );
          _schedulePoll();
        case QrLoginStatus.expired:
          state = const QrLoginViewState(status: QrStatus.expired);
        case QrLoginStatus.success:
          state = const QrLoginViewState(status: QrStatus.success);
          await ref.read(authControllerProvider.notifier).refresh();
        case QrLoginStatus.failed:
          state = QrLoginViewState(
            status: QrStatus.failed,
            message: result.message,
          );
      }
    } on BiliApiException catch (error) {
      if (ref.mounted) {
        state = QrLoginViewState(status: QrStatus.failed, message: error.message);
      }
    } finally {
      _polling = false;
    }
  }
}
