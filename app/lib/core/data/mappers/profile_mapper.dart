import '../../domain/domain.dart';
import '../json.dart';

Profile profileFromJson(Json json) => Profile(
  height: (json['height_cm'] as num).toDouble(),
  weight: (json['weight_kg'] as num).toDouble(),
  target: json['daily_calorie_target'] as int?,
  waterGoal: json['water_goal_ml'] as int? ?? 2000,
  zone: json['timezone'] as String,
  units: json['preferred_units'] as String,
  language: json['preferred_language'] as String? ?? 'en',
  correctionConsent: json['correction_consent'] as bool? ?? false,
);

/// The API's `update_profile` input carries `target_confirmed`. The demo
/// store's own copy ([stored] true) carries `correction_consent` instead.
Json profileToJson(
  Profile profile, {
  bool confirmed = false,
  bool stored = false,
}) => {
  'height_cm': profile.height,
  'weight_kg': profile.weight,
  'daily_calorie_target': profile.target,
  'water_goal_ml': profile.waterGoal,
  'timezone': profile.zone,
  'preferred_units': profile.units,
  'preferred_language': profile.language,
  if (stored)
    'correction_consent': profile.correctionConsent
  else
    'target_confirmed': confirmed,
};
