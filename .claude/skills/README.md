# Website design skills

Project skills Claude Code loads automatically in this repo. Start with `website-standards`: it is the workflow and says when to use each of the others. The same folder is kept in every website repo (automaton-, narrativa-site, premium-client-redesigns, auto); copy it whole into any new site repo.

| Skill | What it's for | Source | License |
|---|---|---|---|
| `website-standards` | The required build → look → audit loop and definition of done | Ours | — |
| `design-taste-frontend` | Taste Skill: art direction, anti-generic house style, browser inspector | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) `skills/taste-skill` @ `f624f37` (2026-10-14), verbatim | MIT |
| `web-design-guidelines` | Audit UI code against Vercel's Web Interface Guidelines | [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) @ `063bee9` + `command.md` from [vercel-labs/web-interface-guidelines](https://github.com/vercel-labs/web-interface-guidelines) @ `434b7f9` | MIT |
| `awesome-design` | Real design systems (DESIGN.md) as references | Ours, wrapping [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md) / `getdesign` CLI | MIT (catalog) |
| `image-to-code` | Turn screenshots/mockups/URLs into matching code | Ours, adapted from taste-skill's `image-to-code` for Claude Code | MIT |
| `playwright-cli` | Drive a real browser: snapshot, screenshot, click, console | `playwright-cli install --skills` from [`@playwright/cli`](https://github.com/microsoft/playwright-cli) 0.1.22 | Apache-2.0 |

## Local changes to vendored files

- `web-design-guidelines/SKILL.md`: reads the bundled `command.md` snapshot first instead of always fetching it.
- `playwright-cli/SKILL.md`: one added section, "Claude Code cloud sessions", for using the pre-installed Chromium.

Everything else in `design-taste-frontend/` and `playwright-cli/` is byte-for-byte upstream.

## Updating

```bash
# Taste Skill
git clone --depth 1 https://github.com/Leonxlnx/taste-skill /tmp/taste-skill
rm -rf .claude/skills/design-taste-frontend && cp -r /tmp/taste-skill/skills/taste-skill .claude/skills/design-taste-frontend
cp /tmp/taste-skill/LICENSE .claude/skills/design-taste-frontend/LICENSE

# Web Interface Guidelines snapshot
curl -fsSL https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md \
  -o .claude/skills/web-design-guidelines/command.md

# Playwright CLI skill (then re-add the cloud-sessions section)
npx -y @playwright/cli@latest install --skills

# Design reference catalog
npx -y getdesign@latest list | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^[a-z0-9.-]+ - ' > .claude/skills/awesome-design/catalog.txt
```

Update the commit hashes in this table when you do, and copy the folder to the other repos so they stay in sync.

## Using these on your own machine for every project

Copy the skill folders into `~/.claude/skills/` and they apply to every project you open locally in Claude Code, not just these repos.
