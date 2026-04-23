# Sprint 01: Production Bootstrap

> **Sprint**: 01
> **Phase**: Pre-Production → Production transition
> **Start**: 2026-04-22
> **Duration**: 2 weeks
> **Goal**: Resolve all gate-check blockers and pass the Pre-Production → Production gate

## Sprint Objective

This sprint resolves the FAIL verdict from `/gate-check production`. The primary
deliverables are: a playable Vertical Slice, UX specs for key screens, playtest
validation, and architecture sign-offs.

## Priority Tiers

### Must Have (blocks gate passage)

| # | Story / Task | Type | Est | Status | Notes |
|---|-------------|------|-----|--------|-------|
| 1 | Build Vertical Slice playable build | Integration | 8h | Not Started | Based on `design/vertical-slice.md` scope. Core loop: start → combat → wave clear → intermission → next wave |
| 2 | UX Spec: Main Menu | UI | 2h | Not Started | `design/ux/main-menu.md` — Title screen, start game, settings entry |
| 3 | UX Spec: HUD | UI | 3h | `design/ux/hud.md` — Health, combo, wave info, form indicator |  |
| 4 | UX Spec: Pause Menu | UI | 2h | Not Started | `design/ux/pause-menu.md` — Pause/resume, settings, quit |
| 5 | Interaction Patterns Library | UI | 1h | Not Started | `design/ux/interaction-patterns.md` — initialize with core patterns |
| 6 | Playtest Session 1 — New Player Experience | Playtest | 2h | Not Started | `production/playtests/session-001.md` |
| 7 | Playtest Session 2 — Core Loop Feel | Playtest | 2h | Not Started | `production/playtests/session-002.md` |
| 8 | Playtest Session 3 — Difficulty Curve | Playtest | 2h | Not Started | `production/playtests/session-003.md` |
| 9 | Architecture Sign-off: TD | Review | 1h | Not Started | Technical Director must sign `docs/architecture/architecture.md` |
| 10 | Architecture Sign-off: LP | Review | 1h | Not Started | Lead Programmer must sign `docs/architecture/architecture.md` |
| 11 | Run prototype in Godot | Validation | 1h | Not Started | Resolve CD-PLAYTEST CONCERNS |

### Should Have (improves quality, not blocking)

| # | Story / Task | Type | Est | Status | Notes |
|---|-------------|------|-----|--------|-------|
| 12 | UX Review: all 3 specs | Review | 1h | Not Started | `/ux-review` after specs are written |
| 13 | Accessibility integration in UX specs | UI | 1h | Not Started | Reference `design/accessibility-requirements.md` in each UX spec |

## Story File References

Stories are in `production/epics/` — all 23 Core stories are Complete.
This sprint focuses on non-story artifacts required by the gate.

## Sprint Health

| Metric | Target | Actual |
|--------|--------|--------|
| Must Have items | 11 | 11 |
| Completed | 0 | 0 |
| Blocked | 0 | 0 |
| Velocity | — | TBD |

## Notes

- This is a bootstrap sprint — no code stories, only documentation and validation artifacts
- Vertical Slice build is the highest-effort item (8h) and the critical path blocker
- Playtest sessions can run in parallel once the VS build is ready
- Architecture sign-offs can happen independently of VS build
