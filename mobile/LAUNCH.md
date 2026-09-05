# Launching Stash it

Written for the week the closed test ends. `PUBLISHING.md` gets it onto the
store; this is about anybody finding it once it is there.

---

## First, the thing that is not marketing

**Production access is an application, not a switch.** When the fourteen days
are served you apply, and Google reviews it — usually a few days, sometimes a
fortnight. Apply the moment you are eligible, on the Friday, and treat
everything below as work for the waiting period rather than for that weekend.

Plan the launch for the day access is granted, not the day testing ends.

---

## What you are actually selling

Three claims, in the order they persuade people:

1. **It tells you before a warranty runs out.** The problem is real, everybody
   has it, and nobody has solved it with a shoebox.
2. **There is no server.** No account, no cloud, nothing uploaded. This is the
   unusual one and it is the one that earns a post rather than a shrug.
3. **Photograph a receipt and it reads the date, the total and the shop.** This
   is the twenty-second video.

Lead with 1 for ordinary people and with 2 where the audience cares. Never lead
with a feature list.

**The line to use everywhere:**

> Warranties, receipts and renewals — on your phone, and nowhere else.

---

## Before you post anything

- [ ] The Play listing is live and installs cleanly on a phone that has never
      had a debug build
- [ ] Privacy policy URL resolves — it changed this week
- [ ] Buying works, and "I already paid" restores on a second phone
- [ ] Four to six screenshots with **real-looking data**, not "Test item 1"
- [ ] Feature graphic (1024 × 500) — Scout, the wordmark, and the one line
- [ ] A 20–30 second screen recording: open, photograph a receipt, watch the
      date and total fill in, save. No voiceover, no music, captions only.

That recording is the single most reusable asset you will make. It is the
Reddit post, the store video, and the reply to "what does it do".

---

## The first and best move: your twelve testers

A listing with no reviews converts badly, and the in-app prompt cannot fire for
a fortnight after install — by design. So the only early reviews you will get
are the ones you ask for.

On the day it goes public, message the testers individually. Not a broadcast.

> Stash it is public today. You have been using it for two weeks — if it has
> been useful, an honest review on the Play listing would genuinely help.
> If it has not, tell me instead and I will fix it.

**Do not offer anything in return.** Incentivised reviews are against Play
policy and can get the listing pulled. "Honest" is doing real work in that
sentence — say it and mean it.

Twelve reviews averaging 4.5 is a functioning listing. Zero reviews is not.

---

## Where to post, in order

Stagger these. One a day beats five in an hour, because you can only reply
properly to one conversation at a time — and replying is most of the value.

**Day 1 — r/androidapps.** Read the rules first; they have a specific format
for developer self-promotion. Post the video, the one line, and be explicit
that it is free with one optional unlock. Answer every comment.

**Day 2 — Hacker News, Show HN.** "Show HN: A warranty and document tracker
with no server at all". This crowd will actually care that the database is
SQLCipher, that entitlements never travel in a backup, and that the widget
payload carries no prices. Say those things plainly; do not dress them up.
Expect scrutiny, welcome it, and do not argue.

**Day 3 — r/degoogle, r/privacy.** Same app, different lead: no account, no
telemetry, no network permission being used for your data. These subs are
sceptical of app posts, so read the rules and be modest.

**Day 4+ — the ones where the *problem* lives.** r/homeowners, r/organization,
r/frugal, r/HomeImprovement. Do not post the app. Answer questions people are
already asking about tracking warranties, and mention it once, honestly, as
something you built. Slower, and the conversion is far better.

**Any time — Product Hunt.** Free, low effort, occasionally worth it for
Android utilities. Do not build a launch around it.

---

## What to write in the post

Not a feature list. The shape that works:

> I kept losing receipts and finding out a warranty had expired the week after
> something broke. Everything that solves it wants an account and a
> subscription, so I built one that has neither — it runs entirely on the
> phone, there is no server to hold your data because there is no server.
>
> [video]
>
> Free, one optional one-time unlock above 20 items. No ads, no tracking, no
> account.

Then answer everything. The comments are the marketing; the post is the excuse
for them.

---

## The first two weeks

- **Reply to every Play review**, including the bad ones, within a day. It is
  public, it is visible on the listing, and a developer who answers is the
  strongest signal a small app can send.
- **Ship one fix release quickly.** Whatever the first real complaint is, fix
  it and say so in the release notes. "Fixed because somebody asked" is worth
  more than the fix.
- **Watch the Play Console acquisition report.** The app has no analytics, by
  design, so this is your only view of what worked. Use a distinct UTM tag per
  post so you can tell them apart.
- **Roll out at 20% first.** A crash you did not see on two phones will surface
  on two hundred, and a staged rollout is the only undo the store offers.

---

## What not to do

- No paid install ads. They buy installs that do not stay, and the money is
  better spent on nothing at all.
- No launch email list you do not have.
- No "please rate 5 stars" anywhere in the app or in a message. Play forbids
  it, and it produces the reviews you least want.
- No claiming a feature the app does not have to win a comment thread. Every
  claim in this app is checkable by turning off the wifi. Keep it that way.

---

## The honest expectation

A free Android utility from an unknown developer, with no ad spend, does tens
to low hundreds of installs in its first week if the posts land, and single
digits if they do not. The number that matters is not week one. It is whether
the people who install it still have it in a month — and that is decided by the
app, which is finished, rather than by the launch, which is not.
