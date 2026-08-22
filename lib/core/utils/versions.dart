/// Compares MAJOR.MINOR.PATCH version strings.
/// Returns <0 when [a] < [b], 0 when equal, >0 when [a] > [b].
int compareVersions(String a, String b) {
  final pa = _parts(a);
  final pb = _parts(b);
  for (var i = 0; i < 3; i++) {
    final diff = pa[i].compareTo(pb[i]);
    if (diff != 0) return diff;
  }
  return 0;
}

List<int> _parts(String v) {
  final m = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(v.trim());
  if (m == null) return const [0, 0, 0];
  return [int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!)];
}
