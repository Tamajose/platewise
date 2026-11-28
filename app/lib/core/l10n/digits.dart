const _bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

/// Replaces the digits 0 to 9 in [text] with Bangla digits.
String toBanglaDigits(String text) => text.replaceAllMapped(
  RegExp('[0-9]'),
  (match) => _bangla[match.group(0)!.codeUnitAt(0) - 0x30],
);
