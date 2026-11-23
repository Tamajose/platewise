import 'package:timezone/timezone.dart' as tz;

import '../../../core/domain/profile.dart';
import '../../../core/domain/target_policy.dart';

const _cmPerInch = 2.54;
const _kgPerPound = .45359237;

const minHeightCm = 100.0, maxHeightCm = 250.0;
const minWeightKg = 30.0, maxWeightKg = 350.0;
const minWaterGoalMl = 500, maxWaterGoalMl = 5000;

const targetConfirmationMessage =
    'Confirm that adult target-setting applies to you, or leave the target blank.';
const timezoneMessage = 'Enter an IANA timezone such as Asia/Dhaka.';
const waterGoalMessage = 'Enter a goal between 500 and 5,000 ml.';

double? _number(String text) {
  final value = double.tryParse(text.trim());
  return value != null && value.isFinite ? value : null;
}

/// Height in centimetres from typed text in [units] (`metric` or `us`), or
/// null when it is not a number.
double? heightCm(String text, String units) {
  final value = _number(text);
  return value == null ? null : value * (units == 'us' ? _cmPerInch : 1);
}

/// Weight in kilograms from typed text in [units], or null.
double? weightKg(String text, String units) {
  final value = _number(text);
  return value == null ? null : value * (units == 'us' ? _kgPerPound : 1);
}

String? heightError(String text, String units) {
  final cm = heightCm(text, units);
  if (cm != null && cm >= minHeightCm && cm <= maxHeightCm) return null;
  return units == 'us' ? 'Enter 39.38–98.42 inches.' : 'Enter 100–250 cm.';
}

String? weightError(String text, String units) {
  final kg = weightKg(text, units);
  if (kg != null && kg >= minWeightKg && kg <= maxWeightKg) return null;
  return units == 'us' ? 'Enter 66.14–771.61 lb.' : 'Enter 30–350 kg.';
}

/// Converts a typed measurement to [next] units for display, so switching
/// units keeps the same height or weight.
String convertHeight(String text, String from, String to) {
  final cm = heightCm(text, from);
  if (cm == null) return text;
  return (to == 'us' ? cm / _cmPerInch : cm).toStringAsFixed(2);
}

String convertWeight(String text, String from, String to) {
  final kg = weightKg(text, from);
  if (kg == null) return text;
  return (to == 'us' ? kg / _kgPerPound : kg).toStringAsFixed(2);
}

/// Body mass index, or null when the height or weight is out of range.
double? bmi(String height, String weight, String units) {
  final cm = heightCm(height, units), kg = weightKg(weight, units);
  if (cm == null || kg == null) return null;
  if (cm < minHeightCm || cm > maxHeightCm) return null;
  if (kg < minWeightKg || kg > maxWeightKg) return null;
  return kg / ((cm / 100) * (cm / 100));
}

String? timezoneError(String zone) {
  try {
    tz.getLocation(zone.trim());
    return null;
  } on Object {
    return timezoneMessage;
  }
}

/// A typed target. Blank is fine; anything else must be a whole number in the
/// pilot range.
String? targetFieldError(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final value = int.tryParse(trimmed);
  return value == null ? 'Enter a whole number.' : targetError(value);
}

String? waterGoalError(String text) {
  final value = int.tryParse(text.trim());
  return value == null || value < minWaterGoalMl || value > maxWaterGoalMl
      ? waterGoalMessage
      : null;
}

/// What the profile form collected, as typed.
class ProfileInput {
  const ProfileInput({
    required this.units,
    required this.height,
    required this.weight,
    required this.target,
    required this.zone,
    required this.language,
    required this.waterGoal,
    required this.targetConfirmed,
    this.correctionConsent = false,
  });

  final String units, height, weight, target, zone, language, waterGoal;
  final bool targetConfirmed, correctionConsent;
}

/// Checks [input] and builds the profile. Returns the profile, or the first
/// problem found as a message to show.
({Profile? profile, String? error}) buildProfile(ProfileInput input) {
  final error =
      heightError(input.height, input.units) ??
      weightError(input.weight, input.units) ??
      timezoneError(input.zone) ??
      targetFieldError(input.target) ??
      waterGoalError(input.waterGoal);
  if (error != null) return (profile: null, error: error);
  final target = int.tryParse(input.target.trim());
  if (target != null && !input.targetConfirmed) {
    return (profile: null, error: targetConfirmationMessage);
  }
  return (
    profile: Profile(
      height: (heightCm(input.height, input.units)! * 10).round() / 10,
      weight: (weightKg(input.weight, input.units)! * 10).round() / 10,
      target: target,
      units: input.units,
      zone: input.zone.trim(),
      language: input.language,
      waterGoal: int.parse(input.waterGoal.trim()),
      correctionConsent: input.correctionConsent,
    ),
    error: null,
  );
}
