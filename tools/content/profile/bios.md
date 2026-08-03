# Endpaper — account kit

Handles, bios, and setup notes. Assets come from `render-profile.mjs`
(avatar 1000×1000, X banner 1500×500, YouTube banner 2560×1440, light + dark).
Use the light avatar everywhere — it reads at 40px and matches the paper.

## Handle

Try in this order, and use the SAME handle on every platform:

1. `endpaper`
2. `endpaper.space` (IG/TikTok allow dots) / `endpaperspace` (X, YouTube)
3. `endpaperapp`

Display name is always just **Endpaper**. Never "Endpaper | AI-free journal"
— the display name is not a billboard.

## Bios

Link is `endpaper.space` everywhere a link is allowed. No linktree.

**TikTok** (80 chars)
> A journal written in ink. No editing, no deleting, no AI. endpaper.space

**Instagram** (150 chars)
> A journal written in ink.
> No editing. No deleting. No AI reading your diary.
> Made by one person, slowly.

**Threads** — inherits from IG.

**X** (160 chars)
> Building Endpaper — a journal written in ink. No editing, no deleting,
> no AI. Maker log, shipped in public.

**YouTube**
> Endpaper is a journal written in ink — what you write can't be edited
> or deleted. This channel is the maker log: building it in public, one
> person, slowly. endpaper.space

## Per-platform setup notes

- **TikTok** — Personal/creator account, NOT business (business accounts
  lose most licensed sounds, which kills stitches and trends). Clickable
  bio link unlocks at 1k followers; until then the domain sits in the bio
  as text — fine.
- **Instagram** — switch to Creator (free, unlocks insights + drafts).
  Creating IG auto-offers Threads; take the same handle.
- **X** — no dots in handles. Turn off "boost your posts" upsells; ignore
  Premium until there's traction worth amplifying.
- **YouTube** — claim the handle even if Shorts wait a few weeks; handles
  are first-come. Banner safe area is the middle strip — the render
  already centers content for it.
- **Pinterest** — claim the handle, post nothing yet. The aesthetic will
  do well there later with zero extra work (rule cards repin themselves).

## Ops

- One dedicated email for all five accounts. `hello@endpaper.space`
  (forwarding to the personal inbox) beats a personal address — clean
  recovery, clean handoff, and platforms can't cross-link your personal
  graph. Any registrar/Cloudflare does forwarding free.
- Password manager entries + 2FA (authenticator app, not SMS) on day one.
  A five-account brand with one password is one phish from gone.
- Do not fill in birthday/phone-book sync/contact-import prompts.

## Attribution

Bio links only allow one URL, so track per-platform with redirect paths:
`endpaper.space/tt`, `/ig`, `/x`, `/yt` → all redirect to `/` with a
`?ref=` param the site can log. (Netlify `_redirects`, four lines.)
Not perfect attribution, but enough to see which platform moves.

## Warm-up (before first post)

New accounts post into a void; seed the algorithm first.

- Days 1–3: no posting. On TikTok/IG, follow and genuinely browse the
  niches Endpaper lives in — journaling, stationery, slow tech,
  buildinpublic, digital minimalism. Like/save what's actually good.
  This teaches the FYP who your neighbors are.
- Complete every profile fully (avatar, banner, bio, link) BEFORE the
  first post — early viewers who tap through to a bare profile don't
  come back.
- First post on each platform: not a hook experiment — the plain
  introduction ("I'm building a journal you can't edit. Here's why.").
  It anchors the profile; pin it. Testing rotation starts with post #2.
