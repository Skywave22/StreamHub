class Person {
  const Person({
    required this.name,
    this.character,
    this.job,
    this.profileUrl,
  });

  final String name;

  /// For cast members, the character they play.
  final String? character;

  /// For crew members, their job/department.
  final String? job;

  final String? profileUrl;

  String get role => job ?? character ?? '';

  bool get isCast => character != null;
  bool get isCrew => job != null;
}
