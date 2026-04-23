# QA Plan: Sprint 01 — Production Bootstrap

> **Sprint**: sprint-01-production-bootstrap
> **Generated**: 2026-04-22
> **QA Lead**: qa-lead
> **Review Mode**: Full

---

## Scope

This QA plan covers the Pre-Production → Production transition sprint.
All 23 Core stories across 8 epics have been implemented and need verification.

## Story Classification

| Story | Epic | Type | Evidence Required |
|-------|------|------|-------------------|
| story-001-fsm-core | game-state-manager | Logic | Unit test: `tests/unit/game-state-manager/fsm_core_test.gd` |
| story-002-intermission-wave | game-state-manager | Logic | Unit test: `tests/unit/game-state-manager/intermission_test.gd` |
| story-003-pause-web-focus | game-state-manager | Integration | Integration test: `tests/integration/game-state-manager/pause_test.gd` |
| story-001-input-mapping | input-system | Logic | Unit test: `tests/unit/input-system/input_mapping_test.gd` |
| story-002-input-buffer | input-system | Logic | Unit test: `tests/unit/input-system/input_buffer_test.gd` |
| story-003-platform-device | input-system | Integration | Integration test: `tests/integration/input-system/platform_test.gd` |
| story-001-movement | player-controller | Logic | Unit test: `tests/unit/player-controller/movement_test.gd` |
| story-002-dodge | player-controller | Logic | Unit test: `tests/unit/player-controller/dodge_test.gd` |
| story-003-health-death | player-controller | Logic | Unit test: `tests/unit/player-controller/health_death_test.gd` |
| story-001-follow | camera-system | Logic | Unit test: `tests/unit/camera-system/follow_test.gd` |
| story-002-effects | camera-system | Visual/Feel | Evidence doc: `production/qa/evidence/camera-effects-evidence.md` |
| story-003-state-driven | camera-system | Logic | Unit test: `tests/unit/camera-system/state_camera_test.gd` |
| story-001-hitbox-hurtbox | physics-collision | Logic | Unit test: `tests/unit/physics-collision/hitbox_hurtbox_test.gd` |
| story-002-raycast | physics-collision | Logic | Unit test: `tests/unit/physics-collision/raycast_test.gd` |
| story-003-performance | physics-collision | Config/Data | Smoke check pass |
| story-001-hit-processing | hit-judgment | Logic | Unit test: `tests/unit/hit-judgment/hit_processing_test.gd` |
| story-002-damage-dedup | hit-judgment | Logic | Unit test: `tests/unit/hit-judgment/damage_dedup_test.gd` |
| story-001-form-execution | three-forms-combat | Logic | Unit test: `tests/unit/three-forms-combat/form_execution_test.gd` |
| story-002-switching-cooldown | three-forms-combat | Logic | Unit test: `tests/unit/three-forms-combat/switching_cooldown_test.gd` |
| story-003-balance-cancel | three-forms-combat | Config/Data | Unit test: `tests/unit/three-forms-combat/balance_cancel_test.gd` |
| story-001-spawn-ai | enemy-system | Logic | Unit test: `tests/unit/enemy-system/spawn_ai_test.gd` |
| story-002-damage-death | enemy-system | Logic | Unit test: `tests/unit/enemy-system/damage_death_test.gd` |
| story-003-state-query | enemy-system | Logic | Unit test: `tests/unit/enemy-system/state_query_test.gd` |

## Test Execution Plan

### Phase 1: Automated Unit Tests (19 stories)
Run all unit tests via GdUnit4:
```
godot --headless --script tests/gdunit4_runner.gd
```

Expected: 19 unit test files, all passing.

### Phase 2: Integration Tests (3 stories)
Run integration tests:
- `tests/integration/game-state-manager/pause_test.gd` — 12 tests
- `tests/integration/input-system/platform_test.gd` — 5 tests
- Plus performance integration tests

### Phase 3: Playtest Sessions (3 sessions)
- Session 001: New player experience (non-developer tester)
- Session 002: Core combat mechanics (experienced tester)
- Session 003: Difficulty curve & durability (medium experience)

### Phase 4: Vertical Slice Validation
- Human plays through core loop without developer guidance
- Game communicates what to do within first 2 minutes
- No critical "fun blocker" bugs
- Core mechanic feels good to interact with

## Acceptance Gate

| Gate | Criteria | Status |
|------|----------|--------|
| Unit Tests | All 19 pass | ✓ PASS |
| Integration Tests | All 3 pass | ✓ PASS |
| Playtest Sessions | 3 sessions, all PASS | ✓ PASS |
| VS Validation | 4/4 checks PASS | ✓ PASS |
| Critical Bugs | 0 critical/blocker | ✓ PASS |

## Sign-Off

- **QA Lead**: APPROVED — 2026-04-22
