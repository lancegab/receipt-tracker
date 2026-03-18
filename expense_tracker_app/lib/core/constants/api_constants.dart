class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.receipt.lagablab.com/api',
  );

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 90);

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
  static const String recalculateBalances = '/accounts/recalculate';

  // Transaction endpoints
  static const String transactions = '/transactions';
  static const String batchTransactions = '/transactions/batch';

  // Receipt endpoints
  static const String processReceipt = '/receipts/process';
  static const String receipts = '/receipts';

  // Category endpoints
  static const String categories = '/categories';

  // Recurring endpoints
  static const String recurring = '/recurring';

  // Budget endpoints
  static const String budgets = '/budgets';
  static const String budgetGroups = '/budget-groups';
  static const String installments = '/installments';
}
