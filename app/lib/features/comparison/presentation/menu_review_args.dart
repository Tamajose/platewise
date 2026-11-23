import 'dart:typed_data';

import '../domain/decision.dart';

/// What the menu review screen needs: the dishes found on a menu (or typed),
/// the budget they are compared against, and the menu photo if there is one.
class MenuReviewArgs {
  const MenuReviewArgs(
    this.options,
    this.budget, {
    this.photo,
    this.sample = false,
    this.language = 'en',
  });

  final List<MenuOption> options;
  final int? budget;
  final bool sample;
  final Uint8List? photo;
  final String language;
}
