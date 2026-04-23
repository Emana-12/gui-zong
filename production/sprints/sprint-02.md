# Sprint 02: Foundation Verification & Production Hardening

> **Sprint**: 02
> **Phase**: Production — Foundation layer verification
> **Start**: 2026-04-22
> **Duration**: 2 weeks (10 working days)
> **Goal**: Resolve all 7 director concerns from Pre-Production gate check, verify infrastructure readiness, and begin Foundation story creation

## Sprint Objective

This sprint addresses the 7 director concerns raised during the Pre-Production gate check
(CONCERNS — ADVANCE verdict). The primary deliverables are: verified CI pipeline,
Jolt Web export proof, performance baselines, ink-wash shader prototype, accessibility
Basic tier, asset manifest, and tuning instrumentation. Foundation story creation for
shader-rendering and audio-system epics follows infrastructure verification.

**Capacity**: 32h total | 25.6h available | 6.4h buffer (20% reserved)

## Priority Tiers

### Must Have (blocks Production confidence — all 7 director concerns)

| # | Story / Task | Type | Est | Status | Director Concern | Acceptance Criteria |
|---|-------------|------|-----|--------|-----------------|---------------------|
| 1 | CI Pipeline Verification (S02-02) | Infrastructure | 3h | Not Started | TD-04 | Green build on GitHub Actions with Godot 4.6.2, all 24+ existing tests passing |
| 2 | Jolt Web Export Verification (S02-04) | Infrastructure | 3h | Not Started | TD-03 | Web export builds and runs, collision detection verified in 3 scenarios (floor, wall, dynamic body) |
| 3 | Performance Baseline Report (S02-03) | Analysis | 3h | Not Started | TD-05 | Baseline report with frame time, draw calls, memory for 3/5/10 enemy counts on WebGL target |
| 4 | Tuning Metrics Instrumentation (S02-07) | Analytics | 3h | Not Started | CD-02 | Analytics events fire for combo length, trigger rate, dead zone frequency; values logged and exportable |
| 5 | Ink-Wash Shader Prototype (S02-01) | Technical Art | 4h | Not Started | CD-01, AD-01 | Prototype runs at >=50fps on WebGL, ink-wash effect visible in 3 test scenes |
| 6 | Accessibility Basic Tier (S02-05) | UX | 6h | Not Started | AD-06 | Input remapping functional, subtitles display correctly at all resolutions |
| 7 | Asset Deliverable Manifest (S02-06) | Art Pipeline | 3h | Not Started | AD-07 | Asset audit generates manifest linking all GDD references to files on disk |

**Must Have subtotal**: 25h (within 25.6h available capacity)

### Should Have (Foundation story creation — improved scope)

| # | Story / Task | Type | Est | Status | Notes |
|---|-------------|------|-----|--------|-------|
| 8 | Foundation Epic: Create shader-rendering stories (S02-08) | Story Creation | 4h | Not Started | `production/epics/shader-rendering/` — stories not yet created per index.md |
| 9 | Foundation Epic: Create audio-system stories (S02-09) | Story Creation | 4h | Not Started | `production/epics/audio-system/` — stories not yet created per index.md |

**Should Have subtotal**: 8h (revised from 4h to match actual story creation effort for 2 epics)

### Nice to Have (stretch goal)

| # | Story / Task | Type | Est | Status | Notes |
|---|-------------|------|-----|--------|-------|
| 10 | First Feature layer story implementation (S02-10) | Development | 4h | Not Started | Stretch — only if Must Have and Should Have complete within Days 1-8 |

**Nice to Have subtotal**: 4h (deferred from "Must Have" — feature implementation is premature until foundation verification is complete)

## Task Ordering (Producer Recommended)

Infrastructure-first approach — build environment risks resolved before dependent work:

