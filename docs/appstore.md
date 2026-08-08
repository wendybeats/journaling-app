# App Store listing — Endpaper

Everything App Store Connect asks for, in submission order. Screenshots
come from `tools/content/render-appstore.mjs` — six shots, rendered at
all three accepted portrait sizes. The upload slot names the size it
wants (Wendell's record shows "iPhone 6.5-inch Display" → the 1284×2778
files); upload one matching set, never mixed sizes.

## Identity

| Field | Value | Limit |
|---|---|---|
| Name | `Endpaper — Journal in Ink` | 25/30 |
| Subtitle | `The journal you can't edit` | 26/30 |
| Category | Lifestyle (primary), Productivity (secondary) | |
| Age rating | 4+ (questionnaire: all "No") | |

## Keywords (98/100)

```
diary,journaling,daily,notebook,private,writing,minimal,permanent,notes,paper,reflection,gratitude
```

No spaces after commas. `journal`, `ink`, `edit` are already indexed from
the name/subtitle — don't spend keyword characters repeating them.

## Promotional text (149/170)

> The founding thirty: the first 30 writers get their first year free —
> write to hello@endpaper.space for a code. What you write here stays written.

(Promotional text is editable without review — swap the founding offer out
once the 30 codes are gone.)

## Description

> Endpaper is a journal written in ink. What you write cannot be edited
> and cannot be deleted. That is not a missing feature — it is the entire
> point.
>
> Paper never asked you to revise yourself. A notebook holds what you
> actually thought, in the words you actually used, on the day you used
> them. Endpaper works the way paper works.
>
> OPEN. WRITE. CLOSE.
> The page is ready the moment the app opens — today's date, a cursor,
> nothing else. Write, or dictate; close the app and it's saved. No
> folders, no tags, no formatting decisions. A journal, not a system to
> maintain.
>
> WRITTEN IN INK
> Committed words stay committed. Tomorrow you'll write from who you are
> tomorrow. Over months, the notebook becomes something no editable app
> can produce: an honest record.
>
> NO AI. NO ACCOUNT. NO ONE READING.
> Your writing lives on your device, and — if you choose — in your own
> private iCloud. There is no server of ours, no analytics, no third-party
> code, no AI reading your diary. The privacy label says "Data Not
> Collected" because we never receive any.
>
> A YEAR YOU CAN HOLD
> Every written day becomes a dot. Twelve rows, one year — a picture of
> your attention you can actually look at. Each December, Endpaper sets
> your year back before you: the honest version.
>
> YOURS, IN PLAIN TEXT
> Export the whole notebook as one plain-text file, any time. No lock-in.
> Deleting the app deletes the local copy; we hold nothing.
>
> WHAT IT COSTS
> A week free, then one yearly price — about the cost of a good paper
> notebook. No monthly upsell, no premium tiers, no ads. One notebook,
> one price.
>
> Made by one person, slowly. A human reads every email:
> hello@endpaper.space
>
> Endpaper is $39.99/year after a 7-day free trial. The subscription
> renews automatically unless cancelled at least 24 hours before the
> period ends — manage it anytime in iOS Settings → Subscriptions.
>
> Privacy Policy: https://endpaper.space/privacy.html
> Terms of Use (EULA): https://endpaper.space/terms.html

The last block is REQUIRED (guideline 3.1.2 — first submission was
rejected for a missing Terms of Use link). Auto-renew apps must carry a
functional ToU/EULA link in the description; ours qualifies because
terms.html incorporates Apple's standard EULA by reference.

## What's New (1.0)

> First edition.

## URLs

- Privacy policy: https://endpaper.space/privacy.html
- Support: https://endpaper.space/support.html
- Marketing: https://endpaper.space

## Privacy label

**Data Not Collected** — truthful as shipped: no analytics SDK, no
first-party telemetry, no accounts. Signals.swift is on-device only and
never networked. iCloud sync is the user's own private database (Apple is
the processor, not us). Revisit this label before ever adding telemetry.

## App Review notes (paste into the Notes field)

> Endpaper is a journaling app whose core rule is permanence: committed
> entries cannot be edited or deleted. This is intentional and is the
> product's main feature (it is taught during onboarding), not a defect.
> Users can export their full notebook as plain text from Settings.
>
> The app is fully usable without an account — there are no accounts.
> Subscription: 7-day free trial via introductory offer on the yearly
> subscription, hard paywall after. The paywall and Settings both include
> offer-code redemption.
>
> Nothing requires special configuration to review. Dictation uses the
> system speech recognizer with standard permission prompts.

## Export compliance

Uses only standard encryption (HTTPS/Apple frameworks) → exempt.
`ITSAppUsesNonExemptEncryption = NO` in the project so the question never
blocks a build upload.

## Submission order

1. Create app record (bundle ID from project.yml, SKU `endpaper-ios`).
2. Create the subscription group + `com.wendellbarton.endpaper.yearly`
   ($39.99/yr, 7-day free introductory offer) — submit it WITH the app's
   first version, in the version's In-App Purchases section.
3. After approval: create the `FOUNDING` offer code (free, 1 year,
   30 redemptions) and start handing it out.
