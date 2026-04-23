# ADR-0015: HUD/UI Architecture

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | UI |
| **Knowledge Risk** | LOW — CanvasLayer, Control nodes, Tween, and Theme are core UI APIs unchanged since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/modules/ui.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Control node layout scaling on Web (HTML5) across different resolutions (1280×720 → 1920×1080); Godot 4.6 dual focus system — `grab_focus()` 仅影响键盘/手柄焦点，菜单导航需显式处理两种输入模式 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (game state — `state_changed` for UI state switching), ADR-0009 (combo system — `get_combo_count()`, `get_charge_progress()`, `combo_changed` signal), ADR-0010 (player controller — `get_health()`, `health_changed` signal), ADR-0012 (camera — `get_camera_position()` for world-to-screen) |
| **Enables** | Player-facing game experience (HUD is the information layer) |
| **Blocks** | None — HUD is a leaf node system |
| **Ordering Note** | All listed dependencies must be Accepted before implementation; HUD consumes data only, never produces gameplay state |

## Context

### Problem Statement

归宗's art-driven aesthetic demands that UI be an extension of the ink-wash world, not an overlay. The HUD must communicate health (ink drop), combo state (ink accumulation), sword form, and myriad charge without breaking the visual immersion. Menus must emerge from ink, not pop onto screen. Without clear HUD architecture, presentation becomes inconsistent and Web performance degrades from unmanaged UI updates.

### Constraints

- Web (HTML5) target — UI rendering must stay within draw call budget (< 50/frame total including 3D)
- CanvasLayer + Control node architecture (2D overlay on 3D scene)
- Must respect 3 Autoload limit — HUD is a scene node, not Autoload
- Must integrate with ADR-0001 state machine (COMBAT = show HUD, DEATH = game over screen, TITLE = title menu)
- Must integrate with ADR-0009 combo system for charge progress and combo count
- Must integrate with ADR-0010 player controller for health display
- HUD auto-fades to 30% alpha after 3 seconds without taking damage
- 万剑归宗 triggers HUD fade-out, restore after effect ends

### Requirements

- TR-HUD-001: Health ink drop display — size changes with current HP
- TR-HUD-002: Combo counter — ink dots accumulate + gold number
- TR-HUD-003: Charge ring indicator — ink circle fills gold as charge progresses
- TR-HUD-005: Control + CanvasLayer architecture for 2D overlay
- TR-HUD-006: Web platform UI scaling — responsive layout across resolutions

## Decision

### Architecture

The HUD/UI system is a `CanvasLayer` scene node (`HUD.tscn`) with a `Control` root and sub-scenes for each HUD element. It is NOT an Autoload — it lives in the main scene tree and is referenced via group lookup or injected reference. It consumes data from gameplay systems via read-only queries and signal subscriptions. Menu management uses a stack pattern — only one menu is visible at a time, with push/pop semantics.

### Scene Structure

```
HUDLayer (CanvasLayer, layer=10)
└── HUDRoot (Control, full_rect anchor)
    ├── HealthInkDrop (TextureRect) — ink drop, size scales with HP
    ├── ComboCounter (HBoxContainer)
    │   ├── InkDotContainer (HBoxContainer) — preset ink dots
    │   └── ComboNumber (Label) — gold text
    ├── SwordFormIndicator (HBoxContainer) — 3 sword form icons
    ├── ChargeRing (TextureProgressBar) — ink→gold circular ring
    ├── WaveCount (Label) — gold text + ink decoration
    └── MenuLayer (Control, full_rect, hidden by default)
        ├── TitleMenu (Control)
        ├── PauseMenu (Control)
        ├── GameOverMenu (Control)
        └── ScoreScreen (Control)
```

### HUD Elements

| Element | Visual | Data Source | Update Trigger |
|---------|--------|-------------|----------------|
| Health Ink Drop | TextureRect, size scales with HP ratio | `player_controller.get_health()` | `health_changed` signal |
| Combo Counter | Preset ink dots + gold Label | `combo_system.get_combo_count()` | `combo_changed` signal |
| Sword Form Indicator | 3 icons (active=gold, inactive=faded) | `sword_system.get_active_form()` | `form_activated` signal |
| Charge Ring | TextureProgressBar, ink→gold fill | `combo_system.get_charge_progress()` | `combo_changed` signal |
| Wave Count | Gold Label + ink decoration | `wave_manager.get_current_wave()` | `wave_started` signal |

### Health Ink Drop Scaling

```
ink_drop_scale = lerp(min_scale, max_scale, current_hp / max_hp)
```