| Days | Tasks | Rationale |
|------|-------|-----------|
| 1-2 | S02-02 CI Pipeline + S02-04 Jolt Web | Build environment validated first; all downstream work depends on verified build |
| 3-4 | S02-03 Performance Baseline + S02-07 Tuning Metrics | Requires working Web export from Days 1-2 |
| 5-6 | S02-01 Ink-Wash Shader Prototype | Requires WebGL baseline from Days 3-4 for performance comparison |
| 7-8 | S02-05 Accessibility + S02-06 Asset Manifest | Can run in parallel; lower risk |
| 9-10 | S02-08/09 Story Creation + Buffer | Story creation uses buffer time; if earlier tasks slip, absorb here |

## Risk Register

| Risk | Severity | Mitigation |
|------|----------|------------|
| **S02-05 Accessibility: AccessKit Web support unknown** | HIGH | 6h estimate assumes AccessKit is not needed or has stable Web support. If AccessKit integration is required, effort may double to ~12h. Mitigation: spike AccessKit status on Day 7 before committing to implementation. If blocked, implement remapping/subtitles without AccessKit and defer platform accessibility to Sprint 03. |
| **S02-04 Jolt: Web export build fails** | HIGH | Jolt on Web flagged HIGH risk by TD. Mitigation: front-loaded to Days 1-2 so failure is detected early. Fallback: switch to Godot default physics for Web, keep Jolt for desktop in Sprint 03. |
| **S02-02 CI: Godot 4.6.2 runner unavailable** | MEDIUM | CI environment may not have Godot 4.6.2 cached. Mitigation: use containerized runner or manual install script. Budget extra time in Days 1-2. |
| **S02-01 Shader: Ink-wash effect exceeds GPU budget** | MEDIUM | WebGL GPU budget is tight. Mitigation: prototype uses simplest viable technique first; optimize in later sprint if >=50fps is achievable. |

## Story File References

Stories are in `production/epics/` — 10 epics total (22 created stories, 2 Foundation epics pending).

- 8 epics with stories: game-state-manager, input-system, player-controller, physics-collision, hit-judgment, three-forms-combat, enemy-system, camera-system
- 2 epics pending story creation: shader-rendering (S02-08), audio-system (S02-09)

## Acceptance Criteria Summary

| Task | Quantified Pass Condition |
|------|--------------------------|
| S02-01 Shader | WebGL prototype >=50fps, ink-wash effect visible in 3 test scenes |
| S02-02 CI | Green GitHub Actions build with Godot 4.6.2, 24+ tests passing |
| S02-03 Perf | Report covers frame time, draw calls, memory for 3/5/10 enemy scenarios |
| S02-04 Jolt | Web export builds, collision verified in floor/wall/dynamic-body scenarios |
| S02-05 Access | Input remapping functional, subtitles display correctly at all resolutions |
| S02-06 Manifest | Audit generates manifest linking all GDD asset references to disk files |
| S02-07 Metrics | Analytics fire for combo length, trigger rate, dead zone frequency |
| S02-08 Shader Stories | Epic file with >=3 stories following project story format |
| S02-09 Audio Stories | Epic file with >=3 stories following project story format |

## Sprint Health

| Metric | Target | Actual |
|--------|--------|--------|
| Must Have items | 7 | 7 |
| Should Have items | 2 | 2 |
| Nice to Have items | 1 | 1 |
| Completed | 0 | 0 |
| Blocked | 0 | 0 |
| Velocity | — | TBD |

## Notes

- **20% capacity buffer (6.4h)** reserved for unplanned work, debugging, and CI/environment issues
- **Front-loaded risk**: Days 1-2 tackle the two highest-risk infrastructure items (CI + Jolt Web) so failures are detected early with time to pivot
- **Accessibility risk**: S02-05 (6h) may escalate to ~12h if AccessKit is required for Web. Spike status on Day 7 before implementation — if blocked, defer platform-specific accessibility to Sprint 03
- **Story creation scope revised**: S02-08/09 estimated at 8h total (4h each), up from original 4h total, reflecting actual effort for creating 2 full Foundation epic story files
- **Feature implementation deferred**: S02-10 moved to Nice to Have — feature layer work should not begin until Foundation verification is complete and CI is green
- This sprint is infrastructure-heavy by design; the gate check revealed unverified build environments that must be resolved before gameplay development proceeds at full speed
