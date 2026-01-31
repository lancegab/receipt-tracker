import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, {String currency = 'USD'}) {
    final format = NumberFormat.currency(
      locale: 'en_US',
      symbol: _getSymbol(currency),
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  static String _getSymbol(String currency) {
    const symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CNY': '¥',
      'KRW': '₩',
      'INR': '₹',
      'BRL': 'R\$',
      'PHP': '₱',
      'THB': '฿',
    };
    return symbols[currency] ?? currency;
  }
}
