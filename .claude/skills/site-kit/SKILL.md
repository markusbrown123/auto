---
name: site-kit
description: Add Automaton's site kit to a client's website — the AI assistant that answers visitors from the business's own facts and takes call-back details after hours, the lead form, and Cal.com booking — by generating the client's kit module from their business.json, registering it, testing it locally, and adding one script tag to their pages. Use it whenever a premium client site needs a chat bot, assistant, "answer questions on the site", lead capture, "book a call/estimate" or appointment booking, after-hours coverage, or follow-up automation, and when a site from the kit misbehaves (wrong answers, origin refused, no booking button).
---

# site-kit

The kit is a small Netlify backend plus a drop-in widget that lives in the JARVIS repo, at
`bases/sites/kit` (on Markus's Mac `~/jarvis/bases/sites/kit`; if it's elsewhere,
`dirname "$(readlink -f "$(command -v jarvis)")"/..` finds the checkout). One kit serves many sites:
each client is one module in `sites/` and a `data-site` on their pages. Read the kit's `README.md`
once for what each endpoint does and what it costs to run; this skill is the procedure for adding a
client.

What a client gets: an assistant that answers only from their facts (never a price or promise that
isn't written there) and hands over to a call-back form; leads and Cal.com bookings kept and passed to
JARVIS, who drafts the follow-up for Markus to approve. Nothing is ever sent from the kit.

## Add a client

1. **Facts first.** The client's `business.json` (the `local-seo` facts file) must pass
   `seo.mjs check`. The assistant can only be as right as it is. For the kit, also fill (from the
   owner, never guessed): `pricing` (how they charge, in words — or leave it out and the assistant
   says prices are given on the phone), `callback` (the honest call-back promise), `faq` (real
   questions and the owner's answers), `accent` (the site's main colour), `bookingLabel`.

2. **Generate the module** into the kit (in a JARVIS background run, that's your own base folder; in
   a session, on the working branch):

   ```bash
   K=~/jarvis/bases/sites/kit
   node .claude/skills/site-kit/scripts/facts.mjs business.json > $K/sites/<id>.mjs
   ```

   The script prints the id it chose in the module (letters and digits only — it's also the
   `BOOKING_URL_<ID>` variable and the `data-site` value). Pass `--id` to pick it. Read the generated
   `facts` through once as the client would: anything wrong goes back into `business.json`, not
   into the module.

3. **Register it** in `$K/lib/sites.mjs`: one `import <id> from '../sites/<id>.mjs'` and the id in
   `SITES`. Check `origins` matches every address the site is served from (add the Netlify preview
   address while testing; a page from any other origin is refused with 403).

4. **Test locally**, no key and no cost:

   ```bash
   cd $K && npm test                       # the kit's own tests still pass
   KIT_FAKE_MODEL=1 node dev.mjs            # http://localhost:8888
   curl -s 'http://localhost:8888/api/site?site=<id>'   # the public config: name, accent, greeting, contact
   ```

   On the client's page (served from localhost, which dev mode allows), add the script tag pointing
   at `http://localhost:8888/kit/widget.js`, open it, ask a question, and send the form with a test
   number. With `ANTHROPIC_API_KEY` set instead of `KIT_FAKE_MODEL`, ask it three things the facts
   answer and one they don't (a price that isn't there): it must answer the first three and offer a
   call for the last.

5. **The client's pages**: before `</body>` on every page that should have it:

   ```html
   <script src="https://<kit address>/kit/widget.js" data-site="<id>" defer></script>
   ```

   It's `defer` and builds its own Shadow DOM, so it doesn't touch the page's styles or slow the
   first paint. Any button can open it with a question: `onclick="AutomatonKit.open('Can someone come
   tonight?')"`. Keep the page's own `tel:` button and form: the assistant is an extra way in, never
   the only one.

6. **Check the page** with `site-audit` (the widget must not add a FAIL) and look at it on a phone:
   the launcher must not cover the sticky call bar.

## Going live — Markus's part

Never deploy, set live variables or touch Cal.com yourself; list these for Markus as a NEED:

- Cal.com: an event type for the client (or the client's own Cal.com), with a webhook to
  `https://<kit>/api/booking?site=<id>` (booking created, rescheduled, cancelled; secret =
  `CAL_WEBHOOK_SECRET`).
- Netlify: `BOOKING_URL_<ID>` = that Cal.com link; then deploy the kit.
- The script tag on the live site, through that site's repo and branch rules.

Today every lead and booking from every site goes to Markus's Needs list through JARVIS. Passing a
client's leads straight to the client (an email, a client view) isn't built yet — say so in the
handover rather than promising it.

## Rules it keeps

- No key or secret in any page or in `sites/*.mjs`; the functions read them from Netlify's
  environment.
- The facts are the client's own words and numbers. The assistant says it's an AI assistant.
- Nothing is sent, texted or emailed from the kit; follow-ups wait for Markus.
- Visitors' addresses are kept only as salted hashes; leads' details stay out of git.
