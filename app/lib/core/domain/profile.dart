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

  /// A copy with the given fields replaced. The target can be replaced but
  /// not cleared this way.
  Profile copyWith({int? target, bool? correctionConsent}) => Profile(
    height: height,
    weight: weight,
    target: target ?? this.target,
    waterGoal: waterGoal,
    zone: zone,
    units: units,
    language: language,
    correctionConsent: correctionConsent ?? this.correctionConsent,
  );

  double get bmi => weight / math.pow(height / 100, 2);
  double get displayHeight => units == 'us' ? height / 2.54 : height;
  double get displayWeight => units == 'us' ? weight / 0.45359237 : weight;
}
