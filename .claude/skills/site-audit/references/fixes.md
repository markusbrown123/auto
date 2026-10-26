# Fixing what site-audit finds

Read the section for what came up. Each entry: why it matters, then the fix.

- [SEO](#seo) · [Local business](#local-business) · [Speed](#speed) · [Accessibility](#accessibility) · [Site files](#site-files)

## SEO

**Title.** The title is the blue link in Google and the tab name. 25–65 characters, the service and
the place first, the brand last: `Emergency Plumber in Trenton, NJ | Hartline Plumbing`. One per page,
different on every page.

**Meta description.** The grey text under the link; it doesn't rank, it gets the click. 70–160
characters, what they get and why call you: `Licensed plumbers on the road in 30 minutes, 24/7.
Up-front pricing before any work starts. Call (609) 555-0114.`

**One h1.** It says what the page is, for people and for Google. A logo is not the h1; on a service
page the h1 is the service and the area.

**Canonical.** `<link rel="canonical" href="https://example.com/page/">` with the page's own final
URL. It stops `?utm=` and `www`/no-`www` copies splitting the page's ranking.

**Open Graph.** What a link looks like when someone texts it to a friend, which is how trades get
referred: `og:title`, `og:description`, `og:image` (1200×630, absolute URL), plus `og:url` and
`og:type` = `website`.

**noindex.** Right on a staging or preview site; fatal on the live one. Check the live site before
handover.

**JSON-LD that doesn't parse.** One stray comma and Google ignores the whole block. Generate it (see
`local-seo`) instead of hand-editing, and validate with Google's Rich Results Test after deploy.

## Local business

**LocalBusiness JSON-LD.** Use the most specific type: `Plumber`, `Electrician`, `HVACBusiness`,
`RoofingContractor`, `HousePainter`, `Locksmith`, `GeneralContractor`, else
`HomeAndConstructionBusiness`. Required in practice: `name`, `telephone`, `url`, and either a full
`address` (a shopfront customers visit) or `areaServed` (a service-area business — most trades; don't
publish a home address). Add `openingHoursSpecification`, `priceRange` if public, `sameAs` (Google
Business Profile, Facebook, Yelp), `logo`, `image`. The `local-seo` skill writes all of this from one
facts file.

**NAP mismatch.** Name, address and phone must be identical on the page, in the schema, on the
Google Business Profile and in directories. Different phone formats are fine; different numbers or a
tracking number in one place are not.

**Click-to-call.** `<a href="tel:+16095550114">(609) 555-0114</a>` in the header and the hero, visible
without scrolling on a phone, at least 44 px tall. On a trade site the call is the conversion.

## Speed

**LCP (largest contentful paint) over 2.5 s on the phone.** The biggest thing on the first screen
arrives late. In order of likelihood:
1. The hero image is too big: serve it at the size it's shown (`srcset`/`sizes`, 1200–1600 px wide
   for full-bleed, AVIF or WebP, under ~200 KB).
2. It's lazy-loaded or discovered late (a CSS background, injected by script): use a real `<img>`,
   no `loading="lazy"`, add `fetchpriority="high"`, and `<link rel="preload" as="image">` if it's a CSS
   background.
3. Web fonts block the text: self-host WOFF2, `font-display: swap`, preload only the one or two files
   the first screen uses.
4. Render-blocking scripts or many stylesheets in `<head>`: `defer` scripts; inline the little CSS
   the first screen needs if the stylesheet is large.
5. Third-party widgets (chat, reviews, trackers) loading early: load them after `load` or on first
   interaction.

**CLS (layout shift) over 0.1.** Things move while loading: images and videos without `width` and
`height` (or `aspect-ratio`), fonts swapping to a very different size (use a metric-compatible
fallback or `size-adjust`), banners or cookie bars injected above content (reserve their space or
overlay them).

**Weight.** A brochure site needs under ~1.5 MB on first load and under 300 KB of JavaScript. The
usual culprits: uncompressed photos straight from a phone (4–8 MB each), a whole icon font for three
icons, an animation library for one fade, autoplaying video without a poster or with a huge file.

**Oversized images.** Re-export at 2× the displayed width at most (a 400 px card needs an 800 px image).

**Below-the-fold images not lazy.** Add `loading="lazy"` (and `decoding="async"`) to images more than
a screen down — never to the first-screen hero.

## Accessibility

Every axe finding names the rule; the fix is usually one of these:

| Rule | Fix |
|---|---|
| `color-contrast` | 4.5:1 for normal text, 3:1 for 18 px bold / 24 px regular and up. Check text on photos too. |
| `image-alt` | Describe what the picture shows for someone who can't see it; `alt=""` only for decoration. |
| `button-name`, `link-name` | Icon-only buttons and links need text: `aria-label="Call Hartline Plumbing"`. |
| `label` | Every input needs a `<label for>` (a placeholder is not a label). |
| `html-has-lang`, `document-title` | `<html lang="en">` and a real `<title>`. |
| `heading-order` | Don't skip levels for looks (h2 → h4); style the right level instead. |
| `region`, `landmark-*` | Wrap content in `<header>`, `<nav>`, `<main>`, `<footer>`. |
| `aria-*` | Remove ARIA you don't need; wrong ARIA is worse than none. |

**Sideways scroll on the phone.** Something is wider than the screen: a fixed `width` in px, `100vw`
(includes the scrollbar), a long unbroken word or URL (`overflow-wrap: anywhere`), a table (wrap it in
`overflow-x: auto`), an absolutely positioned decoration. Find it in the phone screenshot.

**Tap targets under 24 px.** WCAG 2.2 asks for 24×24 px at least; aim for 44×44 on anything people
tap with a thumb (call buttons, menu, form controls). Add padding, not font size.

## Site files

**robots.txt.** Must exist and must not say `Disallow: /` for `User-agent: *` on the live site (a
common leftover from staging). Point it at the sitemap: `Sitemap: https://example.com/sitemap.xml`.

**sitemap.xml.** Every page you want found, with absolute URLs. Submit it in Google Search Console.

**favicon.** A missing favicon is a 404 on every page view and a blank tab icon; add `favicon.ico` or
`<link rel="icon" href="/favicon.svg">`.

**Failed requests.** A 404 image or script on a live site is a broken page for someone; fix or remove
the reference.
