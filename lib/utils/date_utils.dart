String formatDateNative(DateTime dt) {
  final luni = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final luna = luni[dt.month - 1];
  final ziua = dt.day.toString().padLeft(2, '0');
  final ora = dt.hour.toString().padLeft(2, '0');
  final minut = dt.minute.toString().padLeft(2, '0');

  return '$ziua $luna ${dt.year} • $ora:$minut';
}
