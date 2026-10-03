import 'package:intl/intl.dart';

class DateFormats {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  static String formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0 && dateTime.day == now.day) {
      return 'Hôm nay, ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays <= 1 && dateTime.day == now.day - 1) {
      return 'Hôm qua, ${DateFormat('HH:mm').format(dateTime)}';
    }
    return _dateTimeFormat.format(dateTime);
  }

  static String formatShortDate(DateTime dateTime) {
    return _dateFormat.format(dateTime);
  }
}
