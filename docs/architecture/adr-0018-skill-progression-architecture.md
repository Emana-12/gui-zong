# ADR-0018: Skill Progression Architecture

## Status
Accepted

## Date
2026-04-21

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 stable |
| **Domain** | Core |
| **Knowledge Risk** | LOW — FileAccess, JSON, Array, and signal APIs are core, unchanged since Godot 4.0 |
| **References Consulted** | `docs/engine-reference/godot/modules/file-io.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Array serialization to JSON on Web (HTML5); trend data computation cost with 10-entry history |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009 (combo system — combo count data, myriad trigger count), ADR-0010 (player controller — dodge event data), ADR-0017 (scoring system — `run_completed` signal with RunData) |
| **Enables** | HUD progression display (trend data for post-run screen) |
| **Blocks** | None — skill progression is a leaf system |
| **Ordering Note** | ADR-0017 must be Accepted before implementation (provides `run_completed` signal); dodge event data from ADR-0010 must be formalized (currently no explicit `dodged` signal in ADR-0010 — may need supplement) |

## Context

### Problem Statement

归宗's Pillar 3 is "玩家即进度" — the player IS the progression. There are no permanent upgrades, no stat increases, no unlocks. Skill progression makes this tangible by tracking 3 operation metrics across runs and showing trend data: "your average combo went from 5 to 8 over the last 10 runs." Without this system, the "no-numerical-growth" philosophy has no visible payoff — players can't see their own improvement.

### Constraints

- Web (HTML5) target — persistence uses FileAccess (with JavaScript localStorage fallback, same pattern as ADR-0017)
- No gameplay impact — purely informational display
- 3 tracked metrics: average combo length, dodge success rate, myriad frequency
- Trend data: last 10 runs only (rolling window)
- Data collected from scoring system's `run_completed` signal
- Must not duplicate scoring system's persistence logic — share the save pattern

### Requirements

- TR-SKL-001: Operation metrics tracking — average combo, dodge success rate, myriad frequency
- TR-SKL-002: Trend data — rolling window of last 10 runs per metric
- TR-SKL-003: Cross-system data collection — gather metrics from gameplay systems
- TR-SKL-004: Web persistence — survive page refresh

## Decision

### Architecture

The Skill Progression system is a `Node` scene node (`SkillProgression.tscn`) that records per-run operation metrics and maintains a rolling trend history. It is NOT an Autoload — it lives in the main scene tree. It subscribes to the scoring system's `run_completed` signal for run data, and reads additional metrics (dodge events) from the player controller. Trend data persists to JSON via FileAccess with Web fallback.

### Data Model

```gdscript
class_name RunMetrics

var avg_combo: float = 0.0        # total_combo_hits / combo_breaks
var dodge_success_rate: float = 0.0  # successful_dodges / total_dodge_attempts
var myriad_frequency: float = 0.0   # myriad_count / run_duration_minutes

class_name TrendHistory

var combo_trend: Array[float] = []      # last 10 avg_combo values
var dodge_trend: Array[float] = []      # last 10 dodge_success_rate values
var myriad_trend: Array[float] = []     # last 10 myriad_frequency values
```

### Metric Collection

Metrics are computed from the scoring system's `RunData` and additional player controller data:

```gdscript
func _on_run_completed(run_data: RunData) -> void:
    var metrics = RunMetrics.new()

    # Average combo: best_combo is the peak, approximate avg as peak * 0.6
    # (accurate avg would need per-combo-break tracking — deferred to v2)
    metrics.avg_combo = run_data.best_combo * 0.6

    # Myriad frequency: myriad_count / (run_duration / 60.0)
    if run_data.run_duration > 0:
        metrics.myriad_frequency = run_data.myriad_count / (run_data.run_duration / 60.0)

    # Dodge success rate: from player controller (if available)
    metrics.dodge_success_rate = _get_dodge_rate_from_player()

    _record_metrics(metrics)
```

Dodge data collection from player controller:
```gdscript
func _get_dodge_rate_from_player() -> float:
    var player = get_tree().get_first_node_in_group("player")
    if player and player.has_method("get_dodge_success_rate"):
        return player.get_dodge_success_rate()
    return 0.0
```

### Trend Management

Rolling window of last 10 runs:
```gdscript
const MAX_TREND_SIZE: int = 10

