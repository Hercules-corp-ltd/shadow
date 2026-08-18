import 'package:dio/dio.dart';

/// The result of fetching one thing that may legitimately not exist.
///
/// Exists because the app previously collapsed every failure into `null` and
/// then rendered that as "this does not exist". A dead server, a 401, a DNS
/// failure and a genuine 404 are four different facts, and telling a user the
/// domain they typed is unregistered when the truth is that the app could not
/// reach anything is worse than showing no answer at all.
///
/// Callers must handle all three cases — the type is sealed so the analyzer
/// enforces it.
sealed class FetchOutcome<T> {
  const FetchOutcome();
}

/// The thing exists and here it is.
final class FetchSuccess<T> extends FetchOutcome<T> {
  const FetchSuccess(this.value);
  final T value;
}

/// The server answered, and the answer was that this does not exist.
final class FetchNotFound<T> extends FetchOutcome<T> {
  const FetchNotFound();
}

/// Nothing could be established about whether it exists.
final class FetchUnreachable<T> extends FetchOutcome<T> {
  const FetchUnreachable(this.reason);

  /// Human-readable, safe to show. Says what went wrong, not what it means.
  final String reason;
}

/// Turns a Dio failure into an outcome.
///
/// A 404 is the only status treated as "does not exist". Everything else —
/// including 401, which this backend returns for every authenticated route
/// because the auth handshake targets endpoints that were never built — is
/// unreachable, because it tells us nothing about the thing being asked for.
FetchOutcome<T> outcomeFromDio<T>(Object error) {
  if (error is! DioException) {
    return FetchUnreachable<T>('Unexpected error: $error');
  }

  final status = error.response?.statusCode;
  if (status == 404) return FetchNotFound<T>();

  return FetchUnreachable<T>(describeDioFailure(error));
}

/// Plain-language description of a network failure.
String describeDioFailure(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionError:
      return 'Could not reach the server';
    case DioExceptionType.connectionTimeout:
      return 'Timed out connecting to the server';
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.transformTimeout:
      return 'The server stopped responding';
    case DioExceptionType.badCertificate:
      return 'The server presented an invalid certificate';
    case DioExceptionType.cancel:
      return 'The request was cancelled';
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return 'Not signed in to the server (HTTP $status)';
      }
      return 'The server returned an error (HTTP ${status ?? 'unknown'})';
    case DioExceptionType.unknown:
      return 'Could not reach the server';
  }
}
