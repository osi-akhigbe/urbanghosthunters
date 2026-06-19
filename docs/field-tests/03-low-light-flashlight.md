# low light + flashlight

night testing for scanner readability and ghost visibility.

**note:** right now theres NO flashlight button in the app and the ghost isnt using the camera — its just a 3d model overlay. part B is for later when someone adds torch.

**who:** ___________  
**phone:** ___________  
**when:** dusk / full dark  
**brightness setting:** ___% auto on/off  

do tests A1-A4 around sunset. A5-A6 when its actually dark.

---

## part A — what works today

### A1 — can you read the ui at dusk?

scanner open ~30m from hotspot as sun goes down.

can you read without squinting?
- distance number: y/n
- heading degrees: y/n  
- proximity bar: y/n
- buttons: y/n

notes:


### A2 — when does ghost show up

walk toward hotspot at dusk. when do you first notice the ghost? at roughly ___m

does it fade in smooth or pop in suddenly?

| how close (rough) | can you see ghost? | 1-5 how clear |
|-------------------|--------------------|---------------|
| far | | |
| medium | | |
| close | | |


### A3 — full dark, screen only

unlit area. no streetlight on phone. can you play for 2 min?

ui readable? y/n  
haptics help you tell when aligned? y/n  
rating 1-5: ___


### A4 — streetlight glare

shine streetlight/car light on screen.

anything become unreadable? ___________


### A5 — containment at night

do containment minigame in the dark. can you see your purple draw line? y/n  
timer readable? y/n


### A6 — system flashlight (control center)

toggle iphone flashlight while scanner open.

app crash? y/n  
does it help see ghost? (prob not) ___________


---

## part B — in-app torch (NOT BUILT YET)

skip this whole section unless we added a flashlight button.

when we do add it test:
- default off when entering scanner
- tap on/off works, led matches
- torch turns off when you exit scanner (important!! dont drain battery)
- rapid tapping doesnt crash
- low battery behavior

todo for whoever implements: use AVCaptureDevice torch, turn off in onDisappear


---

## overall

part A: pass / fail / ___________  
part B: n/a  

notes for group chat:

