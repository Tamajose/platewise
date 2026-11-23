import 'dart:typed_data';

import '../domain/meal.dart';

/// What the meal review screen needs. Every feature that produces a meal draft
/// (meal logging, menu comparison, nearby meals, the daily log) opens the
/// review route with this as the route's `extra`.
class ReviewArgs {
  const ReviewArgs(
    this.draft, {
    this.photo,
    this.editorial = false,
    this.discardOnLeave = true,
  });

  final MealDraft draft;

  /// The photo the draft was estimated from, shown above the estimate.
  final Uint8List? photo;

  /// Shows the illustrative hero image instead of a photo.
  final bool editorial;

  /// Deletes the draft's uploaded photo when the person leaves without saving.
  final bool discardOnLeave;
}
