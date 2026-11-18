# Experiment template

> Copy to `docs/experiments/EXP-###-short-slug.md`, fill every section, delete this line.
> One experiment = one hypothesis tested with a reproducible method.

# EXP-###: <Title>

- **Date:** <YYYY-MM-DD>
- **Author/agent:** <name>
- **Task:** <T-###>
- **Status:** Planned | Running | Complete | Abandoned

## Hypothesis

<Falsifiable statement, e.g. "Frame time is CPU-bound in draw submission on map X.">

## Baseline

<What is being compared against? Include the P1 baseline ID or measurements.>

## Method

| Item | Value |
|---|---|
| Game build | <hash / patch / GenTool state> |
| Command line | <exact> |
| Settings | <resolution, detail, windowed/fullscreen> |
| Scenario | <map, faction, duration, replay or script> |
| Tools | <name + version> |
| Repetitions | <n> |

Steps:

1. <step>
2. <step>

## Measurements

| Metric | Baseline | Variant | Delta | Notes |
|---|---:|---:|---:|---|
| <metric> | | | | |

## Result

<Supported / rejected / inconclusive, with the numbers.>

## Interpretation

<What it means and what it does not mean.>

## Artifacts

- `artifacts/<run>/manifest.md` — raw logs/traces.

## Follow-ups

- <next experiment or task>
