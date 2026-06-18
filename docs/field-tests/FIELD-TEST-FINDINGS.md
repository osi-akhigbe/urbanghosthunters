# field test findings

**group:** urban ghost hunters ios team  
**last updated:** june 2026  
**status:** not fully run yet — fill this in after outdoor session

---

## session info

| | |
|---|---|
| date | |
| where we tested | |
| weather | |
| phones | |
| build | |
| who ran tests | |

---

## stuff we noticed reading code (before going outside)

didnt actually test these yet just looked at swift files:

**compass** — `ScannerViewModel` uses `magneticHeading` directly, no smoothing. reveal lens totem widens aim window to 90°. we expect wobble especially near metal.

**gps** — geofence manager has `distanceFilter = 5` but scanner takes every location update. no check for bad accuracy values. containment button tied to proximity so might flicker.

**low light** — `GhostARView` is non-AR (no camera). no torch in ui yet.

---

## compass results

| test | ok? | notes |
|------|-----|-------|
| 1 stand still | | |
| 2 figure 8 | | |
| 3 metal | | |
| 4 spin | | |
| 5 walking | | |
| 6 background | | |
| 7 optional | | |

bugs:


---

## gps results

| test | ok? | notes |
|------|-----|-------|
| 1 stand still | | jitter range: ___m |
| 2 buildings | | |
| 3 trees | | |
| 4 walk in | | containment at ___m |
| 5 banner | | |
| 6 nearest flip | | |
| 7 cold start | | |
| 8 button flicker | | |

bugs:


---

## low light results

| test | ok? | notes |
|------|-----|-------|
| A1 dusk ui | | |
| A2 ghost fade | | |
| A3 dark haptics | | |
| A4 glare | | |
| A5 containment | | |
| A6 system torch | | |
| B torch toggle | n/a | not built |

bugs:


---

## things to fix later (from code + field tests)

add as we confirm:

- [ ] smooth gps distance so meter doesnt bounce when standing still
- [ ] maybe add distanceFilter to scanner like geofence has
- [ ] filter out garbage location fixes (bad horizontalAccuracy)
- [ ] smooth compass heading or ignore noisy updates
- [ ] flashlight button + turn off on exit
- [ ] figure-8 hint if compass stuck??

---

## random notes / screenshots

(paste links or describe here)

