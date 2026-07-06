import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

export class Metrics {
  constructor(metadata) {
    this.metadata = metadata;
    this.startedAt = new Date().toISOString();
    this.timings = new Map();
    this.counters = new Map();
    this.errors = [];
  }

  timing(name, milliseconds) {
    if (!Number.isFinite(milliseconds) || milliseconds < 0) return;
    const values = this.timings.get(name) || [];
    values.push(milliseconds);
    this.timings.set(name, values);
  }

  increment(name, amount = 1) {
    this.counters.set(name, (this.counters.get(name) || 0) + amount);
  }

  error(operation, error, userIndex) {
    this.increment('errors');
    if (this.errors.length < 100) {
      this.errors.push({
        operation,
        userIndex,
        message: error instanceof Error ? error.message : String(error),
      });
    }
  }

  snapshot() {
    return {
      metadata: this.metadata,
      startedAt: this.startedAt,
      finishedAt: new Date().toISOString(),
      counters: Object.fromEntries([...this.counters.entries()].sort()),
      timings: Object.fromEntries(
        [...this.timings.entries()].sort().map(([name, values]) => [name, summarize(values)]),
      ),
      sampleErrors: this.errors,
    };
  }

  async save(directory = 'reports') {
    const report = this.snapshot();
    await mkdir(directory, { recursive: true });
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = path.resolve(directory, `load-${timestamp}-shard-${this.metadata.shard}.json`);
    await writeFile(filename, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
    return { filename, report };
  }
}

function summarize(values) {
  if (values.length === 0) return { count: 0 };
  const sorted = [...values].sort((a, b) => a - b);
  const sum = sorted.reduce((total, value) => total + value, 0);
  return {
    count: sorted.length,
    minMs: round(sorted[0]),
    averageMs: round(sum / sorted.length),
    p50Ms: round(percentile(sorted, 0.5)),
    p95Ms: round(percentile(sorted, 0.95)),
    p99Ms: round(percentile(sorted, 0.99)),
    maxMs: round(sorted[sorted.length - 1]),
  };
}

function percentile(sorted, fraction) {
  return sorted[Math.min(sorted.length - 1, Math.ceil(sorted.length * fraction) - 1)];
}

function round(value) {
  return Math.round(value * 100) / 100;
}
