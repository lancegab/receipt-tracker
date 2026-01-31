class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const AppException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'AppException: $message (status: $statusCode)';
}

class NetworkException extends AppException {
  const NetworkException([String message = 'Network error occurred'])
      : super(message);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([String message = 'Unauthorized'])
      : super(message, statusCode: 401);
}

class NotFoundException extends AppException {
  const NotFoundException([String message = 'Not found'])
      : super(message, statusCode: 404);
}

class ServerException extends AppException {
  const ServerException([String message = 'Server error'])
      : super(message, statusCode: 500);
}

class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException(
    String message, {
    this.fieldErrors,
  }) : super(message, statusCode: 422);
}