- `min_scale` = 0.3 (nearly empty when HP=1)
- `max_scale` = 1.0 (full when HP=3)
- HP=3: scale=1.0, HP=2: scale=0.65, HP=1: scale=0.3

### HUD Auto-Fade

```gdscript
var time_since_last_hit: float = 0.0
var hud_alpha: float = 1.0

func _process(delta: float) -> void:
    time_since_last_hit += delta
    var target_alpha = 0.3 if time_since_last_hit > HUD_FADE_DELAY else 1.0
    hud_alpha = lerp(hud_alpha, target_alpha, FADE_SPEED * delta)
    _apply_alpha(hud_alpha)
```

On `health_changed` (damage received): `time_since_last_hit = 0.0`

Tuning knobs: `HUD_FADE_DELAY = 3.0s`, `FADE_SPEED = 5.0`, `target_fade_alpha = 0.3`

### Menu Stack

Menu management uses a stack — only the top menu is visible:

```gdscript
var menu_stack: Array[Control] = []

func show_menu(menu_name: String) -> void:
    var menu = menu_nodes[menu_name]
    menu.visible = true
    menu_stack.push(menu)

func hide_current_menu() -> void:
    if menu_stack.size() > 0:
        var menu = menu_stack.pop_back()
        menu.visible = false
```

| Menu | Trigger State | Content | Transition |
|------|--------------|---------|------------|
| Title | TITLE | Game name + "Start" button | Fade in from ink |
| Pause | COMBAT (cancel key) | Resume/Restart/Quit | Ink overlay |
| Game Over | DEATH | Score + "Try Again" | Ink static backdrop |
| Score Screen | DEATH (detailed) | Wave/combo/myriad stats | Rice paper texture |

### State Integration

| Game State | HUD Behaviour |
|-----------|---------------|
| TITLE | Hide HUD, show TitleMenu |
| COMBAT | Show HUD, hide all menus |
| INTERMISSION | Show HUD (faded), show wave complete indicator |
| DEATH | Hide HUD, show GameOverMenu |
| RESTART | Hide all menus, reset HUD alpha |

### Web Responsive Layout

UI uses Control node anchors and container nodes for responsive scaling:

```gdscript
# In _ready():
get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
    var screen_size = get_viewport().get_visible_rect().size
    # Anchor HUD elements relative to screen edges
    # Health: top-left anchored
    # Combo: top-right anchored
    # Charge Ring: bottom-center anchored
```

### Public API

```gdscript
# Visibility
func show_hud() -> void
func hide_hud() -> void
func show_menu(menu_name: String) -> void
func hide_current_menu() -> void
func hide_all_menus() -> void

# Display updates (called internally via signal handlers)
func update_health_display(current: int, max_hp: int) -> void
func update_combo_display(count: int) -> void
func update_charge_display(progress: float) -> void
func update_wave_display(wave_number: int) -> void

# Effects
func fade_hud(to_alpha: float, duration: float) -> void
func trigger_myriad_hud_effect() -> void
func restore_hud_from_myriad() -> void
```

### Signals

```gdscript
signal menu_opened(menu_name: String)
signal menu_closed(menu_name: String)
signal hud_fade_changed(alpha: float)
```

### Integration Points

| System | Integration | Direction |
|--------|------------|-----------|
| Game State (ADR-0001) | Listens `state_changed` — switches HUD/menu visibility | Consumer |
| Player Controller (ADR-0010) | Reads `get_health()`, listens `health_changed` | Consumer |
| Combo System (ADR-0009) | Reads `get_combo_count()`, `get_charge_progress()`, listens `combo_changed` | Consumer |
| Sword System (ADR-0006) | Reads `get_active_form()`, listens `form_activated` | Consumer |
| Camera System (ADR-0012) | Calls `get_camera_position()` for world-to-screen | Consumer |
| Wave System (ADR-0014) | Reads `get_current_wave()`, listens `wave_started` | Consumer |
| Hit Feedback (ADR-0013) | Receives ink erosion overlay on player hit | Consumer |
| Scoring System (ADR-0017) | Reads score data for GameOver/Score menus | Consumer |

## Alternatives Considered

### Alternative 1: HUD as Autoload Singleton
- **Description**: Make HUDManager a global Autoload for direct access from any system
- **Pros**: Any system can call `HUD.update_health()` without signal wiring
- **Cons**: Adds a 4th Autoload (exceeds 3-singleton guideline); HUD is presentation logic — it should live in the scene tree; Autoload HUD can't be replaced per-scene for testing
- **Rejection Reason**: Violates Autoload minimization principle. Signal-based coupling is sufficient — all data sources already emit signals that HUD can subscribe to.

### Alternative 2: Each System Renders Its Own UI
- **Description**: Player controller owns health bar, combo system owns combo counter, etc.
- **Pros**: No centralized HUD; each system is self-contained
- **Cons**: UI consistency impossible — each system would use different fonts, colors, layouts; z-ordering nightmares on CanvasLayer; no central point for auto-fade or menu stack management
- **Rejection Reason**: Art Bible demands visual consistency. Ink-wash UI aesthetic requires centralized theme and layout management.

### Alternative 3: Signal-Only UI Updates (No Direct Reads)
- **Description**: HUD only updates when signals fire — never polls or reads system state directly
- **Pros**: Fully decoupled; HUD has zero references to gameplay systems
- **Cons**: Initial state setup requires a signal to fire first (HUD may show stale data on scene load); missed signals = stale HUD; no way to recover from a missed `health_changed` without polling
- **Rejection Reason**: Hybrid approach is safer — subscribe to signals for updates, but read initial state in `_ready()` to avoid stale data on load.

## Consequences

### Positive

- Centralized HUD management — one place to tune ink-wash visual consistency
- Menu stack pattern prevents conflicting menu states
- Auto-fade reduces visual clutter during combat without hiding information entirely
- CanvasLayer architecture separates 2D UI from 3D scene rendering
- Signal-based data intake keeps HUD decoupled from gameplay internals

### Negative

- Ink dot combo counter has a fixed maximum (preset dots) — combo > preset count has no visual representation (cap at 20 for MVP)
- Auto-fade may hide critical information during intense combat (HP=1 while faded)
- Menu stack adds complexity — nested menu navigation must be tested per menu pair
- Web resolution scaling requires per-element anchor setup — not automatic

### Risks

- **Stale HUD on scene load**: If a signal is missed during scene transition, HUD may show incorrect state. Mitigation: `_ready()` reads all data sources to initialize display; `state_changed` to COMBAT forces full refresh.
- **Combo dot overflow**: Preset 20 ink dots — if combo exceeds 20, dots have no more visual space. Mitigation: cap visual dots at 20; number label still shows actual count. GDD says max combo is bounded by game difficulty.
- **Web draw call budget**: CanvasLayer + Control nodes contribute to draw call count. With ~10 HUD elements + menus, estimate 15-20 draw calls for UI. Mitigation: share materials between ink elements; use StyleBoxFlat instead of textures where possible.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| hud-ui-system.md | Health ink drop display | TextureRect with size scaling formula: `lerp(0.3, 1.0, hp/max_hp)` |
| hud-ui-system.md | Combo counter with ink dots | HBoxContainer with preset ink dots + gold number Label |
| hud-ui-system.md | Charge ring indicator | TextureProgressBar, ink→gold gradient fill |
| hud-ui-system.md | Control + CanvasLayer architecture | CanvasLayer (layer=10) with Control root and container nodes |
| hud-ui-system.md | Web platform UI scaling | Anchor-based responsive layout with `viewport.size_changed` handler |

## Performance Implications

- **CPU**: Signal handlers + lerp for alpha ≈ 0.01ms/frame (negligible)
- **Memory**: ~10 Control nodes + textures ≈ 50KB
- **Draw Calls**: 15-20 for HUD + menus (within 50/frame budget when combined with 3D)
- **Load Time**: Preloaded textures + Control tree < 5ms

## Validation Criteria

- Health ink drop shrinks as HP decreases (3→2→1)
- Combo counter shows ink dots accumulating + gold number updates in real-time
- Charge ring fills from ink to gold as combo reaches 10
- HUD auto-fades to 30% alpha after 3 seconds without damage
- HUD immediately restores to full alpha on damage received
- 万剑归宗 triggers HUD fade-out, restores after effect
- Title menu shows in TITLE state, hides in COMBAT
- Game over menu shows in DEATH state with score data
- Menu stack: pause menu overlays HUD, resume pops stack
- UI scales correctly at 1280×720 and 1920×1080 on Web

## Related Decisions

- ADR-0001: Game State Architecture — `state_changed` for HUD/menu switching
- ADR-0009: Combo System — `get_combo_count()`, `get_charge_progress()`, `combo_changed`
- ADR-0010: Player Controller — `get_health()`, `health_changed`
- ADR-0012: Camera System — `get_camera_position()` for world-to-screen
- ADR-0013: Hit Feedback — ink erosion overlay on player hit
- ADR-0014: Arena Wave — `get_current_wave()`, `wave_started`
- ADR-0017: Scoring System — score data for game over screen
