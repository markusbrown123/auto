---
name: site-audit
description: Launch check for any website, measured in a real browser — technical and local SEO (title, description, h1, canonical, Open Graph, JSON-LD and LocalBusiness fields, name-address-phone consistency, click-to-call on the first phone screen), Core Web Vitals on a throttled phone (LCP, CLS, page weight, lazy-loaded hero, oversized or unsized images, render-blocking scripts), accessibility with axe-core (WCAG 2.2 AA, contrast, names, alt), sideways scroll and small tap targets, robots.txt/sitemap, broken requests. Use it before calling any site, page or client fix done, after a redesign, when a page "feels slow", when asked about SEO, Google, Lighthouse, PageSpeed, accessibility or "is this ready to launch", and on a live client site before quoting a redesign. One command, no npm install.
---

# site-audit

One command that answers "is this page ready to put in front of customers and Google?" It loads
each page the way a customer on a mid-range phone would (390×844, 4× slower CPU, slow 4G — close
to Lighthouse's mobile run) and again on a desktop, and prints every problem as FAIL, WARN or ok.

It complements the rest of the website workflow: `design-taste-frontend`'s inspector judges how the
page *looks*; this judges whether it *works* — found, fast, usable, callable. Run both.

## Run it

```bash
node .claude/skills/site-audit/scripts/audit.mjs <url | build folder | page.html> [options]

  --pages /,/services/,/contact/   more pages under the same site (default: the one given)
  --local                          it's a local business: LocalBusiness JSON-LD and click-to-call are required
  --json report.json               the whole report as JSON (for a PR, a ticket, or comparing runs)
  --out .site-audit                where the phone and desktop screenshots go (default)
  --no-axe                         skip the accessibility engine (offline)
```

Needs Node 22+ and Chrome, Edge or Chromium installed (set `CHROME_PATH` to choose; in a Claude Code
cloud session use the `/tmp/chromium-no-sandbox` wrapper from `website-standards`). A folder or file
is served over a throwaway local server; a URL is loaded as is. axe-core comes from the project's
`node_modules` if present, otherwise `npm pack` fetches it once into `~/.cache/site-audit`.

Exit code 1 when anything FAILs, so it can gate a deploy script or CI. Besides the screenshots it
saves each page as rendered (`.site-audit/<page>.html`), so `copy-check` and `local-seo verify` can
read sites whose HTML is built by JavaScript.

On the phone it waits until the network has been idle for a second and LCP has stopped changing (at
most 25 s), so a hero that paints late is measured, not missed.

## Read the result

Fix every FAIL. Treat every WARN as a real problem unless you can say in one sentence why it doesn't
apply to this site — and say it in your report. The "ok" lines are the measurements to quote
(LCP, CLS, weight) when a client asks how fast their site is.

What each area means and how to fix the usual causes is in `references/fixes.md` — read the section
for whatever came up instead of guessing. The common ones for our trade sites:

- **No LocalBusiness JSON-LD / missing fields / NAP mismatch** → generate it with the `local-seo`
  skill from the business's facts; the phone in the schema, the footer and every `tel:` link must be
  the same number.
- **No click-to-call on the first phone screen** → the call is the conversion on a trade site; put
  the number (as a `tel:` link) in the header and the hero.
- **First-screen image set to `loading="lazy"`** → remove it there (and add `fetchpriority="high"`);
  lazy-load only what's below the fold.
- **axe color-contrast** → raise the text or background contrast to 4.5:1 (3:1 for large text);
  don't argue with it, the measurement is the customer reading your phone number in sunlight.

## When the numbers are wrong

- Lab numbers vary run to run by ±20%. A borderline LCP (2.3–2.8 s) deserves a second run before you
  rewrite anything.
- A local build has no CDN, compression or HTTP/2, so the live site is usually faster; a live site
  with tracking scripts is usually slower. Audit both before launch.
- `ERR_TUNNEL_CONNECTION_FAILED` or blocked third-party images in a sandbox are the sandbox's network,
  not the site — say so rather than "fixing" the URLs.

## In a report

Quote the RESULT line, list each FAIL with its fix, the WARNs you left with the one-sentence reason,
and the phone LCP/CLS/weight. Attach the two screenshots it saved.
