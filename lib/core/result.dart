import 'errors/app_exception.dart';

/// A simple discriminated result used across services so that failures are
/// always represented by a structured [AppException] rather than raw throws.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;

  T? get valueOrNull => switch (this) { Ok<T>(value: final v) => v, Err<T>() => null };

  AppException? get errorOrNull =>
      switch (this) { Ok<T>() => null, Err<T>(error: final e) => e };

  R fold<R>(R Function(T value) onOk, R Function(AppException error) onErr) =>
      switch (this) { Ok<T>(value: final v) => onOk(v), Err<T>(error: final e) => onErr(e) };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.error);
  final AppException error;
}
