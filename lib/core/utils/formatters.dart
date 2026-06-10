import 'package:intl/intl.dart';

class Formatters {
  static final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 4);
  static final _compactCurrency =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _dateTime = DateFormat('MMM d, yyyy HH:mm');
  static final _number = NumberFormat.decimalPattern();

  static String currency(double value) {
    if (value > 0 && value < 0.00005) return '<\$0.0001';
    return _currency.format(value);
  }

  static String compactCurrency(double value) =>
      _compactCurrency.format(value);

  static String dateTime(DateTime value) => _dateTime.format(value);

  static String tokens(int value) => _number.format(value);
}
