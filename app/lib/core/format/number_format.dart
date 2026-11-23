import 'package:intl/intl.dart';

String number(num value) => NumberFormat.decimalPattern('en').format(value);
