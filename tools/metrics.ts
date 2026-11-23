export type Observation = {
  expected: number;
  result: { calorie_low: number; calorie_high: number; representative_calories: number } | null;
  elapsedMs: number;
};

export function estimateMetrics(rows: Observation[]) {
  const valid = rows.filter((r) => r.result !== null);
  const errors = valid.map((r) => r.result!.representative_calories - r.expected);
  const mean = (values: number[]) => values.length ? values.reduce((a, b) => a + b, 0) / values.length : null;
  const latencies = rows.map((r) => r.elapsedMs).sort((a, b) => a - b);
  return {
    attempted: rows.length,
    valid: valid.length,
    failed: rows.length - valid.length,
    mean_absolute_error_kcal: mean(errors.map(Math.abs)),
    mean_signed_error_kcal: mean(errors),
    empirical_range_coverage: mean(
      valid.map((r) => Number(r.expected >= r.result!.calorie_low && r.expected <= r.result!.calorie_high)),
    ),
    p50_ms_including_failures: latencies.length ? latencies[Math.ceil(latencies.length * .50) - 1] : null,
    p95_ms_including_failures: latencies.length ? latencies[Math.ceil(latencies.length * .95) - 1] : null,
  };
}
