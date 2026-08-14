# Endpaper — Hook Library

The living hook bank (per docs/endpaper-content-engine.md). One line per
hook, tagged. Mine new ones from: App Store reviews, r/Journaling,
r/digitalminimalism, TikTok comments on journaling content, TestFlight
feedback. Winners never die — retire status is `rested`, not deleted.

Statuses: `fresh` (untested) · `live` (posted, watching) · `winner`
(spawn same-family variants) · `rested` (worked once, cooling off) ·
`dead` (tested, didn't move).

| Hook | Angle | Audience | Format | Status |
|---|---|---|---|---|
| I typed something honest and then remembered I can't delete it | permanence | lapsed journalers | clip / face | fresh |
| This journal won't let me edit anything. That's why it works | permanence | practice crowd | clip | fresh |
| One honest sentence a day, in an app with no delete key — day 12 | permanence-challenge | creators | series | fresh |
| My journal app has no AI and that's the entire point | no-AI | digital minimalists | clip / stitch | fresh |
| The journal that doesn't want to talk to you about your feelings | no-AI | skeptics | card / clip | fresh |
| I built a journal I literally cannot read. Here's the architecture | privacy / maker | privacy crowd | face explainer | fresh |
| No account. No server. Nothing to breach | privacy | privacy crowd | card | fresh |
| July, honest version | dots | everyone | month-end still | fresh |
| Every dot is a day I actually wrote | dots | practice crowd | still / clip | fresh |
| Watch what happens when I tap a month | choreography | everyone | screen clip | fresh |
| Four abandoned journals. This one stuck because it does less | comparison | lapsed journalers | face / clip | fresh |
| I deleted my journaling app's AI and kept the journal | no-AI | minimalists | card | fresh |
| An app that behaves like paper | analog | pen-and-paper crowd | clip | fresh |
| My year in one screen — no streaks, no fire emoji, just days | dots / anti-gamification | burned-out habit trackers | still | fresh |
| It read my own words back to me and I had to sit down for a second | reflections | practice crowd | face | fresh |
| Development is a locked skill now. Distribution is the next one | maker log | build-in-public | text post | fresh |
| I shipped a bug that deleted nothing, because nothing can be deleted | maker log | build-in-public | text post | fresh |
| The one app on my phone with no red dot, no badge, no push | quiet tech | minimalists | card / clip | fresh |
| Writing that counts because it can't be taken back | permanence | practice crowd | card | fresh |
| My journal costs what one good paper notebook costs | price | fence-sitters | card | fresh |
| [quote worth keeping], shown on the page it was written on | quotes | everyone | quote-motion Reel | winner |
| Wrote this one down so it would stop following me around | quotes | everyone | quote-motion caption | live |
| Lines I can't delete — a numbered series | quotes | everyone | quote-motion Reel series | fresh |
| One quote a week, written in ink | quotes | everyone | quote-motion Reel cadence | fresh |
| One insight a week — dots that tell it, my voice over it | dots + founder | everyone | dot-motion Reel + VO, weekly | fresh |
| Hi — I'm building Endpaper. One take, like the journal | founder | everyone | face 60s | fresh |
| This video is one take because the product is one take | founder | practice crowd | face 60s | fresh |
| Five books that made me stop performing in my own journal | recs | practice crowd | list card / carousel | fresh |
| A writing exercise for the day you have nothing to say | recs | lapsed journalers | list card | fresh |
| Journaling prompts that don't ask how you feel | recs | skeptics | list card / carousel | fresh |

## Family notes

- **Permanence** is the flagship family — it produces the felt-event
  stories. Pair with real committed-text screen captures.
- **No-AI** is counter-programming; strongest as stitches/duets on
  AI-journal content, where the contrast does the work.
- **Dots** is the repeatable identity format (month-end cadence).
- **Maker log** hooks come from the actual git history and beta diary —
  never invent one.

## Pillars (logged 2026-08, Wendell voice note)

The page should be a destination for knowledge with an aesthetic people
return to — promos mixed in sparingly, not a link-out billboard. Three
pillars beyond the product families above:

1. **Quotes on the page** — interesting/worth-keeping lines shown inside
   the actual writing surface, the app as the picture frame. Sources:
   public-domain writers on attention/honesty/memory, or (with explicit
   permission) beta users' lines. Never invented "user" quotes. Renderer
   note: the day-page template can set an arbitrary entry — a
   quote-card mode is a small render-app.mjs variant when needed.
2. **Founder videos, single take** — 60 seconds, Wendell to camera,
   explicitly framed by the product rule: recorded once, mistakes kept,
   like the journal. Say the frame out loud in the video — the format IS
   the pitch. No cuts, no teleprompter polish. First one: "This is who I
   am, this is what I'm building."
3. **Recommendations** — books, writing exercises, prompt lists. List
   cards and carousels in the brand register. Give value with no ask;
   the app appears only as the page the list is written on.

Mix guide: pillars carry the page, product promos stay ≤1 in 4 posts.

## Signals

- 2026-08-10: First reach data. Pinned still post: 7 views in ~24h,
  mostly followers. Quote-motion Reel ("commit to nothing"): 66 views
  in 5 minutes, 98.4% non-followers. **Video is the distribution
  surface; stills are anchors/carousel/story material.** Reels-first
  cadence from here.
- Watch-the-metric: avg watch on the Reel opened at ~1.3s/view (83s
  over 66). RESOLVED 2026-08-11 (Wendell called it early): hang cut to
  ~0.5s, first letter +20% (252px) and on frame one — a feed scroll
  must never catch an empty page. Emphasis press rebuilt reflow-free
  (skew + stroke, not italic/weight) so the line never re-wraps
  mid-effect.
- W33 pass (2026-08-10, same-day data): quotes family promoted to
  winner on the reach signal; two same-family variants spawned (series
  framing, weekly cadence framing). Packs now include a quote video
  every week (make-pack renders it from cards/quotes.json, rotating).
  Stills recadenced to anchor/carousel/story duty. Story-frame results
  from 08-09 still pending — log when known.
- 2026-08-11 (Wendell): quote bench read as too generic — rebuilt
  around provocation (Dostoevsky, Kierkegaard, Kafka, Nietzsche tier;
  greeting-card Emerson lines cut). Target state: mine quotes from
  quote-posts that overperform their creator's baseline via Eden's
  indexed search each week; until that pass runs, Wendell may also feed
  a weekly library by hand. First comment rewritten — "I wrote this in
  the Endpaper app" (the URL-bearing version read as bot).
- 2026-08-12: first Eden mining pass ran (global corpus, outlier-ranked,
  last quarter). Four lines lifted from 5x–115x overperformers onto the
  bench (control/mind, emotions/button, ships/water, defeat is
  psychological — all posted unattributed; the Aurelius attribution on
  the last is shaky and we don't fake attributions). Validation: "You
  become what you give your attention to" — already on our bench — ran
  6.7x on Daily Stoic; schedule it soon. Repeatable Friday step now.

## Cadence & pipeline (2026-08-10)

- **LIVE (2026-08-12)**: approved and on the store —
  https://apps.apple.com/app/endpaper-journal-in-ink/id6795154721.
  Site badges wired. Launch post gated on the listing showing "Get"
  (price was misconfigured $39.99 → corrected to free; propagation
  up to a few hours). Founding offer code: FOUNDING / free / 1 yr /
  30 redemptions — create in ASC before the launch post goes out.

- **2x/day**: morning slot 07:05 (the "Thought of…" light quote Reel —
  the daily franchise) and evening slot 21:45 (app clips, cards, dark
  quote when nothing else fits). Europe/Helsinki. More signal > polish
  while the account is cold; revisit if the second slot underperforms.
- **Eden connected**: scheduling and first comments now run from the
  session (workspace "hello's workspace", IG @endpaper.space; LinkedIn
  present but never targeted without an explicit ask). Friday passes
  can pull analytics directly.
- **Daily kit run (from 2026-08-12)**: automated routine fires at
  06:00 Helsinki every morning and delivers both day-kits to the chat
  (light for the ~7am slot, dark for the evening), rendered dated to
  the day, standard format: mp4 → bare caption → bare comment. Wendell
  posts in-app with catalog audio. Eden queue stays empty by default.
- **First comment (from 2026-08-11)**: "I wrote this in the Endpaper
  app" — no URL, no dash-speak.
- **Music (from 2026-08-11)**: quote Reels get Instagram catalog
  audio — neoclassical register (Jóhannsson / Alcocer / Hisaishi /
  Pamart / Richter). Catalog tracks attach only in-app (Meta's API has
  no music parameter), so music Reels are posted by Wendell from a
  prep kit delivered the night before: silent video + caption + first
  comment, paste-ready. Eden scheduling is the fallback for missed
  slots (silent > skipped). render-quote.mjs can also mux a local
  track from tools/content/music/ (arg 6) — dormant unless licensed
  files ever land there.

## Live log

| Date | Platform | Asset / format | Hook / role | Notes |
|---|---|---|---|---|
| 2026-08-09 | IG + Threads | rule-permanence-feed-light | Intro announcement (pinned anchor, not a test) | Founding-thirty offer included; app in review |
| 2026-08-09 | IG story | rule-no-ai-story-dark + link sticker (/ig) | no-AI angle | "launching this week" overlay |
| 2026-08-09 | IG story | rule-open-write-close-story-light + poll | permanence question | Poll: "Could you keep a journal you can't edit?" |
| 2026-08-10 | IG Reel | quote-motion "commit to nothing" | quotes pillar, video format test | 66 views / 5 min, 98.4% non-followers — early winner on reach |
| 2026-08-10 | IG Reel (scheduled 21:51 EEST via Eden) | quote-motion Marcus Aurelius dark | quotes franchise, first machine-scheduled post | caption "Thought of Monday, Aug 10th at 9:51pm", first comment auto |
| 2026-08-11 | IG Reel (scheduled 07:08 EEST via Eden) | quote-motion Seneca "everywhere is *nowhere*" light | morning franchise slot 1, first emphasis-press post live | 14.7s runtime (short — watch-time test), caption "Thought of Tuesday, Aug 11th at 7:08am", first comment auto. Renderer takes a date arg now — render the night before, dated to posting day |
| 2026-08-11 | IG Reel (manual, midday) | quote-motion Seneca "imagination / *reality*" light | replaces the 07:08 post — v4 template debut (frame-one letter, 0.5s hang, no-reflow press) + catalog audio | caption "Thought of Tuesday, Aug 11th at 7:18am" |
| 2026-08-11 | IG Reel (manual, ~21:15) | quote-motion Dostoevsky "own way" dark | evening slot, first prep-kit post with catalog audio + human first comment | caption "Thought of Tuesday, Aug 11th at 9:15pm" |
| 2026-08-12 | IG Reel (manual, ~7:11) | quote-motion "needing an *audience*" light | morning slot — first Wendell-mined line live | caption "Thought of Wednesday, Aug 12th at 7:11am", catalog audio, first daily-kit-routine delivery |
| 2026-08-12 | IG Reel (manual, ~21:37) | quote-motion "comfort for *suffering*" dark | evening slot — Wendell-mined line | caption "Thought of Wednesday, Aug 12th at 9:37pm", catalog audio |
| 2026-08-13 | IG Reel (manual, ~7:00 or after launch post) | quote-motion "take the *risk*" light | morning slot — LAUNCH DAY; launch Reel takes priority if listing shows Get | caption "Thought of Thursday, Aug 13th at 6:50am", catalog audio |
| 2026-08-13 | IG Reel (manual, ~21:30) | quote-motion Epictetus "*attention*" dark | evening slot — Eden-validated line pulled forward (6.7x on Daily Stoic) | caption "From Epictetus - Thought of Thursday, Aug 13th at 9:30pm", catalog audio |
| 2026-08-14 | IG Reel (manual, ~7:27) | quote-motion "universe / *more*" light | morning slot — the off-voice manifestation test (kept deliberately: if it outruns the stoic lines, that's audience signal) | caption "Thought of Friday, Aug 14th at 7:27am", catalog audio |
| 2026-08-14 | IG Reel (manual, ~21:22) | quote-motion "ruthless with *access*" dark | evening slot — Wendell-mined line | caption "Thought of Friday, Aug 14th at 9:22pm", catalog audio |
