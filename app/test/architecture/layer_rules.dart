/// Layer rules from docs/architecture.md, as pure functions so they can be
/// tested with synthetic input as well as run against the real source tree.
library;

enum Layer { domain, data, presentation, other }

/// A source file's position in the architecture.
class Position {
  const Position(this.layer, this.feature);

  /// The layer, or [Layer.other] for the shell, theme, widgets and config.
  final Layer layer;

  /// The owning feature, or null for `core/` and the shell.
  final String? feature;
}

const _allowedDart = {
  'dart:async',
  'dart:collection',
  'dart:math',
  'dart:typed_data',
};
const _allowedDomainPackages = {'collection', 'meta', 'timezone'};

/// Classifies a path relative to `lib/`, such as `features/meals/domain/x.dart`.
Position positionOf(String libPath) {
  final parts = libPath.split('/');
  if (parts.length >= 3 && parts[0] == 'features') {
    final layer = switch (parts[2]) {
      'domain' => Layer.domain,
      'data' => Layer.data,
      'presentation' => Layer.presentation,
      _ => Layer.other,
    };
    return Position(layer, parts[1]);
  }
  if (parts.length >= 3 && parts[0] == 'core') {
    return switch (parts[1]) {
      'domain' => const Position(Layer.domain, null),
      'data' => const Position(Layer.data, null),
      'presentation' => const Position(Layer.presentation, null),
      _ => const Position(Layer.other, null),
    };
  }
  return const Position(Layer.other, null);
}

/// Resolves an import written in a file at [fromLibPath] to a path relative to
/// `lib/`, or null when it does not point into this project's `lib/`.
String? resolveProjectImport(String fromLibPath, String import) {
  if (import.startsWith('package:platewise/')) {
    return import.substring('package:platewise/'.length);
  }
  if (import.startsWith('dart:') || import.startsWith('package:')) return null;
  final base = Uri.parse('file:///lib/$fromLibPath');
  final resolved = base.resolve(import).path;
  return resolved.startsWith('/lib/')
      ? resolved.substring('/lib/'.length)
      : null;
}

/// Returns a description of every rule [libPath] breaks given its [imports].
List<String> violations(String libPath, List<String> imports) {
  final self = positionOf(libPath);
  final problems = <String>[];
  for (final import in imports) {
    final target = resolveProjectImport(libPath, import);
    final targetPosition = target == null ? null : positionOf(target);

    // Shared code never depends on a feature.
    if (libPath.startsWith('core/') &&
        target != null &&
        target.startsWith('features/')) {
      problems.add('core file $libPath imports a feature: $import');
    }

    // Features never import each other.
    if (targetPosition != null &&
        self.feature != null &&
        targetPosition.feature != null &&
        targetPosition.feature != self.feature) {
      problems.add('$libPath imports another feature: $import');
    }

    switch (self.layer) {
      case Layer.domain:
        if (target == null) {
          final isPackage = import.startsWith('package:');
          final name = isPackage ? import.split(':')[1].split('/').first : '';
          final allowed = isPackage
              ? _allowedDomainPackages.contains(name)
              : _allowedDart.contains(import);
          if (!allowed) {
            problems.add('domain file $libPath imports $import');
          }
        } else if (targetPosition!.layer != Layer.domain) {
          problems.add('domain file $libPath imports non-domain $import');
        }
      case Layer.data:
        if (targetPosition != null &&
            targetPosition.layer == Layer.presentation) {
          problems.add('data file $libPath imports presentation $import');
        }
      case Layer.presentation:
        final isProviders =
            target != null && target.endsWith('_providers.dart');
        if (targetPosition != null &&
            targetPosition.layer == Layer.data &&
            !isProviders) {
          problems.add(
            'presentation file $libPath imports data $import '
            '(only *_providers.dart is allowed)',
          );
        }
      case Layer.other:
        break;
    }
  }
  return problems;
}

final _importPattern = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

List<String> importsIn(String source) =>
    _importPattern.allMatches(source).map((m) => m.group(1)!).toList();
