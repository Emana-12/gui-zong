# UX Spec: HUD (Heads-Up Display)

> **Screen**: Gameplay HUD
> **Status**: Draft
> **Author**: ux-designer
> **Last Updated**: 2026-04-22
> **GDD Reference**: `design/gdd/hit-feedback.md`, `design/gdd/combo-system.md`
> **ADR Reference**: ADR-0015 (HUD/UI Architecture), ADR-0013 (Hit Feedback)
> **Manifest Version**: 2026-04-22

---

## Screen Purpose

In-game overlay displayed during combat. Communicates player health, current sword form, combo counter, wave progress, and 万剑归宗 (ultimate) readiness. Must not obstruct the 3D combat arena.

## Layout

```
┌─────────────────────────────────────────────────┐
│  [Wave 3/10]                          [Score]   │  ← Top bar: wave info left, score right
│                                                   │
│                                                   │
│                                                   │
│                                                   │
│  ┌──────┐                                         │
│  │ ♥ ♥ ♥│  [Form: 绕剑式]                        │  ← Bottom-left: HP + form indicator
│  │ HP   │  [Combo: 7x]                            │
│  └──────┘  [━━━━━━━━░░░ 万剑归宗]                 │  ← Charge bar under combo
│                                                   │
└─────────────────────────────────────────────────┘
```

## Visual Style

| Element | Style | Notes |
|---------|-------|-------|
| HP hearts | Ink-wash styled, filled = white/gold, empty = gray | 3 hearts max (ADR-0010: HP = 3) |
| Form indicator | Gold text, current form name | "绕剑式" / "游剑式" / "钻剑式" |
| Combo counter | White text, gold glow at 10+ | Fades after combo break |
| Wave info | Semi-transparent top-left | "Wave N/10" format |
| Score | Semi-transparent top-right | Cumulative score |
| 万剑归宗 charge | Ink-wash progress bar, gold fill | Full = pulsing gold glow |
| All text | White on dark, ≥ 4.5:1 contrast | WCAG AA per accessibility-requirements.md |

## HUD Auto-Fade Behavior (per ADR-0015)

- 3 seconds without taking damage → lerp alpha to 30% over 0.5s
- Taking damage → immediately restore to 100% alpha
- 万剑归宗 active → entire HUD fades to 10% to avoid "金色淹没"
- Lerp interpolation, not instant snap

## Navigation Flow

| Input | Action | Context |
|-------|--------|---------|
| Escape | Open pause menu | Push onto menu stack (ADR-0015) |
| Tab (hold) | Show detailed stats overlay | Temporary overlay, release to dismiss |

## Data Sources (per ADR-0015)

| HUD Element | Data Source | Signal Subscription |
|-------------|-------------|---------------------|
| HP hearts | PlayerController | `health_changed(old, new)` |
| Form indicator | ThreeFormsCombat | `form_changed(form_enum)` |
| Combo counter | ComboSystem | `combo_changed(count)` |
| 万剑归宗 charge | ComboSystem | `charge_changed(progress)` |
| Wave info | WaveManager | `wave_started(wave_number, total)` |
| Score | ScoringSystem | `score_changed(total)` |

All data initialized via `_ready()` to prevent stale values on scene load.

## Responsive Behavior

| Viewport | Behavior |
|----------|----------|
| 1920×1080 | Primary layout as shown |
| 1280×720 | Scale UI elements 80%, reduce font sizes |
| Mobile (portrait) | Move HP to top-center, form indicator bottom-center, increase touch targets |

## Accessibility

| Feature | Implementation |
|---------|---------------|
| Text contrast | White on semi-transparent dark ≥ 4.5:1 (WCAG AA) |
| HP indicator | Heart icons + text count (not color-only) |
| Form indicator | Text label always visible (not just color-coded) |
| Combo counter | Number + audio cue on increment |
| Screen reader | Godot 4.6 AccessKit — HUD elements have accessible names |

## Animation

| Element | Animation | Duration |
|---------|-----------|----------|
| HP loss | Heart shatter + shake | 0.3s |
| Form switch | Fade transition | 0.15s |
| Combo +1 | Scale bounce | 0.1s |
| Combo break | Fade out | 0.5s |
| 万剑归宗 ready | Pulsing gold glow | Continuous loop |
| HUD auto-fade | Alpha lerp to 30% | 0.5s after 3s idle |

## Performance Budget

- Draw calls: ≤ 8 (HP hearts + form text + combo + wave + score + charge bar + background panel)
- Memory: ≤ 2MB (fonts + heart textures)
- No post-processing on HUD elements

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| HP reaches 0 | Death screen replaces HUD (ADR-0015: pure white text) |
| Combo at 0 | Combo counter hidden, charge bar hidden |
| Wave transition | Wave info shows "Intermission" |
| Pause menu open | HUD remains visible behind pause overlay |
| 万剑归宗 active | HUD auto-fades to 10% alpha |

## Implementation Notes

- Root node: `HUD` (Control) as child of CanvasLayer (layer = 10)
- HP hearts: HBoxContainer with 3 TextureRect nodes
- Form indicator: Label with dynamic text
- Combo counter: Label, visibility toggled by combo > 0
- Charge bar: ProgressBar with custom StyleBox (ink-wash fill)
- Wave info / Score: Labels anchored to top-left / top-right
- Signal subscriptions established in `_ready()`, disconnected in `_exit_tree()`
- HUD is NOT Autoload — scene node per ADR-0015
