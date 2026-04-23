# ADR-0017: Scoring System Architecture

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Core |
| **Knowledge Risk** | LOW — FileAccess, JSON, and signal APIs are core, unchanged since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/modules/file-io.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | FileAccess write/read on Web (HTML5) — falls back to JavaScript localStorage if FileAccess is restricted |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009 (combo system — `get_combo_count()`, `myriad_triggered` signal), ADR-0014 (arena wave — `get_current_wave()`) |
| **Enables** | ADR-0015 (HUD — score display on game over screen), ADR-0018 (skill progression — run data aggregation) |
| **Blocks** | HUD game over screen (needs score data), skill progression (needs run data) |
| **Ordering Note** | ADR-0009 and ADR-0014 must be Accepted before implementation; this ADR is a leaf dependency — nothing blocks it beyond those two |

## Context

### Problem Statement

归宗 is a "再来一局" game — infinite waves, no win state. Without a scoring system, there is no record of performance, no "beat your best" motivation, and no data for the skill progression system. The scoring system is the persistence layer between runs — it answers "how far did you get?" and "did you beat your record?"

### Constraints

- Web (HTML5) target — persistence uses FileAccess (with JavaScript localStorage fallback)
- Only 3 tracked metrics: best wave, best combo, total myriad triggers
- Score data must be available at game over (DEATH state) for HUD display
- Must not provide any gameplay advantage — purely informational
- Must reset per-run data on each new run (RESTART state)
- Per-run data consumed by ADR-0018 (skill progression) for run recording

### Requirements

- TR-SCR-001: Best record tracking — highest wave, longest combo, most myriad triggers across all runs
- TR-SCR-002: Web localStorage persistence — survive page refresh
- TR-SCR-003: Cross-system data collection — gather wave/combo/myriad data from gameplay systems

## Decision

### Architecture

The Scoring System is a `Node` scene node (`ScoringSystem.tscn`) that tracks per-run metrics and maintains best records. It is NOT an Autoload — it lives in the main scene tree. It reads data from gameplay systems via their public APIs and signal subscriptions. Best records persist to a JSON file via FileAccess (with Web fallback). Per-run data is reset on RESTART and available for consumption by HUD and skill progression at DEATH.

### Data Model

```gdscript
class_name RunData

var best_wave: int = 0
var best_combo: int = 0
var myriad_count: int = 0
var run_duration: float = 0.0  # seconds, for skill progression frequency calc

class_name BestRecords

var best_wave: int = 0
var best_combo: int = 0
var total_myriad: int = 0  # lifetime total myriad triggers (across all runs)
```

### Per-Run Data Collection

The scoring system subscribes to gameplay signals to track per-run metrics:

```gdscript
func _on_wave_completed(wave_number: int) -> void:
    if wave_number > current_run.best_wave:
        current_run.best_wave = wave_number

func _on_combo_changed(count: int) -> void:
    if count > current_run.best_combo:
        current_run.best_combo = count

func _on_myriad_triggered() -> void:
    current_run.myriad_count += 1
```

Run duration is tracked via `_process(delta)` accumulation while in COMBAT state.

### Best Record Update

On DEATH state (run ended):
```gdscript
func _on_state_changed(old_state: int, new_state: int) -> void:
    match new_state:
        State.DEATH:
            _finalize_run()
        State.RESTART:
            _reset_current_run()

func _finalize_run() -> void:
    var new_records = false
    if current_run.best_wave > best_records.best_wave:
        best_records.best_wave = current_run.best_wave
        new_records = true
    if current_run.best_combo > best_records.best_combo:
        best_records.best_combo = current_run.best_combo
        new_records = true
    best_records.total_myriad += current_run.myriad_count
    if new_records:
        _save_records()
    run_completed.emit(current_run)
```

### Web Persistence

Save format: JSON file at `user://best_records.json`

```gdscript
func _save_records() -> void:
    var data = {
        "best_wave": best_records.best_wave,
        "best_combo": best_records.best_combo,
        "total_myriad": best_records.total_myriad,
    }
    var file = FileAccess.open("user://best_records.json", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
        file.close()

func _load_records() -> void:
    if FileAccess.file_exists("user://best_records.json"):
        var file = FileAccess.open("user://best_records.json", FileAccess.READ)
        if file:
            var data = JSON.parse_string(file.get_as_text())
            if data:
                best_records.best_wave = data.get("best_wave", 0)
                best_records.best_combo = data.get("best_combo", 0)
                best_records.total_myriad = data.get("total_myriad", 0)
            file.close()
```

Web fallback: If `FileAccess` fails (browser security), use `JavaScriptBridge.eval()` to access `localStorage`:
```gdscript
func _web_save(data: Dictionary) -> void:
    JavaScriptBridge.eval('localStorage.setItem("gui_zong_records", \'%s\')' % JSON.stringify(data))

func _web_load() -> Dictionary:
    var result = JavaScriptBridge.eval('localStorage.getItem("gui_zong_records")')
    if result and result != "null":
        return JSON.parse_string(result)
    return {}
```

### State Integration

| Game State | Scoring Behaviour |
|-----------|-------------------|
| COMBAT | Active — collecting wave/combo/myriad data |
| DEATH | Finalize run, update best records, emit `run_completed` |
| RESTART | Reset per-run data to zeros |
| TITLE | Inactive — best records remain loaded |
| INTERMISSION | Continue tracking (wave data updated on wave completion) |

