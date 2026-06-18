# outdoor testing notes

we need to test the app outside on real phones — simulator gps/compass is fake and useless for this.

## before you go

- install debug build from xcode (or whatever testflight build we have)
- location + notifications allowed. camera too if we add torch later
- put a hotspot near where youre testing — edit the hardcoded coords in `GeofenceManager.swift` or add one in supabase. we forgot to do this last time and wasted 20 min
- bring 2 phones if possible (different models)
- dont test while driving lol

## the docs

1. [compass drift](./01-compass-drift.md) — ~45 min
2. [gps jitter](./02-gps-jitter.md) — ~45 min  
3. [low light + flashlight](./03-low-light-flashlight.md) — do at dusk/night, ~30 min

do gps first then compass. low light last when it gets dark.

write stuff down in [findings](./FIELD-TEST-FINDINGS.md) as you go. screen record anything weird.

## what we know from reading the code (sprint 1)

- compass uses raw magnetic heading, no smoothing. prob gonna wobble
- geofence has 5m distance filter but scanner doesnt?? might jitter when standing still
- ghost is fake 3d (not camera ar). no flashlight button yet — skip torch tests for now
