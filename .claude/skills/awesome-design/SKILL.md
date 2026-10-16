---
name: awesome-design
description: Pull a real design system (a DESIGN.md from the awesome-design-md / getdesign.md catalog — Stripe, Linear, Apple, Airbnb, Notion and ~80 more) to anchor a website's tokens, type scale, spacing, and components. Use when starting a site or redesign, when a page looks generic or templated, or when the user names a brand or site whose feel they want.
---

# Awesome Design — real design systems as references

Source: [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md) (MIT), served by the `getdesign` CLI. Each DESIGN.md is a plain-markdown analysis of a real site's visual language: color tokens and roles, type scale, spacing and grid, component patterns, motion, and responsive behavior.

## 1. Pick one or two

`catalog.txt` in this folder lists every slug with a one-line description (snapshot from 2026-10-16). For the live list:

```bash
npx -y getdesign@latest list
```

Pick by *structure and mood*, not by industry. Most of the catalog is tech brands; for local-service and small-business sites, borrow from consumer and marketplace systems (e.g. `airbnb`, `apple`, `starbucks`, `uber`, `shopify`, `nike`) rather than dev-tool systems. Don't pick more than two: mixing systems produces mush.

## 2. Pull it into scratch space

```bash
npx -y getdesign@latest add <slug> --out .design-refs/<slug>.md
```

`.design-refs/` is gitignored scratch. If `npx` has no network, fetch the raw file instead:
`https://raw.githubusercontent.com/VoltAgent/awesome-design-md/main/design-md/<slug>/DESIGN.md`.

## 3. Read the whole file, then borrow structure

Take:
- type scale ratios, weights, line-heights, tracking
- spacing scale, section rhythm, container widths, gutters
- radius logic, border and shadow restraint
- component anatomy (button sizes and hierarchy, card structure, nav, forms)
- color *roles and proportions* (how much accent, where it appears)
- motion durations and easings

Never take:
- the brand's actual colors as the client's palette, its logo, product names, or copy
- proprietary fonts (map to a free equivalent with similar metrics)
- its imagery

## 4. Record it

- Name the reference(s) and what you borrowed in your report or PR.
- If the project has no design-system doc and you're setting its direction, write a project `DESIGN.md` in the same format, adapted to the client's brand. If the repo already has one (e.g. Automaton's `docs/AUTOMATON_UI_DESIGN_SYSTEM.md`), that doc wins and references only fill gaps.
