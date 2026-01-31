class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String googleAuth = '/auth/google';
  static const String facebookAuth = '/auth/facebook';
  static const String appleAuth = '/auth/apple';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Account endpoints
  static const String accounts = '/accounts';

  // Transaction endpoints
  static const String transactions = '/transactions';
  static const String batchTransactions = '/transactions/batch';

  // Receipt endpoints
  static const String presignedUrl = '/receipts/presigned-url';
  static const String processReceipt = '/receipts/process';
  static const String receipts = '/receipts';

  // Category endpoints
  static const String categories = '/categories';
}
