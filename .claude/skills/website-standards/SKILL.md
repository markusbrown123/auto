---
name: website-standards
description: Required workflow for building, redesigning, generating, or fixing any public-facing website, landing page, or client site — including Automaton-generated sites and client redesigns. Use for new builds, redesigns, client fixes, hero/section/layout/visual changes, design reviews, and visual QA. Chains design-taste-frontend, awesome-design, image-to-code, playwright-cli, and web-design-guidelines into one direct → build → look → audit loop.
---

# Website Standards

Every website we build or fix goes through the same loop. Each step has its own skill; this one says when to use which and what "done" means.

**Repo rules win.** If the repo's CLAUDE.md, AGENTS.md, or task board locks a file, layout, or design system, these steps don't unlock it. Findings in locked or out-of-scope code get reported, not fixed. The client's existing brand and the user's explicit asks also beat any skill's house style.

## Size the job first

| Job | Steps |
|---|---|
| New site, full redesign, or "make it look premium/less generic" | All five steps, full `design-taste-frontend` run |
| Section or page change, client fix, visual bug | Skip the taste draw; read `design-taste-frontend/references/tells.md`, then steps 4–5 |
| Copy/content-only or one-line CSS fix | Steps 4–5 only, on the touched page |

A full taste run is expensive (30–45 min, a few hundred thousand tokens). Don't start one for a small fix.

## 1. Direction — `design-taste-frontend`

Run its steps 1–4 (inventory → argument → draw → idea). Write the direction down in your notes or PR: audience, the one action the page must drive, chosen direction and why, type system, palette roles.

- No sector fits a local trade or service business (most Automaton leads): use `--sector other`.
- Its house rules (no gradients, no resting shadows, no eyebrow labels, etc.) are defaults for new work. Where they contradict an established brand, a repo design system, or something the user asked for, keep the existing choice and say so.
- Its `assets.mjs` finds archival/open-collection pictures. For a real local business, never present those as the business's own work, crew, or location; the business's real photos come first.

## 2. References — `awesome-design`

Pull one or two real design systems that fit the direction and borrow structure (type scale, spacing, component anatomy, color proportions), never branding. Name what you borrowed.

## 3. Reference → code — `image-to-code`

When there's a screenshot, mockup, the client's current site, or a URL to match: extract, build tokens-first, compare render vs. reference, fix the top three differences, repeat (max 3 rounds).

## 4. Look at it — `playwright-cli` (+ the taste inspector)

Never ship UI you haven't seen rendered.

- Run the site locally (the repo's dev/preview script, or open the generated HTML file).
- At 390×844, 768×1024, and 1440×900: `snapshot`, `screenshot`, `console`. Open the screenshots and look at them.
- Check: no horizontal scroll, hero image loads, nav/menu works, primary CTA visible without scrolling on a phone, forms submit, no console errors.
- For full builds also run `node .claude/skills/design-taste-frontend/scripts/lint.mjs <src>` and `inspect.mjs <url>`; fix FAILs or defend them.

**Claude Code cloud sessions** (when `/opt/pw-browsers/chromium` exists). Shell variables don't persist between tool calls, so set them on the command that needs them:

```bash
command -v playwright-cli >/dev/null || npm install -g @playwright/cli@latest
PLAYWRIGHT_MCP_BROWSER=chromium PLAYWRIGHT_MCP_EXECUTABLE_PATH=/opt/pw-browsers/chromium playwright-cli open http://localhost:5173/

# taste inspector: Chromium refuses to run as root without --no-sandbox
printf '#!/bin/sh\nexec /opt/pw-browsers/chromium --no-sandbox "$@"\n' > /tmp/chromium-no-sandbox && chmod +x /tmp/chromium-no-sandbox
CHROME_PATH=/tmp/chromium-no-sandbox node .claude/skills/design-taste-frontend/scripts/inspect.mjs http://localhost:5173/
```

Remote images (e.g. Unsplash) can fail there with `ERR_TUNNEL_CONNECTION_FAILED`, and the inspector then reports them as broken. That's the sandbox's network policy, not the site; don't "fix" those URLs.

## 5. Audit — `web-design-guidelines`

Audit every file you changed against the Web Interface Guidelines. Fix findings in code you touched; list the rest under risks.

## Definition of done

- [ ] Job sized; direction and references written down (full builds).
- [ ] Rendered and screenshotted at phone, tablet, and desktop; no console errors, no horizontal overflow.
- [ ] Guidelines audit run on changed files; findings fixed or listed.
- [ ] Copy is truthful: no invented reviews, awards, stats, team names, or certifications for a real business.
- [ ] Report lists files changed, checks run (with viewports), open findings, and risks.

Scratch output (`.playwright-cli/`, `.taste-skill/`, `.design-refs/`) is gitignored; don't commit it.
