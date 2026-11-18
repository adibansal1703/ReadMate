class Reading {
  DateTime? startDate;
  DateTime? finishDate;

  Reading({
    this.startDate,
    this.finishDate,
  });

  factory Reading.fromString(String input) {
    List<String> dateAndValue = input.split('|');

    if (dateAndValue.length < 2) {
      return Reading();
    }

    DateTime? startDate =
        dateAndValue[0] != '' ? DateTime.parse(dateAndValue[0]) : null;
    DateTime? finishDate =
        dateAndValue[1] != '' ? DateTime.parse(dateAndValue[1]) : null;

    return Reading(
      startDate: startDate,
      finishDate: finishDate,
    );
  }

  @override
  String toString() {
    final startDate =
        this.startDate != null ? this.startDate!.toIso8601String() : '';
    final finishDate =
        this.finishDate != null ? this.finishDate!.toIso8601String() : '';

    return '$startDate|$finishDate';
  }

  Reading copyWith({
    DateTime? startDate,
    DateTime? finishDate,
  }) {
    return Reading(
      startDate: startDate ?? this.startDate,
      finishDate: finishDate ?? this.finishDate,
    );
  }
}
