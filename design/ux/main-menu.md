# UX Spec: Main Menu

> **Screen**: Title / Main Menu
> **Status**: Draft
> **Author**: ux-designer
> **Last Updated**: 2026-04-22
> **GDD Reference**: `design/gdd/game-concept.md`
> **ADR Reference**: ADR-0015 (HUD/UI Architecture)
> **Manifest Version**: 2026-04-22

---

## Screen Purpose

Title screen displayed on game launch. Establishes the shanshui (水墨) visual identity and provides the primary entry point to gameplay.

## Layout

```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│           归 宗                     │  ← Title: gold ink calligraphy, centered
│         Gui Zong                    │  ← Subtitle: white, smaller
│                                     │
│                                     │
│                                     │
│           [ Start ]                 │  ← Primary CTA: gold border, white text
│           [ Settings ]              │  ← Secondary: subtle ink wash style
│                                     │
│                                     │
│                                     │
│    ┌─────────────────────────┐      │
│    │    Version 0.1.0        │      │  ← Footer: semi-transparent
│    └─────────────────────────┘      │
└─────────────────────────────────────┘
```

## Visual Style

| Element | Style | Notes |
|---------|-------|-------|
| Background | Animated ink wash landscape | Subtle parallax or slow particle drift |
| Title "归宗" | Gold calligraphy, large | Core visual anchor |
| Subtitle "Gui Zong" | White sans-serif, small | Below title |
| Buttons | Ink wash border, gold text on hover | Minimal, monochrome palette |
| Focus indicator | Gold glow / underline | Keyboard/gamepad navigation |

## Navigation Flow

| Input | Action | Destination |
|-------|--------|-------------|
| Start button click / Enter | Start new game | → Arena scene (wave 1) |
| Settings button click / S key | Open settings overlay | → Settings menu (push) |
| Escape (on title) | Quit (Web: no-op) | N/A |

## Interaction Patterns Used

- **Button** — standard CTA with hover/focus/disabled states
- **Menu Stack** — settings opens as overlay (push/pop, per ADR-0015)
- **Input Routing** — all input through InputSystem Autoload, never direct `Input` singleton

## Responsive Behavior

| Viewport | Behavior |
|----------|----------|
| 1920×1080 | Primary layout as shown |
| 1280×720 | Scale title down 80%, reduce spacing |
| Mobile (portrait) | Stack vertically, increase touch target to 48px |

## Accessibility

| Feature | Implementation |
|---------|---------------|
| Text contrast | Gold on dark background ≥ 4.5:1 (WCAG AA) |
| Keyboard navigation | Tab cycles buttons, Enter activates |
| Screen reader | Godot 4.6 AccessKit — buttons have accessible names |
| No color-as-only | Buttons have text labels, not just color states |

## Animation

| Element | Animation | Duration |
|---------|-----------|----------|
| Background | Slow ink wash drift | Continuous loop |
| Title appear | Fade in + slight scale | 1.0s ease-out |
| Button hover | Gold border glow | 0.2s |
| Screen transition | Fade to black | 0.3s (per ADR-0016) |

## Performance Budget

- Draw calls: ≤ 10 (background + UI elements)
- Post-processing: 0 passes (ink wash is sprite-based)
- Memory: ≤ 5MB (background art + fonts)

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Rapid Start presses | Debounce — ignore input for 0.5s after first press |
| Settings opened then closed | Return focus to Start button |
| No gamepad connected | Hide gamepad prompt icons |
| Window resize | Re-anchor all Control nodes via `viewport.size_changed` |

## Implementation Notes

- Root node: `MainMenu` (Control) as child of CanvasLayer
- All buttons are `Button` nodes with custom StyleBox
- Background is a `TextureRect` with animated shader or `AnimatedSprite2D`
- Scene transition uses SceneManager (per ADR-0016): fade → queue_free → add_child
- Music: BGM starts here (AudioServer bus: Master → BGM)
