# Field Test 04 — NFC Totem Scan

**Date:** 2026-06-20  
**Feature:** CoreNFC tag reading mapped to Supabase `nfc_tags` table  
**Branch:** `feature/APPDEV-53-flashlight-toggle`

---

## Objective

Verify that a physical NFC tag placed near the device:
1. Is detected and its UID extracted correctly
2. Is resolved against the `nfc_tags` Supabase table
3. Displays the totem name and effect on a successful match
4. Shows a graceful "unknown tag" state for unregistered UIDs
5. Shows clear error states for device unavailability or connection failures

---

## Setup

- Device: iPhone 15 or newer (CoreNFC is unavailable on the simulator)
- NFC tags: ISO 14443-A NTAG213/215 stickers — 1x registered in Supabase, 1x unregistered
- Supabase: `nfc_tags` table seeded from `docs/supabase-nfc.sql`

---

## Test Cases

| # | Scenario | Expected Result |
|---|----------|-----------------|
| 1 | Tap registered NTAG213 | Sheet shows totem name + effect, green signal icon |
| 2 | Tap unregistered tag | "UNKNOWN TAG" with UID displayed, "TRY AGAIN" button |
| 3 | Cancel iOS NFC sheet | State silently returns to idle |
| 4 | No tag present (timeout) | "SCAN ERROR" with CoreNFC timeout message |
| 5 | Run on iPad without NFC | "NFC UNAVAILABLE" shown immediately on tap |
| 6 | Offline / airplane mode | Tag UID read succeeds; Supabase lookup shows "Lookup failed" error |

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

---

## Notes

- UID stored as uppercase hex, no separators (e.g. `04ABCDEF123456`)
- All four tag families supported: ISO 7816, ISO 15693, FeliCa, MIFARE
- Session alert message updates to "Tag read. Looking up totem…" immediately after UID extraction, giving feedback before the Supabase round-trip completes
