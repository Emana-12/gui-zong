# Interaction Pattern Library

> **Status**: Draft
> **Author**: ux-designer
> **Last Updated**: 2026-04-22
> **ADR Reference**: ADR-0015 (HUD/UI Architecture)
> **Manifest Version**: 2026-04-22

---

## Purpose

Central reference for all reusable UI interaction patterns in 归宗. Every screen
must use patterns from this library — do not invent one-off interaction styles.

---

## Pattern: Button (Standard CTA)

**Used in**: Main Menu, Pause Menu, Settings, Death Screen

| Property | Value |
|----------|-------|
| Node type | `Button` |
| StyleBox | Custom ink-wash border, white text |
| Hover | Gold border glow, 0.15s transition |
| Focus | Gold underline indicator |
| Disabled | 50% alpha, no hover effect |
| Press | Scale 95% → 100% bounce, 0.1s |
| Min size | 200×48px (48px touch target for mobile) |

**States**: Default → Hover → Pressed → Released → Default

**Accessibility**: Must have `accessible_name` set. Focus order follows visual order (top-to-bottom, left-to-right).

---

## Pattern: Menu Stack (Push/Pop)

**Used in**: Main Menu → Settings, Pause Menu → Settings

| Property | Value |
|----------|-------|
| Data structure | Array (stack) |
| Push | Add menu as child, disable input on lower menus |
| Pop | Remove topmost menu, re-enable input on previous |
| Constraint | Only one menu visible at a time |
| Transition | Fade in (push) / Fade out (pop), 0.2s |

**Escape key behavior**: Always pops the topmost menu. If stack has only 1 item (gameplay HUD), opens pause menu.

**Implementation**: MenuManager tracks the stack. Each menu is a Control node added/removed from the CanvasLayer.

---

## Pattern: Input Routing

**Used in**: All screens

| Property | Value |
|----------|-------|
| Source | InputSystem Autoload |
| Forbidden | Direct `Input` singleton access |
| Buffer capacity | 1 (ADR-0002) |
| Capture method | `_input()` not `_process()` |
| Gamepad | Auto-detect, show/hide gamepad prompt icons |

**Rule**: All UI input queries go through `InputSystem.is_action_just_pressed()`. Never call `Input.is_action_just_pressed()` directly.

---

## Pattern: Screen Transition

**Used in**: All scene changes

| Property | Value |
|----------|-------|
| Method | Fade-to-black via CanvasLayer mask |
| Duration | 0.3s fade in → scene change → 0.3s fade out |
| Easing | Linear (not eased — consistent timing) |
| Scene change | SceneManager manual add_child/remove_child |
| Forbidden | `change_scene_to_packed()` (ADR-0016) |

**Sequence**:
1. Fade mask to 100% black (0.3s)
2. `queue_free()` old scene root
3. `add_child()` new scene root
4. Fade mask to 0% (0.3s)

---

## Pattern: HUD Auto-Fade

**Used in**: Gameplay HUD

| Property | Value |
|----------|-------|
| Idle threshold | 3 seconds without player damage |
| Fade target | 30% alpha |
| Fade duration | 0.5s lerp |
| Restore trigger | Player takes damage |
| Override | 万剑归宗 active → fade to 10% |

**Implementation**: Timer resets on `health_changed` signal. When timer expires, lerp modulate.a toward 0.3. On damage signal, lerp toward 1.0 immediately.

---

## Pattern: Focus Navigation

**Used in**: All menus

| Property | Value |
|----------|-------|
| Keyboard | Tab to cycle, Enter to activate |
| Gamepad | D-pad / left stick to cycle, A to activate |
| Focus indicator | Gold underline or glow (visible, not subtle) |
| Wrap | First → Last and Last → First |
| Trap | Active menu only — Tab does not reach elements behind overlay |

**Accessibility**: Every focusable element must have `focus_mode = FOCUS_ALL`. Focus order set via `focus_neighbor_*` properties or implicit tree order.

---

## Pattern: Confirmation Dialog

**Used in**: Quit game, destructive actions

| Property | Value |
|----------|-------|
| Trigger | Clicking Quit or destructive action |
| Content | "确认退出？" + Yes/No buttons |
| Default focus | No (safer default) |
| Dismiss | Escape or No → close dialog, return focus to trigger |
| Confirm | Yes → execute action |

**Implementation**: AcceptDialog or custom Control overlay. Pushed onto menu stack.

---

## Pattern: Responsive Layout

**Used in**: All screens

| Property | Value |
|----------|-------|
| Anchoring | Control node anchors (not pixel positions) |
| Resize handler | `viewport.size_changed` signal |
| Primary viewport | 1920×1080 |
| Scale factor | 80% at 1280×720 |
| Mobile | Stack vertically, 48px min touch targets |

**Rule**: Never use absolute pixel positions. Always use anchor presets or container nodes. Font sizes scale with viewport via theme overrides.

---

## Adding New Patterns

When a new interaction pattern is needed:
1. Check this library first — reuse if possible
2. If genuinely new, add a section here with the full property table
3. Update `Manifest Version` in the header to current date
4. Reference the pattern in the relevant UX spec's "Interaction Patterns Used" section
