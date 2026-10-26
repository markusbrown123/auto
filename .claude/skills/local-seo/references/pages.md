# Service pages, city pages, and the owner's handover

- [Service pages](#service-pages) · [City pages](#city-pages) · [Handover for the owner](#handover-for-the-owner) · [Where this comes from](#where-this-comes-from)

## Service pages

A service page answers one search ("water heater repair Trenton") and turns it into a call. Local SEO
practitioners keep seeing the same thing: a blog post can outrank the service page, but the leads come
through the service page — because it has the phone and the form on it. So every service page has:

1. **h1**: the service and the main town — "Water heater repair in Trenton".
2. **The first screen**: what you fix, how fast you come, the `tel:` button, the licence line.
3. **What it costs or how pricing works** — a range, a call-out fee, "price agreed before work
   starts". Whatever is true; never a made-up number.
4. **What happens when they call**: who answers, when someone arrives, what they do first.
5. **Proof from this service**: a real job (photo, town, what was wrong, what was done), a real review
   that mentions it.
6. **Questions people ask about this service** (3–5, real ones from the owner's calls).
7. **The form and the phone again** at the end.

Generate its tags with `seo.mjs meta --service <slug>` and `seo.mjs schema --service <slug>`; link
it from the home page and the nav. Slugs are plain words: `/water-heater-repair/`.

Which services get pages: the ones people search for and the owner wants more of. Five strong pages
beat twenty thin ones. Ask the owner which jobs pay best and which calls they turn away.

## City pages

Google calls a set of near-identical pages that differ only by town "doorway pages", and they drag the
whole site down. The test practitioners use: would this page make sense in your site's navigation, for
a person from that town? It does only if it has things that are true about that town:

- jobs done there (street or neighbourhood, what was wrong, photo),
- a review from a customer there,
- what's different there (older housing stock and its pipes, the water hardness, the permit office,
  the response time from the shop),
- the towns next to it that the same crew covers.

No local material yet → no page. The town goes in `areaServed` and in an "Areas we serve" list on the
home page, and a page comes later when there are jobs to show. Never generate city pages from a
template with the name swapped, and never put the town list in a block of keywords.

Title: `seo.mjs meta --city Hamilton` (with `--service` for a service-in-town page).

## Handover for the owner

The website is the part we build. Give the owner this list (in plain words) for the part only they
can do — it moves the map pack more than anything on the site:

- **Google Business Profile**: verified; the right *primary* category (the main trade, e.g.
  "Plumber"), a few accurate secondary ones; hours; service areas; the website link; the phone the
  same as on the site (or the tracking number as primary and the real one as additional).
- **Name**: the real business name only. Adding keywords breaks Google's rules and gets profiles
  suspended.
- **Photos**: real jobs, the van, the team, every few weeks.
- **Reviews**: ask every happy customer, the same day, with the direct review link. Reply to every
  review, good and bad, in their own words; templated replies put people off. Recent reviews count
  far more with customers than a high total from years ago.
- **Directories**: the same name, address and phone on Yelp, Facebook, BBB, Angi, Nextdoor and the
  trade's own directories. Consistency matters more than quantity.
- **Search Console**: add the site, submit `sitemap.xml`.

## Where this comes from

Practitioner consensus on the Local Search Forum (doorway pages, service-area settings, schema and
rankings, call-tracking numbers), the Whitespark local ranking factors survey (profile and reviews
outweigh on-page and citations for the map pack), BrightLocal's local consumer review survey (recency
of reviews, replying to all of them, templated replies), Search Engine Land's tests of keyword-stuffed
business names, and Google's own guidance on structured data and doorway pages. Re-check the numbers
against the current year's editions before quoting them to a client.
