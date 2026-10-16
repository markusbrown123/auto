---
name: image-to-code
description: Turn design references — screenshots, mockups, Figma exports, a client's current site, or a live URL to match — into faithful frontend code, then compare the render against the reference until they match. Use when the user shares an image or URL of a design, says "make it look like this", asks to rebuild or modernize an existing site from screenshots, or provides a direction sheet to implement.
---

# Image to Code

Adapted for Claude Code from the `image-to-code` skill in [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) (MIT, see `LICENSE`). The upstream skill is written for Codex and generates its own design images first; here the references come from the user, the web, or a screenshot, and the extraction and anti-drift rules are kept.

## 1. Get references you can actually read

- **User images:** open each with the Read tool. If an image is a tiny full-page board, ask for (or cut) section-level images: one readable image per section beats one compressed board.
- **A URL to match or improve on:** screenshot it with `playwright-cli` at 1440×900 and 390×844, one screenshot per section (`playwright-cli screenshot <ref>` on the section element), not one long page.
- **An image-generation tool in this session:** you may generate section references first, as the upstream skill does. Without one, don't pretend; work from real references.

## 2. Analyze before coding

For every reference section, write short extraction notes. Treat the image as a spec, not a vibe.

- **Purpose and priority:** what the section is and the one thing the eye lands on first.
- **Text:** extract readable headline, subhead, CTA labels, nav and section titles. Use them only if they belong to the client (see step 5).
- **Typography:** serif/sans, display-to-body contrast, size and weight ratios, line count, line-height, tracking.
- **Spacing:** headline→subhead→buttons gaps, card gaps, section top/bottom padding, gutters, image-to-text distance. Aim for faithful *spacing logic*, not pixel OCR.
- **Components:** button shape, radius, fill vs outline, primary/secondary hierarchy, card anatomy, borders, dividers, shadows, input styling.
- **Color:** background, surfaces, text hierarchy, accent, border logic, image grade. Sample hex values where you can.
- **Imagery:** aspect ratios, crops, frames, how images sit against text.

## 3. Build

1. Tokens first: CSS custom properties (or Tailwind theme) for the extracted colors, type scale, spacing, and radii.
2. Then section by section, in the reference's order.
3. Media sits in fixed-aspect frames (`aspect-ratio` + `object-fit: cover`) with consistent proportions across similar modules.

Guard rails carried over from upstream:
- **Hero:** one focal point, headline in 1–3 lines, short supporting text, primary CTA visible on a 1366×768 laptop and a 390×844 phone without scrolling. No pills, fake stats, or micro-labels crowding it.
- **No nested boxes:** no cards inside cards inside panels. Prefer open layouts and whitespace over enclosure.
- **No micro-UI clutter:** no filler chips, pseudo-system tags, or decorative metadata rows.

## 4. Don't drift

The commonest failure: strong reference, generic result. While coding, do not compress generous spacing, flatten strong type into a default hierarchy, swap distinctive sections for stock rows, or "improve" the design into a template.

When a detail is unclear, resolve in this order: keep the visible design language → keep layout and spacing logic → keep the component family → keep the mood and polish level → ask for or capture a closer reference → only then pick the most faithful implementation-friendly option.

## 5. Compare and fix (max 3 rounds)

1. Render your build with `playwright-cli` at the same viewport and section as the reference.
2. Open both images and list the top three differences (spacing, type scale, color, alignment, crop).
3. Fix those three, re-render, repeat. Stop after three rounds and report what still differs.

## Rights and truthfulness

References give structure, never content. Don't copy another company's logo, photos, illustrations, or copy into a client site. A client's own existing site, photos, and text are theirs to reuse. Never invent reviews, stats, awards, or team names to fill a layout slot; drop the slot instead.
