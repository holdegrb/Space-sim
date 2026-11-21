const _suffixes = ['', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No'];

/// 999, 1.23K, 45.6M, 789B ... then scientific notation.
String formatNumber(double n) {
  if (n.isNaN) return '0';
  if (n < 0) return '-${formatNumber(-n)}';
  if (n < 1000) return n.floor().toString();
  var tier = 0;
  var v = n;
  while (v >= 1000 && tier < _suffixes.length - 1) {
    v /= 1000;
    tier++;
  }
  if (v >= 1000) return n.toStringAsExponential(2).replaceAll('+', '');
  final digits = v < 10 ? 2 : (v < 100 ? 1 : 0);
  // Truncate rather than round so 999.96K never shows as "1000K".
  final f = _pow10(digits);
  final t = (v * f).floor() / f;
  return '${t.toStringAsFixed(digits)}${_suffixes[tier]}';
}

double _pow10(int d) => d == 0 ? 1 : (d == 1 ? 10 : 100);

/// "3h 12m", "45m", "30s".
String formatDuration(Duration d) {
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m';
  return '${d.inSeconds}s';
}
