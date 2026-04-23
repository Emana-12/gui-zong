# UX Spec: Pause Menu

> **Screen**: Pause Menu (overlay)
> **Status**: Draft
> **Author**: ux-designer
> **Last Updated**: 2026-04-22
> **GDD Reference**: `design/gdd/game-concept.md`
> **ADR Reference**: ADR-0015 (HUD/UI Architecture), ADR-0001 (Game State)
> **Manifest Version**: 2026-04-22

---

## Screen Purpose

Overlay displayed when the player pauses gameplay. Provides resume, settings, and quit options. Uses push/pop menu stack per ADR-0015.

## Layout

```
┌─────────────────────────────────────────────────┐
│                                                   │
│           [dimmed game scene behind]              │
│                                                   │
│        ┌─────────────────────────┐                │
│        │       暂 停              │  ← Title: gold
│        │                         │                │
│        │      [ Resume ]         │  ← Primary CTA
│        │      [ Settings ]       │  ← Secondary
│        │      [ Quit ]           │  ← Tertiary
│        │                         │                │
│        └─────────────────────────┘                │
│                                                   │
└─────────────────────────────────────────────────┘
```

## Visual Style

| Element | Style | Notes |
|---------|-------|-------|
| Background overlay | Semi-transparent black (60% alpha) | Dims game scene |
| Panel | Ink-wash border, centered | Not full-screen panel |
| Title "暂停" | Gold calligraphy | Matches main menu style |
| Buttons | Ink-wash border, white text | Gold glow on hover/focus |
| Focus indicator | Gold underline | Keyboard/gamepad navigation |

## Navigation Flow

| Input | Action | Destination |
|-------|--------|-------------|
| Resume click / Enter / Escape | Pop pause menu | → Return to gameplay |
| Settings click / S key | Push settings overlay | → Settings menu (push) |
| Quit click / Q key | Confirm → return to main menu | → Main menu scene |
| Escape (on settings) | Pop settings overlay | → Back to pause menu |

## Menu Stack Behavior (per ADR-0015)

- Pause menu pushes onto the menu stack
- Settings opens as a second push (stack: [HUD] → [Pause] → [Settings])
- Escape always pops the topmost menu
- Only one menu visible at a time
- `get_tree().paused = true` when pause menu is active (per ADR-0001)

## State Transitions

| From | To | Trigger |
|------|----|---------|
| COMBAT | PAUSED | Escape key / Pause button |
| PAUSED | COMBAT | Resume / Escape again |
| PAUSED | TITLE | Quit confirmed |

GameStateManager handles state change via `change_state(STATE.PAUSED)` — validated transition.

## Responsive Behavior

| Viewport | Behavior |
|----------|----------|
| 1920×1080 | Primary layout as shown |
| 1280×720 | Scale panel 80%, reduce spacing |
| Mobile (portrait) | Full-width panel, increase touch targets to 48px |

## Accessibility

| Feature | Implementation |
|---------|---------------|
| Text contrast | Gold on dark ≥ 4.5:1 (WCAG AA) |
| Keyboard navigation | Tab cycles buttons, Enter activates, Escape resumes |
| Screen reader | Godot 4.6 AccessKit — buttons have accessible names |
| No color-as-only | Buttons have text labels |
| Focus trap | Tab cycles within pause menu only (not behind overlay) |

## Animation

| Element | Animation | Duration |
|---------|-----------|----------|
| Overlay appear | Fade in from 0% to 60% alpha | 0.2s |
| Panel appear | Scale from 90% to 100% + fade | 0.2s ease-out |
| Button hover | Gold border glow | 0.15s |
| Dismiss | Reverse of appear | 0.15s |

## Performance Budget

- Draw calls: ≤ 6 (overlay + panel + 3 buttons + title)
- Post-processing: 0 passes
- Memory: ≤ 1MB (reuse main menu fonts/styles)

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Rapid Escape presses | Debounce — ignore for 0.3s after first press |
| Settings opened then closed | Return focus to Resume button |
| Quit confirmation | Two-step: first click shows "确认退出?" with Yes/No |
| Game already paused by another system | Pause menu ignores duplicate pause request |
| Web focus loss (ADR-0001) | Auto-pause → pause menu appears |

## Implementation Notes

- Root node: `PauseMenu` (Control) as child of CanvasLayer (layer = 20)
- Background: ColorRect with 60% black alpha, full rect
- Panel: CenterContainer → VBoxContainer with title + buttons
- All buttons: Button nodes with custom StyleBox (matching main menu)
- State change: `GameStateManager.change_state(GameStateManager.STATE.PAUSED)`
- Resume: `GameStateManager.change_state(GameStateManager.STATE.COMBAT)`
- Quit: fade to black → `SceneManager.change_scene("main_menu")` per ADR-0016
- Pause menu is NOT Autoload — scene node per ADR-0015
- Input routing through InputSystem Autoload, never direct Input singleton
