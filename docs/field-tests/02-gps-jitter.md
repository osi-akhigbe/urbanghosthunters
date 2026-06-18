# gps jitter tests

does distance/proximity make sense outside or does it bounce around randomly

**who:** ___________  
**phone:** ___________  
**hotspot + radius:** ___________  
**spirit flash totem?** y / n (makes containment unlock earlier)

helpful: mark 3 spots with tape or just remember a tree/bench  
- **A** ~150m from hotspot (open area)  
- **B** ~50m out  
- **C** at the hotspot  

---

## test 1 — dont move for 3 minutes

stand at spot A, open scanner, literally dont move. write distance every 30 sec:

| time | meters on screen | proximity bar |
|------|------------------|---------------|
| 0:00 | | |
| 0:30 | | |
| 1:00 | | |
| 1:30 | | |
| 2:00 | | |
| 2:30 | | |
| 3:00 | | |

lowest: ___  highest: ___  difference: ___

if difference > 25m in open sky thats probably a bug. bar jumping constantly also bad.


---

## test 2 — between buildings

same thing at spot B near tall buildings. 2 min standing still.

does it get worse than test 1? y/n  
when you walk 20m does distance update within ~5 sec of stopping? y/n


---

## test 3 — under trees

~80m out under tree cover. 2 min still.

step into open sky 5m away — how long till readings calm down? ___ sec


---

## test 4 — walk toward hotspot

start scanner at A, walk to C without stopping. every ~25m write distance:

- start: ___m  
- closer: ___m  
- closer: ___m  
- closer: ___m  
- closer: ___m  
- at hotspot: ___m  

distance should mostly go down. proximity bar should fill up.

when did BEGIN CONTAINMENT turn purple? at ___m  
(with spirit flash it should unlock farther away — we think ~38m vs ~67m but verify)


---

## test 5 — anomaly banner

map tab open. walk into hotspot radius from outside.

banner show up? y/n — when? ___m-ish  
notification? y/n  
direction make sense (north/south etc)? y/n  

walk out — banner go away? y/n  
walk back in — come back? y/n (even if you dismissed it before? check)


---

## test 6 — nearest hotspot flip flop

if theres 2 hotspots nearby stand between them on map tab. dont move 2 min.

does the bottom sheet keep switching hotspots annoyingly? y/n  

walk toward one — does it pick the right one? y/n


---

## test 7 — cold start

force quit app. airplane mode 10 sec off. open app go straight to scanner.

how long till distance shows something real? ___ sec  
how long till it stops jumping around? ___ sec


---

## test 8 — containment button flicker

walk till containment button just unlocks. stand still 1 min.

does button flicker on/off? y/n — count toggles: ___  

try again with spirit flash if you have it.


---

## overall

pass / fail / kinda broken: ___________

weird stuff:

