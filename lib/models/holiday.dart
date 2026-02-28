class Holiday {
  final DateTime date;
  final String name;

  const Holiday({required this.date, required this.name});

  factory Holiday.fromEntry(String dateStr, String name) {
    return Holiday(
      date: DateTime.parse(dateStr),
      name: name,
    );
  }

  @override
  String toString() => 'Holiday($date, $name)';
}

