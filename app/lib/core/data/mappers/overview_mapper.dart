import '../../domain/domain.dart';
import '../json.dart';
import 'meal_mapper.dart';
import 'profile_mapper.dart';

TargetSnapshot targetSnapshotFromJson(Json json) =>
    TargetSnapshot(json['effective_on'] as String, json['target_kcal'] as int?);

Json targetSnapshotToJson(TargetSnapshot target) => {
  'effective_on': target.day,
  'target_kcal': target.target,
};

WaterEntry waterEntryFromJson(Json json) => WaterEntry(
  json['id'] as String,
  DateTime.parse(json['logged_at'] as String),
  json['amount_ml'] as int,
  json['updated_at'] as String,
);

Json waterEntryToJson(WaterEntry entry) => {
  'id': entry.id,
  'logged_at': entry.at.toUtc().toIso8601String(),
  'amount_ml': entry.amount,
  'updated_at': entry.revision,
};

Overview overviewFromJson(Json json) => Overview(
  profile: json['profile'] == null
      ? null
      : profileFromJson(Json.from(json['profile'] as Map)),
  meals: jsonRows(json['meals']).map(savedMealFromJson).toList(),
  targets: jsonRows(json['targets']).map(targetSnapshotFromJson).toList(),
  water: jsonRows(json['water']).map(waterEntryFromJson).toList(),
  localDay: json['local_day'] == null
      ? null
      : DateTime.parse('${json['local_day']}T00:00Z'),
  pendingAssets: json['pending_asset_count'] as int? ?? 0,
  deletionPending: json['deletion_pending'] as bool? ?? false,
  deletionAccount: json['deletion_account'] as bool? ?? false,
  sampleHistory: json['sample_history'] as bool? ?? false,
);

/// The shape the demo store persists. It is a subset of the API's dashboard
/// response, so [overviewFromJson] reads it back.
Json overviewToStoredJson(Overview overview) => {
  'profile': overview.profile == null
      ? null
      : profileToJson(overview.profile!, stored: true),
  'meals': overview.meals.map(savedMealToJson).toList(),
  'water': overview.water.map(waterEntryToJson).toList(),
  'targets': overview.targets.map(targetSnapshotToJson).toList(),
  'sample_history': overview.sampleHistory,
};