func _record_metrics(metrics: RunMetrics) -> void:
    trend.combo_trend.append(metrics.avg_combo)
    trend.dodge_trend.append(metrics.dodge_success_rate)
    trend.myriad_trend.append(metrics.myriad_frequency)

    # Trim to last N
    while trend.combo_trend.size() > MAX_TREND_SIZE:
        trend.combo_trend.pop_front()
    while trend.dodge_trend.size() > MAX_TREND_SIZE:
        trend.dodge_trend.pop_front()
    while trend.myriad_trend.size() > MAX_TREND_SIZE:
        trend.myriad_trend.pop_front()

    _save_trend()
```

### Historical Averages

```gdscript
func get_average_combo() -> float:
    if trend.combo_trend.is_empty():
        return 0.0
    var sum = 0.0
    for v in trend.combo_trend:
        sum += v
    return sum / trend.combo_trend.size()

func get_dodge_success_rate() -> float:
    if trend.dodge_trend.is_empty():
        return 0.0
    var sum = 0.0
    for v in trend.dodge_trend:
        sum += v
    return sum / trend.dodge_trend.size()

func get_myriad_frequency() -> float:
    if trend.myriad_trend.is_empty():
        return 0.0
    var sum = 0.0
    for v in trend.myriad_trend:
        sum += v
    return sum / trend.myriad_trend.size()
```

### Trend Direction

```gdscript
func get_trend_direction(metric: String) -> int:
    # Returns: 1 (improving), 0 (stable), -1 (declining)
    var arr = _get_trend_array(metric)
    if arr.size() < 2:
        return 0
    var recent_avg = _avg(arr.slice(-3))   # last 3 runs
    var older_avg = _avg(arr.slice(0, max(1, arr.size() - 3)))
    if recent_avg > older_avg * 1.05:      # 5% improvement threshold
        return 1
    elif recent_avg < older_avg * 0.95:
        return -1
    return 0
