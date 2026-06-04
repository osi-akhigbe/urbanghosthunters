# Sprint tasks (OA) — implementation checklist

## Before demo
1. Run `docs/supabase-demo-setup.sql` in Supabase SQL Editor
2. Run `docs/supabase-sprint2.sql` (totems + inventory)
3. Confirm `ios/urbanghosthunters/Secrets.plist` has URL + anon key
4. Simulator location near a hotspot (e.g. 52.3676, 4.9041)

## APPDEV-24 — Encounter journal (list + detail)
- **Done in app**: Journal tab lists encounters from Supabase with hotspot name, XP, totem
- **Detail**: Tap row → encounter detail with outcome, rewards, replay button
- **Demo**: Journal → tap latest capture → see detail → Replay hunt

## APPDEV-32 — Mic lure
- **Done in app**: Scanner → hold **HOLD TO LURE** → Ghost Reveal meter fills (mic amplitude or simulated)
- **Demo**: Hold button until reveal bar fills → Begin containment unlocks

## APPDEV-33 — Disturbance attacks + shield
- **Done in app**: Containment shows shield meter; periodic QTE overlay (tap); shake drains shield
- **Demo**: During seal, tap red QTE overlays; watch shield drop if missed

## Hotspot difficulty scaling
- **Done in app**: Difficulty 1/2/3 changes timer, seal points, close distance, attack rate, shield
- **Demo**: Hunt **Hard Haunt** (difficulty 3) vs **Demo Haunt** (difficulty 1)

## APPDEV-37 — Sprint 2 end-to-end demo
Flow: **Map → Scanner (lure) → Contain → Result (totem) → Journal → Loadout (equip) → Replay**

| Step | Screen | Action |
|------|--------|--------|
| 1 | Auth | Continue as Guest |
| 2 | Map | Open hotspot |
| 3 | Scanner | Hold lure OR get close → Begin containment |
| 4 | Containment | Draw seal, block QTEs, SEAL |
| 5 | Result | See XP + Spirit Ward earned |
| 6 | Journal | Open encounter detail |
| 7 | Loadout | Equip Spirit Ward |
| 8 | Journal detail | Replay hunt at this haunt |

## Mark Jira done when
- [ ] SQL scripts run without errors
- [ ] App builds and runs on simulator
- [ ] Full flow above works once on your machine
- [ ] Screenshot or short screen recording for team demo
