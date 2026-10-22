/// The outcome of an operation that can fail.
///
/// Either [Ok] with a value, or [Error] with the exception that caused the
/// failure. Use a `switch` to handle both cases.
sealed class Result<T> {
  const Result();

  /// A successful result holding [value].
  const factory Result.ok(T value) = Ok._;

  /// A failed result holding [error].
  const factory Result.error(Exception error) = Error._;
}

/// A successful [Result].
final class Ok<T> extends Result<T> {
  const Ok._(this.value);

  /// The value produced by the operation.
  final T value;

  @override
  String toString() => 'Result<$T>.ok($value)';
}

/// A failed [Result].
final class Error<T> extends Result<T> {
  const Error._(this.error);

  /// The exception that caused the failure.
  final Exception error;

  @override
  String toString() => 'Result<$T>.error($error)';
}
