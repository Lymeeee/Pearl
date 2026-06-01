class RemainingElectricity {
  final DateTime date;
  final int remain;
  final double average;

  RemainingElectricity({
    required this.date,
    required this.remain,
    this.average = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'date': date.millisecondsSinceEpoch ~/ 1000,
        'remain': remain,
        'average': average,
      };

  factory RemainingElectricity.fromJson(Map<String, dynamic> json) {
    return RemainingElectricity(
      date: DateTime.fromMillisecondsSinceEpoch(
          (json['date'] as int) * 1000),
      remain: json['remain'] as int,
      average: (json['average'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() =>
      'RemainingElectricity(date: $date, remain: $remain, average: $average)';
}
