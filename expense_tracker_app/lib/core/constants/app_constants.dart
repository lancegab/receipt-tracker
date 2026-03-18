import '../utils/currency_formatter.dart';

class AppConstants {
  static const String appName = 'Expense Tracker';
  static const String defaultCurrency = 'PHP';
  static const int maxImageSizeBytes = 500 * 1024;
  static const int maxImageDimension = 2048;
  static const int jpegQuality = 85;
  static const int minJpegQuality = 60;

  static List<String> get supportedCurrencies =>
      CurrencyFormatter.currencies.map((c) => c.code).toList();
}
