# Footage log — capture session 1

Master: GitHub release `footage` asset `ScreenRecording_08-03-2026.12-18-14_1.MP4`
(213MB, 5:50, 1320×2868 HEVC 60fps, recorded 2026-08-03,
sha256 b786495d…60753b). Keep the original on the phone as the true master.

Cuts are 1080×1920 (Reels/TikTok), source scaled to full height and
pillarboxed in page bone `#E8E6E1` or ink `#161514`, audio stripped,
H.264 CRF 20. Reproduce with ffmpeg: `-ss <start> -t <len> -vf
"scale=-2:1920,pad=1080:1920:(ow-iw)/2:0:color=<hex>" -an`.

| Clip | ss | t | Pad | Content |
|---|---|---|---|---|
| writing-settle | 55 | 30 | bone | Blank Today page → entry typed live, keyboard up |
| calendar-choreography | 226.5 | 17.5 | bone | Year matrix → month → day page; dots travel (FLIP) between layouts |
| wrapped-month | 245.5 | 33 | ink | Monthly reflection: moon → dots draw → 28 days / 8,697 words / 11 run → recurring ideas → "house"/"boat"/"kind" quote cards → Reflect & start anew |
| find-type-shrink | 285.3 | 23.2 | bone | Find overlay: "Tired" typed huge, type shrinks to fit, results underline; cleared, "Nerv", "Happy" |

## Segment map of the master (5s scrub)

- 0:00–0:20 onboarding (dot-fill slide ~0:08)
- 0:25–0:45 Today + consent card + weekly reflection modal ("tired" quote ~0:35)
- 0:50–3:20 live writing session (long)
- ~3:05 ⚠ iOS Proofread/Rewrite writing-tools bar visible — never use this window
- 3:25–3:40 notebook reading + weekly "7 days / 2,551 words" card
- 3:44–4:04 calendar: year ↔ month ↔ day with dot choreography
- 4:05–4:40 monthly wrapped run
- 4:44–5:10 Find sequence
- 5:12–5:30 Settings (reminder time picker, toggles)

## Notes

- Status bar shows the red REC pill throughout — kept on purpose;
  it reads as authentic screen capture.
- On-screen text is Wendell's typed entry plus seeded demo data;
  cleared for marketing use per capture intent.
