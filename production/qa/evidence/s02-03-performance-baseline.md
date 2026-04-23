# S02-03: Performance Baseline Report

**Story**: S02-03 Performance Baseline Report
**Date**: 2026-04-22
**Tester**: Claude (automated profiling infrastructure)
**Platform**: Web (HTML5) — target: WebGL 2.0

## Overview

Performance baseline measurement for the 3D arena combat scene at 3/5/10 simultaneous enemies. Measures frame time, draw calls, static memory, and triangle count against defined budgets.

## Budget Targets

| Metric | Budget | Source |
|--------|--------|--------|
| Frame Time (max) | ≤ 16.6ms | 60fps target |
| Draw Calls (max) | ≤ 50/frame | Technical Preferences |
| Scene Triangles (max) | ≤ 10,000 | Technical Preferences |
| Memory (max) | Monitor only | Web platform — no fixed ceiling |

## Test Methodology

1. Open `tests/integration/performance-baseline/baseline_test.tscn` in Godot editor
2. Run Scene (F6)
3. The profiler automatically cycles through 3 → 5 → 10 enemies
4. Each level observes for 5 seconds, collecting per-frame metrics
5. Results print to console and display on UI label

## Baseline Results

> **Note**: Run the test scene to populate actual measurements. Values below are placeholders.

### 3 Enemies

| Metric | Avg | Min | Max | P95 | Budget Pass |
|--------|-----|-----|-----|-----|-------------|
| Frame Time (ms) | — | — | — | — | — |
| Draw Calls | — | — | — | — | — |
| Memory (MB) | — | — | — | N/A | N/A |
| Triangles | — | — | — | — | — |

### 5 Enemies

| Metric | Avg | Min | Max | P95 | Budget Pass |
|--------|-----|-----|-----|-----|-------------|
| Frame Time (ms) | — | — | — | — | — |
| Draw Calls | — | — | — | — | — |
| Memory (MB) | — | — | — | N/A | N/A |
| Triangles | — | — | — | — | — |

### 10 Enemies

| Metric | Avg | Min | Max | P95 | Budget Pass |
|--------|-----|-----|-----|-----|-------------|
| Frame Time (ms) | — | — | — | — | — |
| Draw Calls | — | — | — | — | — |
| Memory (MB) | — | — | — | N/A | N/A |
| Triangles | — | — | — | — | — |

## Overall Verdict

| Level | Frame Time | Draw Calls | Triangles | Overall |
|-------|-----------|------------|-----------|---------|
| 3 enemies | — | — | — | — |
| 5 enemies | — | — | — | — |
| 10 enemies | — | — | — | — |

**Overall**: Awaiting manual test run.

## Files

- Profiler script: `tests/integration/performance-baseline/baseline_profiler.gd`
- Test scene: `tests/integration/performance-baseline/baseline_test.tscn`

## Acceptance Criteria Verification

- [x] Baseline profiler measures frame time per enemy count level
- [x] Baseline profiler measures draw calls per enemy count level
- [x] Baseline profiler measures memory usage per enemy count level
- [x] Baseline profiler measures triangle count per enemy count level
- [x] Budget pass/fail reported per metric
- [x] Test scene auto-runs through all enemy count levels
- [ ] Actual baseline values recorded (requires manual test run)
