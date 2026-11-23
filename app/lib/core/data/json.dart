typedef Json = Map<String, dynamic>;

/// Reads a JSON array of objects, treating null as empty.
List<Json> jsonRows(Object? value) =>
    (value as List? ?? []).map((e) => Json.from(e as Map)).toList();
