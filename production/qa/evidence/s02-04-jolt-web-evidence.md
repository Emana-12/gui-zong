# S02-04: Jolt Web Export Verification -- Evidence

**Date**: 2026-04-22
**Task**: S02-04 Jolt Web Export Verification
**Sprint**: 02
**Status**: IN PROGRESS

## Verification Scope

Per QA Plan and Sprint Plan:
- Web export builds successfully from Godot 4.6.2
- Jolt physics engine is active in the exported build (not Godot default)
- Floor collision: object rests on static floor without falling through
- Wall collision: object bounces off static wall correctly
- Dynamic body collision: two objects collide and respond with correct momentum

## Export Configuration

- **Engine**: Godot 4.6.2 stable
- **Physics**: Jolt Physics (configured in project.godot)
- **Target**: HTML5 / Web
- **Renderer**: WebGL 2.0 (auto-downgrade from Forward+)
- **Export Presets**: Created at `src/export_presets.cfg`

## Build Verification

### Export Presets Configuration

| Setting | Value | Verified |
|---------|-------|----------|
| Export preset exists | `Web` in `export_presets.cfg` | [x] |
| Platform | HTML5 | [x] |
| Export path | `builds/web/index.html` | [x] |
| Variant | Standard | [x] |
| Texture format | S3TC + ETC2 | [x] |
| Progressive Web App | Disabled (simplified) | [x] |

### Web Export Build Steps

1. Open project in Godot 4.6.2
2. Project → Export → Select "Web" preset
3. Click "Export Project"
4. Export to `builds/web/index.html`
5. Serve via local HTTP server with COOP/COEP headers:
   ```powershell
   # Requires Python or Node.js HTTP server with headers
   # Chrome: launch with --enable-features=SharedArrayBuffer
   # Or serve with correct headers for cross-origin isolation
   ```

### COOP/COEP Headers Required

Web platform requires Cross-Origin headers for SharedArrayBuffer (needed by Jolt multi-threading):

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

**Local verification**: Use Chrome with `--enable-features=SharedArrayBuffer` flag, or serve with a local server that sets these headers.

## Collision Test Scenarios

### Test Scene: `collision_test_web.tscn`

Created at `src/tests/collision_test_web.tscn` with companion script `src/tests/collision_test_web.gd`.

**Scene layout**:
- Static floor: `StaticBody3D` with `CollisionShape3D` (BoxShape3D, 10x0.1x10)
- Static wall: `StaticBody3D` with `CollisionShape3D` (BoxShape3D, 0.1x3x10)
- Test sphere 1: `RigidBody3D` with `CollisionShape3D` (SphereShape3D, r=0.5)
- Test sphere 2: `RigidBody3D` with `CollisionShape3D` (SphereShape3D, r=0.5)
- Camera: `Camera3D` positioned to view all test objects
- UI: Labels showing collision state

### Scenario 1: Floor Collision

**Setup**: Drop a sphere from height 5 onto static floor.
**Expected**: Sphere lands on floor and comes to rest (no falling through).
**Verification**:
- [ ] Sphere Y-position stabilizes above floor (y > 0)
- [ ] No jitter or oscillation after settling
- [ ] Frame time stays within 16.6ms budget during physics settle

### Scenario 2: Wall Collision

**Setup**: Launch sphere horizontally toward static wall.
**Expected**: Sphere bounces off wall (velocity reverses in collision axis).
**Verification**:
- [ ] Sphere X/Z-position stops at wall boundary
- [ ] Velocity magnitude preserved (elastic collision or friction damping)
- [ ] No tunneling through wall at launch speed

### Scenario 3: Dynamic Body Collision

**Setup**: Two spheres launched toward each other at equal speed.
**Expected**: Spheres collide and exchange momentum (equal mass = velocity swap).
**Verification**:
- [ ] Both spheres change direction after collision
- [ ] No overlap or penetration at collision point
- [ ] Total momentum approximately conserved

## Local Verification (Desktop)

Since Web export requires a running HTTP server with specific headers, local desktop testing verifies:

- [x] Export preset configured correctly
- [ ] Project exports without errors (requires Godot editor)
- [ ] Collision test scene runs correctly in desktop build (baseline behavior)
- [ ] Jolt physics confirmed active via project.godot setting

### Desktop Physics Verification

**project.godot confirms**:
```ini
[physics]
3d/physics_engine="Jolt Physics"
```

This means ALL exports (including Web) use Jolt physics. The only risk is whether Jolt's Web build (wasm) behaves identically to the desktop build.

## Edge Cases

| Edge Case | Status | Notes |
|-----------|--------|-------|
| Export template missing | PENDING | Requires Godot editor with HTML5 export template installed |
| Jolt not default on Web | VERIFIED | project.godot explicitly sets Jolt — applies to all platforms |
| COOP/COEP headers | DOCUMENTED | Requires server config or Chrome flag for local testing |

## Web Export Performance Considerations

Per ADR-0005 (HIGH risk):
- Jolt on Web compiles to WebAssembly — performance may differ from native
- SharedArrayBuffer requires COOP/COEP headers (server config)
- Fallback roadmap: Jolt → Godot built-in physics → simplified collision → pure raycast
- MAX_HITBOXES=18 should be achievable on Web (pool-based, zero-alloc hot path)

## Evidence Summary

| Check | Local | Web Export | Status |
|-------|-------|------------|--------|
| Export preset configured | [x] | N/A | DONE |
| Jolt physics active | [x] | [ ] | LOCAL VERIFIED |
| Floor collision | [ ] | [ ] | PENDING (needs editor) |
| Wall collision | [ ] | [ ] | PENDING (needs editor) |
| Dynamic body collision | [ ] | [ ] | PENDING (needs editor) |
| COOP/COEP config | [x] | [ ] | DOCUMENTED |

## Acceptance Criteria

- [x] Export preset exists and configured for Web/HTML5
- [x] Jolt physics confirmed as project default
- [x] Collision test scene created
- [ ] Floor collision verified — PENDING (requires Godot editor build test)
- [ ] Wall collision verified — PENDING (requires Godot editor build test)
- [ ] Dynamic body collision verified — PENDING (requires Godot editor build test)
- [x] COOP/COEP requirements documented
- [x] Edge cases documented

## Notes

- Web export verification requires actual Godot editor to run the export — cannot be fully automated via code alone
- Collision test scene provides a baseline for local desktop testing before Web export
- Jolt is confirmed as project-wide physics engine, so Web export will use Jolt unless explicitly overridden
- The test scene can be opened directly in Godot editor for visual verification
- Performance on Web will need actual profiling in S02-03 (Performance Baseline)

## Sign-off

- [ ] Desktop collision test pass — requires Godot editor
- [ ] Web export build pass — requires Godot editor + HTML5 export template
- [ ] Web collision verification — requires serving build with COOP/COEP headers
- Verdict: **LOCAL CONFIGURATION COMPLETE — AWAITING EDITOR VERIFICATION**
