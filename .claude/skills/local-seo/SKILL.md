---
name: local-seo
description: Local SEO for a local service business's website (plumber, electrician, HVAC, roofer, painter, cleaner, contractor, locksmith, any trade, also real estate agents) — one facts file (business.json) generates the LocalBusiness JSON-LD, title/description/canonical/Open Graph tags, the name-address-phone footer, robots.txt and sitemap.xml, and verifies every built page uses the same phone number, the business name, valid schema and no claims the business doesn't make (24/7, review stars). Also how to plan service pages and city pages without doorway-page spam, and what to hand the owner for their Google Business Profile. Use it whenever a site for a local business is built, launched or fixed, when site-audit reports missing LocalBusiness schema, a NAP mismatch or missing meta tags, and whenever someone asks about ranking on Google or in the map pack, "near me" searches, schema, or service-area pages.
---

# local-seo

For a trade business, being found means two things: the map pack (the three businesses under the
map) and the plain results below it. The map pack runs mostly on the Google Business Profile and its
reviews; the website's part is to say clearly and consistently who the business is, what it does and
where, and to turn the visit into a call. This skill does the website's part from one facts file, so
the phone number in the schema, the footer and every call button can never drift apart.

## 1. Write the facts file

Copy `assets/business.example.json` to the site repo as `business.json` and fill it from the owner —
their survey, their Google Business Profile, their invoices. Every field is a fact a customer or
Google will hold them to, so nothing is guessed:

- `name` exactly as on the Google Business Profile. No keywords added ("Hartline Plumbing", not
  "Hartline Plumbing – Emergency Plumber Trenton"): stuffing the name gets profiles suspended.
  If the trucks, logo or signs use a longer form ("A-1 Sealcoating Asphalt Services" for "A-1
  Sealcoating LLC"), put it in `alternateName` so both read as one business.
- `type`: the most specific schema.org type — `Plumber`, `Electrician`, `HVACBusiness`,
  `RoofingContractor`, `HousePainter`, `Locksmith`, `GeneralContractor`, `MovingCompany`, `AutoRepair`,
  `RealEstateAgent`, else `HomeAndConstructionBusiness`.
- `telephone`: the business's real number. If they use call tracking, the tracking number goes on the
  Google profile as primary and the real number as additional; the site keeps the real one.
- `address` + `showAddress`: a shopfront customers visit shows it (`true`). A service-area business
  working from home (most trades) sets `false` — the street stays off the web; the town, state and ZIP
  remain — and lists the towns it goes to in `areaServed` (strings), or a wider area written out:
  `{ "@type": "State", "name": "New Jersey" }`. No address known at all is fine for a service-area
  business: `areaServed` alone carries it.
- `hours` or `"open24h": true` — only if someone really answers at 3 am. `emergency` says what's true
  instead ("burst pipes answered until 10 pm"). Unknown hours are left out; `check` lists them as a
  question for the owner rather than failing.
- `license`, `services` (name, slug, one-sentence description each), `servicePages: true` only if
  the site has a page per service (the schema then links each one; a one-page site leaves it out),
  `sameAs` (Google profile, Facebook, Yelp, BBB), `ogImage` (1200×630, a real job photo).
- Leave out anything you don't know. A missing field costs little; a wrong one costs trust.

Check it: `node .claude/skills/local-seo/scripts/seo.mjs check business.json`

## 2. Generate the tags

```bash
S=.claude/skills/local-seo/scripts/seo.mjs
node $S schema business.json                         # home page <head>: business + website JSON-LD
node $S schema business.json --service drain-cleaning # a service page: adds the Service node
node $S meta   business.json [--service slug] [--city Hamilton]  # title, description, canonical, Open Graph
node $S nap    business.json                         # the footer's name / area / phone / licence block
node $S files  business.json dist/                   # after the build: sitemap.xml + robots.txt
node $S verify business.json dist/                   # before calling it done
```

Paste the output into the page templates (or have the build call the script). Don't hand-edit the
JSON-LD afterwards — one stray comma and Google ignores the whole block; change `business.json` and
regenerate. The script leaves out review stars (`aggregateRating`) on purpose: Google ignores
self-published ratings for local businesses and can penalise them. Real reviews go on the page as text,
linked to where they live.

A site built with JavaScript (React, Vue, a Vite SPA) has almost nothing in its HTML files, so run
`site-audit` first and point `verify` at the rendered pages it saves: `seo.mjs verify business.json
.site-audit/`. The JSON-LD and meta tags themselves must still be in the HTML the server sends —
Google reads structured data from the initial HTML most reliably — so put them in `index.html` (or
the framework's head), not in a component.

`verify` exits 1 with a list when a page shows or links a different number, a JSON-LD block doesn't
parse, the name is missing, there are review stars in the schema, or the page says 24/7 when the
facts don't. Fix the page, not the check.

## 3. Plan the pages

Read `references/pages.md` before adding service or city pages. In short:

- **One page per service** that people search for and the business wants more of ("water heater
  repair", "drain cleaning"), each with its own h1 (service + main town), the phone and the form on it.
  Service pages are where the calls come from.
- **City pages only with something local on them** — jobs done there, a review from someone there,
  photos, the town's specifics. The same page with the town name swapped is a doorway page and hurts
  the whole site. If there's nothing real to say about a town, it goes in `areaServed` and the
  "Areas we serve" list, not on its own page.

## 4. What the website doesn't do

Say this to the owner rather than letting them believe the site alone ranks them:

- The map pack is mostly the Google Business Profile (category, completeness, photos, posts) and
  reviews (how many, how recent, whether the owner replies). The website's on-page signals matter, but
  less; directory citations matter least. Ranking is strongest near the verified address — setting
  more service areas on the profile changes where it shows, not how it ranks.
- Schema doesn't lift rankings by itself; it makes the facts unambiguous and can earn rich results.
- What moves it: a complete profile with the right primary category, a steady stream of recent reviews
  that the owner answers personally (not with a template), real photos, and the site linked from the
  profile. `references/pages.md` has the handover list to give them.

## Done when

- [ ] `seo.mjs check` passes and every value came from the owner.
- [ ] Every page has its own title, description and canonical; the home page and each service page
      have the JSON-LD; the footer has the NAP block.
- [ ] `seo.mjs files` wrote sitemap.xml and robots.txt into the build, and `seo.mjs verify` passes.
- [ ] `site-audit --local` shows no local or SEO FAILs.
- [ ] After deploy: Google's Rich Results Test on the home page; sitemap submitted in Search Console
      (the owner's account, or note it as theirs to do).
