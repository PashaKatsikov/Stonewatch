const displayFont = 'Lilita';

String formatAmount(double value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final left = whole.length - i;
    if (i > 0 && left % 3 == 0) grouped.write(' ');
    grouped.write(whole[i]);
  }
  var frac = parts[1];
  while (frac.endsWith('0')) {
    frac = frac.substring(0, frac.length - 1);
  }
  final body = frac.isEmpty ? grouped.toString() : '$grouped.$frac';
  return negative ? '-$body' : body;
}

String formatMult(double value) {
  var s = value.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return 'x$s';
}
