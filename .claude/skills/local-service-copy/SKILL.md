---
name: local-service-copy
description: Writing and checking the words on a local service business's website so visitors call — plumbers, electricians, HVAC, roofers, painters, cleaners, contractors, locksmiths, landscapers, any trade, and small service businesses generally. Covers the first phone screen, the call-first contact order, page and section order, trust that holds up (licence, real dated reviews, real job photos, terms of any guarantee), plain words in the owner's voice, honest after-hours and emergency claims, short forms, and a copy-check script that flags placeholders, filler and AI-sounding phrases, unsourced claims, vague buttons and long forms. Use it whenever you write, rewrite or review headlines, hero text, service pages, calls to action, forms or reviews sections for a local business site, when a client site "doesn't get calls", and before handing any trade site over — even when the request only says "make the site better" or "write the copy".
---

# local-service-copy

A trade site has one job: the phone rings, or a form comes in that someone calls back. People land on
it with a problem (no hot water, a leak, a breaker that keeps tripping), on a phone, often stressed,
comparing two or three businesses in a minute. They're asking three things: *do they fix this, can
they come soon, can I trust them?* Every line either answers one of those or is in the way.

Start from the facts file the `local-seo` skill uses (`business.json`): the services, towns, hours,
licence and phone are already there, and the copy must agree with it. What it doesn't hold, get from
the owner — see "Ask the owner" below. Never fill a gap with something that sounds plausible.

## The order of contact

Most homeowners still want to call; text and online booking come well behind, and an emergency is
always a call. So, everywhere on the site:

1. **Call** — the number as a `tel:` button, visible on the first phone screen, and kept on screen
   on phones (a slim sticky bar or header).
2. **Text**, if the business takes texts.
3. **A short form** — for people who can't call right now — with an honest promise of when they'll
   hear back ("we call back within the hour, 7 am–6 pm"). The business that calls back first usually
   gets the job, and most don't answer a web lead within five minutes, so the promise has to be one
   they keep.
4. **Online booking** (Cal.com through the site kit) for estimates and non-urgent work, never as the
   only way in for an emergency.

## The first phone screen (390 px wide)

- **h1: what you fix, and where.** "Plumber in Trenton" or "No hot water? Same-day water heater
  repair in Trenton." Under ten words, in the words customers use, not "solutions".
- **One line of the promise that's true and specific:** how soon someone comes, how pricing works
  ("price agreed before any work starts"), the area.
- **The call button with the number on it**, then the secondary action.
- **The licence line**, next to the button: "NJ Master Plumber Lic. #…, insured". It's what a wary
  customer looks for before they call.
- **A real photo**: the owner, the van, a real job. Stock photos of smiling models read as fake, and
  presenting them as the crew is a lie.

## Page order

Home page: the first screen → the services (each linking to its page) → how it works when you call
(who answers, how soon, what happens first, how you're charged) → real reviews → real recent jobs →
areas served → questions people ask → the form and the phone again → the footer with the NAP block
from `local-seo`.

Vary the sections. The same heading + three cards rhythm on every section is one of the clearest
signs of a template or AI-made site. Let the reviews look like reviews, the jobs like a photo log, the
process like steps.

Service pages: follow `local-seo/references/pages.md` — they're where the calls come from.

## Trust that holds up

- **Reviews**: real ones, with first name, town, date and where they're from (Google, Yelp), newest
  first, linked to the profile. People trust recent reviews far more than a big total from years
  ago, and notice when the owner replies. Never write, merge or "tidy" reviews; never invent a rating
  or count. A quoted review can say "best plumber in Philly" — the customer is the source.
- **Guarantees**: only what the owner really offers, with its terms ("if the same leak comes back
  within 90 days, we fix it free"). A bare "100% guaranteed" reads as filler.
- **Numbers**: years in business, jobs done, response time, only from the owner and only if true.
- **24/7 / emergency**: only if someone really answers at 3 am. Otherwise say exactly what's true:
  "Burst pipes answered until 10 pm, and first thing at 7."

## Words

- Write how the owner talks on the phone. Short sentences; one idea each.
- The customer's problem first, in their words ("water coming through the ceiling"), then what you do.
- "You" more than "we". The page is about their problem, not the company's values.
- Buttons say what happens: "Call (609) 555-…", "Get my price", "Book a free estimate". Never
  "Submit", "Learn more", "Get started".
- Specific beats impressive: "On the road in 30 minutes in Trenton and Hamilton" beats "fast,
  reliable service".
- Cut filler a competitor could say word for word, and the phrases that mark copy as machine-written:
  "look no further", "your trusted partner", "we pride ourselves", "top-notch", "state-of-the-art",
  "seamless", "elevate", "unlock", "go above and beyond", "no job too big or too small". The script
  keeps the full list. Go easy on em dashes in customer copy; full stops read cleaner.

## Forms

Name, phone, what's wrong (one text box), ZIP. Email optional. Each extra field loses people. Keep the
bot trap hidden (the site kit's lead form has one). The button says what happens, and the page after
says when they'll hear back.

## After hours: the assistant

On a premium site the site kit's assistant (`site-kit` skill) covers the hours nobody answers: it
answers only from the business's facts, takes a name and callback number, says when they'll get a
call, and always shows the phone number. It says it's an assistant. Many people dislike talking to a
bot instead of a person, so it's a way to get a callback, never a wall in front of the phone.

## Ask the owner

Five questions get better copy than any amount of writing:
1. What do people call you about most, and in what words?
2. What do customers say when they're relieved it's fixed?
3. How soon can you really get there, and where?
4. How do you price — call-out fee, free estimate, price before work starts?
5. What do you do that the others around you don't (or what do they get wrong)?

## Check it

```bash
node .claude/skills/local-service-copy/scripts/copy-check.mjs <build folder or page.html>
```

FAIL (exit 1): placeholder text left in — a template slot like `[City]`, lorem ipsum, a 555 number,
example.com, TODO. WARN: filler and AI-sounding phrases, claims that need a source, vague buttons,
emoji in headings, a long h1, "we" outweighing "you", heavy em-dash use, long sentences, long forms.
Fix FAILs. A WARN can stay if you can say in one sentence why (e.g. a guarantee whose terms are on the
page) — say it in the report.

## Done when

- [ ] Every fact on the page is in `business.json` or came from the owner; nothing invented.
- [ ] First phone screen: h1 (what + where), the promise, the call button with the number, the licence.
- [ ] The phone stays reachable on phones; the form is four fields with an honest call-back promise.
- [ ] Reviews are real, dated and sourced; no ratings, counts or awards that can't be shown.
- [ ] `copy-check.mjs` has no FAIL; WARNs fixed or defended. `local-seo`'s `verify` passes.