```

### Web Persistence

Same pattern as ADR-0017 — JSON via FileAccess with localStorage fallback:

```gdscript
func _save_trend() -> void:
    var data = {
        "combo_trend": trend.combo_trend,
        "dodge_trend": trend.dodge_trend,
        "myriad_trend": trend.myriad_trend,
    }
    var file = FileAccess.open("user://skill_progression.json", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
        file.close()

func _load_trend() -> void:
    if FileAccess.file_exists("user://skill_progression.json"):
        var file = FileAccess.open("user://skill_progression.json", FileAccess.READ)
        if file:
            var data = JSON.parse_string(file.get_as_text())
            if data:
                trend.combo_trend = data.get("combo_trend", [])
                trend.dodge_trend = data.get("dodge_trend", [])
                trend.myriad_trend = data.get("myriad_trend", [])
            file.close()
```

### State Integration

| Game State | Skill Progression Behaviour |
|-----------|---------------------------|
| COMBAT | Inactive (data collected post-run) |
| DEATH | Receive `run_completed`, compute metrics, update trends |
| RESTART | Ready for next run |
| TITLE | Display trend data if available |
| INTERMISSION | Inactive |

### Public API

```gdscript
# Historical averages
func get_average_combo() -> float
func get_dodge_success_rate() -> float
func get_myriad_frequency() -> float

# Trend data for UI display
func get_trend(metric: String) -> Array[float]  # "avg_combo", "dodge_rate", "myriad_freq"
func get_trend_direction(metric: String) -> int  # 1=improving, 0=stable, -1=declining

# Recording (called via signal, not directly)
func record_run(run_data: RunData) -> void
```

### Signals

```gdscript
signal metrics_updated(metrics: RunMetrics)
signal trend_updated(metric: String, trend: Array[float])
```

### Integration Points

| System | Integration | Direction |
|--------|------------|-----------|
| Scoring System (ADR-0017) | Listens `run_completed(run_data)` for run data | Consumer |
| Combo System (ADR-0009) | Indirect — combo data comes via scoring system's RunData | Consumer |
| Player Controller (ADR-0010) | Reads `get_dodge_success_rate()` for dodge metric | Consumer |
| HUD/UI (ADR-0015) | Provides `get_trend()`, `get_trend_direction()` for progression display | Provider |

## Alternatives Considered

### Alternative 1: Skill Progression as Part of Scoring System
- **Description**: Merge trend tracking into ADR-0017's scoring system
- **Pros**: One fewer system; shared persistence logic
- **Cons**: Scoring system owns "what happened this run" — skill progression owns "how am I improving over time." These are distinct concerns. Merging creates a monolith that handles both per-run and cross-run analytics. Scoring system's `run_completed` event is the clean boundary.
- **Rejection Reason**: Separation of concerns. Scoring answers "how did I do?" — progression answers "am I getting better?" Different consumers, different data shapes, different display contexts.

### Alternative 2: Track Per-Combo-Break for Accurate Average
- **Description**: Record every combo break event to compute exact average combo length
- **Pros**: More accurate than `best_combo * 0.6` approximation
- **Cons**: Requires combo system to emit a per-break signal (currently only `combo_changed`); significantly more data per run; Web storage grows faster
- **Rejection Reason**: The `best_combo * 0.6` approximation is sufficient for trend direction (improving/declining). Accurate per-break tracking can be added in v2 if players request more precision.

### Alternative 3: IndexedDB for Web Persistence
- **Description**: Use JavaScript IndexedDB instead of FileAccess/localStorage for richer data storage
- **Pros**: Larger storage quota; async operations; structured queries
- **Cons**: IndexedDB API is asynchronous (requires JavaScriptBridge callback chains); overkill for 3 arrays of 10 floats each; adds significant complexity for minimal benefit
- **Rejection Reason**: localStorage quota (5MB) is more than sufficient for trend data (< 1KB). IndexedDB complexity is unjustified.

## Consequences

### Positive

- Pure-informational design aligns with Pillar 3 ("玩家即进度") — no gameplay impact
- Rolling 10-run window shows recent improvement without overwhelming history
- Trend direction indicator (improving/stable/declining) gives instant feedback without reading numbers
- `run_completed` signal from scoring system provides clean data boundary — no direct coupling to gameplay systems
- Shared persistence pattern with ADR-0017 (JSON + localStorage fallback) — consistent codebase

### Negative

- `best_combo * 0.6` is an approximation for average combo — not precise
- Dodge success rate depends on ADR-0010 exposing `get_dodge_success_rate()` — currently not formalized in ADR-0010's API (may need supplement)
- Trend data loses all history on Web localStorage clear — player must rebuild from scratch
- No visual representation specified yet — trend data is raw numbers until HUD designs the progression screen

### Risks

- **Dodge metric unavailable**: If ADR-0010 doesn't provide dodge success rate, this metric defaults to 0.0 and the progression display shows a dead metric. Mitigation: formalize `get_dodge_success_rate()` in ADR-0010 before implementing; or display "N/A" when data is unavailable.
- **Approximation inaccuracy**: `best_combo * 0.6` may not match actual average — if a player gets one lucky 20-combo but averages 5, the approximation shows 12 instead of ~5. Mitigation: consider per-break tracking in v2; for MVP, the trend direction (improving/declining) is still valid even if absolute values are off.
- **Web storage limit**: localStorage 5MB is sufficient, but if other systems also use localStorage, quota may be shared. Mitigation: use a single localStorage key with combined JSON (merge scoring + progression data).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| skill-progression.md | Operation metrics tracking (combo, dodge, myriad) | `RunMetrics` class with 3 fields; computed from `run_completed` data |
| skill-progression.md | Trend data (last 10 runs) | Rolling window arrays with `MAX_TREND_SIZE = 10` |
| skill-progression.md | Cross-system data collection | `run_completed` signal from ADR-0017 + player controller dodge queries |
| skill-progression.md | Web persistence | JSON via FileAccess with `JavaScriptBridge.eval()` localStorage fallback |

## Performance Implications

- **CPU**: Metric computation + trend append ≈ 0.001ms/frame (only runs on DEATH, not per-frame)
- **Memory**: Trend arrays (3 × 10 floats) ≈ 120 bytes
- **Load Time**: JSON load < 1ms
- **Network**: N/A (single-player, local persistence)

## Validation Criteria

- After 5 runs, `get_trend("avg_combo")` returns an array of 5 floats
- After 10+ runs, trend array caps at 10 entries (oldest removed)
- `get_trend_direction("avg_combo")` returns 1 when recent runs are better than older runs
- `get_myriad_frequency()` returns 0.0 when never triggered
- Trend data persists after page refresh (Web localStorage)
- `metrics_updated` signal emits on each `run_completed`
- Loading game with no save data initializes all trends to empty arrays
- Dodge success rate shows 0.0 when player controller doesn't provide dodge data

## Related Decisions

- ADR-0009: Combo System — combo count data source (indirect via scoring system)
- ADR-0010: Player Controller — dodge success rate data (may need API supplement)
- ADR-0017: Scoring System — `run_completed` signal with RunData
- ADR-0015: HUD/UI — trend display on progression screen
