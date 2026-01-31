class AppConstants {
  static const String appName = 'Expense Tracker';
  static const String defaultCurrency = 'USD';
  static const int maxImageSizeBytes = 500 * 1024;
  static const int maxImageDimension = 2048;
  static const int jpegQuality = 85;
  static const int minJpegQuality = 60;

  static const List<String> supportedCurrencies = [
    'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY', 'CNY', 'INR',
    'BRL', 'MXN', 'KRW', 'SGD', 'HKD', 'NOK', 'SEK', 'DKK',
    'NZD', 'ZAR', 'RUB', 'TRY', 'THB', 'PHP',
  ];
}
