import 'dart:math' as math;

class Profile {
  const Profile({
    required this.height,
    required this.weight,
    required this.target,
    this.waterGoal = 2000,
    this.zone = 'Asia/Dhaka',
    this.units = 'metric',
    this.language = 'en',
    this.correctionConsent = false,
  });
  final double height, weight;
  final int? target;
  final int waterGoal;
  final String zone, units, language;
  final bool correctionConsent;
  double get bmi => weight / math.pow(height / 100, 2);
  double get displayHeight => units == 'us' ? height / 2.54 : height;
  double get displayWeight => units == 'us' ? weight / 0.45359237 : weight;
}
