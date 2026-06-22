# Field Test 05 — Flashlight Toggle

**Date:** 2026-06-21  
**Feature:** AVCaptureDevice torch toggle in ScannerView with ambient light awareness  
**Branch:** `feature/APPDEV-53-flashlight-toggle`

---

## Objective

Verify that the flashlight button in ScannerView:
1. Appears only when the device has a torch (hides on devices without one)
2. Toggles the torch on and off correctly
3. Turns off automatically when leaving ScannerView
4. Pulses as a hint when ambient light is detected as low
5. Does not interfere with audio static, haptics, or mic lure

---

## Setup

- Device: iPhone with rear torch (any iPhone 6+)
- Test device without torch: iPad or iPhone simulator (button should not render)
- Scanner screen: navigate to any hotspot and enter ScannerView

---

## Test Cases

| # | Scenario | Expected Result |
|---|----------|-----------------|
| 1 | Open ScannerView on torch-capable iPhone | Flashlight icon appears in top-right toolbar |
| 2 | Open ScannerView on device without torch | No flashlight button rendered at all |
| 3 | Tap flashlight button (off → on) | Torch activates, icon turns yellow |
| 4 | Tap flashlight button (on → off) | Torch deactivates, icon returns to accent colour |
| 5 | Exit ScannerView while torch is on | Torch turns off automatically |
| 6 | Screen brightness below 30% (auto-brightness in dark room) | Button icon pulses as a low-light hint |
| 7 | Flashlight on during mic lure | Audio and lure work normally, no interference |
| 8 | Flashlight on during containment entry | Torch turns off when ScannerView disappears |

---

## Results

| # | Pass/Fail | Notes |
|---|-----------|-------|
| 1 | | |
| 2 | | |
| 3 | | |
| 4 | | |
| 5 | | |
| 6 | | |
| 7 | | |
| 8 | | |

---

## Notes

- `FlashlightManager` calls `AVCaptureDevice.default(for: .video)?.hasTorch` to gate availability
- `AmbientLightMonitor` watches `UIScreen.brightnessDidChangeNotification`; threshold is 0.3 (30% brightness)
- Torch is always turned off in `ScannerView.onDisappear` regardless of state