### Public API

```gdscript
# Current run queries
func get_current_score() -> RunData
func get_current_wave() -> int
func get_current_combo() -> int

# Best record queries
func get_best_score() -> BestRecords
func get_best_wave() -> int
func get_best_combo() -> int

# Control
func save_score() -> void
func reset_current() -> void
```

### Signals

```gdscript
signal run_completed(run_data: RunData)
signal best_record_updated(record_type: String, new_value: int)
```

### Integration Points

| System | Integration | Direction |
|--------|------------|-----------|
| Game State (ADR-0001) | Listens `state_changed` — DEATH=finalize, RESTART=reset | Consumer |
| Combo System (ADR-0009) | Listens `combo_changed`, `myriad_triggered`; reads `get_combo_count()` | Consumer |
| Arena Wave (ADR-0014) | Listens `wave_completed`; reads `get_current_wave()` | Consumer |
| HUD/UI (ADR-0015) | Provides `get_current_score()`, `get_best_score()` for game over screen | Provider |
| Skill Progression (ADR-0018) | Provides `run_completed` signal with RunData | Provider |

## Alternatives Considered

### Alternative 1: Scoring System as Autoload
- **Description**: Make ScoringSystem a global Autoload for direct access
- **Pros**: Any system can call `ScoringSystem.get_best_score()` without signal wiring
- **Cons**: Adds a 4th Autoload (exceeds 3-singleton guideline); scoring is scene-specific logic — it resets per run and tracks per-session data
- **Rejection Reason**: Violates Autoload minimization. HUD and skill progression access score data via injected reference or group lookup.

### Alternative 2: Each System Owns Its Own Persistence
- **Description**: Combo system saves best combo, wave system saves best wave, each system persists independently
- **Pros**: Decentralized — no central scoring bottleneck
- **Cons**: 3 separate save files; no unified "run" concept; cross-run analytics impossible; save file management fragmented across systems
- **Rejection Reason**: Single persistence point is simpler and enables run-level events (`run_completed`) for downstream consumers like skill progression.

### Alternative 3: ConfigFile Instead of JSON
- **Description**: Use Godot's ConfigFile for persistence instead of JSON + FileAccess
- **Pros**: Built-in section/key/value structure; simpler API
- **Cons**: ConfigFile stores as `.cfg` — less portable; JSON is more readable for debugging; ConfigFile has no Web-specific fallback mechanism
- **Rejection Reason**: JSON with FileAccess is more portable and debuggable. The localStorage fallback path is straightforward with JSON.stringify/parse.

## Consequences

### Positive

- Single source of truth for per-run metrics — HUD, skill progression, and future systems all consume from one place
- `run_completed` signal provides clean event for post-run processing (skill progression recording, analytics)
- Best records persist across sessions — "beat your best" motivation survives page refresh
- Per-run reset is trivial — one `reset_current()` call on RESTART
- JSON persistence is human-readable for debugging

### Negative

- Web FileAccess may be restricted by browser security — localStorage fallback adds code path complexity
- `total_myriad` is a cumulative counter (not a per-run best) — mixing best-record and cumulative semantics in one system
- Run duration tracked via `_process(delta)` accumulation — minor drift over long runs (acceptable for display purposes)
- No online leaderboard — records are local only

### Risks

- **FileAccess blocked on Web**: Some browser configurations restrict `user://` path access. Mitigation: `JavaScriptBridge.eval()` localStorage fallback; test on target browsers during prototype.
- **Data corruption on crash**: If game crashes mid-save, JSON file may be truncated. Mitigation: write to temp file first, then rename; or validate JSON on load with fallback to defaults.
- **Signal ordering**: If `wave_completed` fires after DEATH state transition, the final wave may not be recorded. Mitigation: Godot processes signals sequentially — all wave signals fire before state_changed(DEATH) if emitted in the same frame. Verify during prototype.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| scoring-system.md | Best record tracking (wave, combo, myriad) | `BestRecords` class with 3 fields; updated on DEATH |
| scoring-system.md | Web localStorage persistence | JSON via FileAccess with `JavaScriptBridge.eval()` fallback |
| scoring-system.md | Cross-system data collection | Signal subscriptions to `wave_completed`, `combo_changed`, `myriad_triggered` |

## Performance Implications

- **CPU**: Signal handlers + best record comparison ≈ 0.001ms/frame (negligible)
- **Memory**: RunData + BestRecords ≈ 100 bytes
- **Load Time**: JSON load from disk < 1ms
- **Network**: N/A (single-player, local persistence)

## Validation Criteria

- Per-run data resets to zeros on RESTART
- Reaching wave 10 records `best_wave = 10` in current run
- Combo interrupted at 15 records `best_combo = 15`
- 3 myriad triggers in one run records `myriad_count = 3`
- On DEATH, best records update if current run exceeds them
- `run_completed` signal emits with correct RunData
- Best records persist after page refresh (Web localStorage)
- Loading game with no save file initializes records to zeros

## Related Decisions

- ADR-0001: Game State Architecture — `state_changed` for DEATH (finalize) and RESTART (reset)
- ADR-0009: Combo System — `combo_changed`, `myriad_triggered` signals
- ADR-0014: Arena Wave — `wave_completed` signal, `get_current_wave()` query
- ADR-0015: HUD/UI — score data display on game over screen
- ADR-0018: Skill Progression — `run_completed` signal for run data recording
