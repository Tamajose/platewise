class CalorieRange {
  const CalorieRange(this.low, this.high);
  static const zero = CalorieRange(0, 0);
  final int low, high;
  int get midpoint => ((low + high) / 2).round();
  String get label => low == high ? '$low' : '$low–$high';
  CalorieRange operator +(CalorieRange other) =>
      CalorieRange(low + other.low, high + other.high);
  CalorieRange remaining(int target) =>
      CalorieRange(target - high, target - low);
}
