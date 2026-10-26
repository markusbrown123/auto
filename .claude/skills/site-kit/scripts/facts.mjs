#!/usr/bin/env node
// site-kit — turns a client's business.json (the local-seo facts file) into the kit's site module,
// so the assistant answers from the same facts the pages and the schema were built from.
//
//   node facts.mjs business.json [--id hartline] [--accent '#0b5fff'] > <kit>/sites/<id>.mjs
//
// Optional business.json fields it uses beyond local-seo's: "pricing" (how they charge, in words),
// "callback" (the honest call-back promise), "faq" ([{ "q": "…", "a": "…" }]), "accent", "bookingLabel".
import { readFileSync } from 'node:fs'

const [file, ...rest] = process.argv.slice(2)
const opt = (name) => (rest.includes(name) ? rest[rest.indexOf(name) + 1] : null)
if (!file) {
  console.error("usage: node facts.mjs business.json [--id name] [--accent '#hex'] > sites/<id>.mjs")
  process.exit(2)
}
const b = JSON.parse(readFileSync(file, 'utf8'))
const fail = (m) => (console.error(m), process.exit(1))
if (!b.name || !b.url || !b.telephone) fail('business.json needs at least name, url and telephone (run local-seo check)')

// The id is also the env var suffix (BOOKING_URL_<ID>) and the widget's data-site, so letters and digits only.
const id = (opt('--id') ?? b.name).toLowerCase().replace(/[^a-z0-9]+/g, '').slice(0, 24)
const accent = opt('--accent') ?? b.accent ?? '#1f6feb'
if (!/^#[0-9a-f]{6}$/i.test(accent)) fail(`accent must be a #rrggbb colour, got ${accent}`)
const host = new URL(b.url).hostname.replace(/^www\./, '')
const digits = String(b.telephone).replace(/\D/g, '').replace(/^1(?=\d{10}$)/, '')
const phone = digits.length === 10 ? `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}` : b.telephone
const DAY = { Mo: 'Mon', Tu: 'Tue', We: 'Wed', Th: 'Thu', Fr: 'Fri', Sa: 'Sat', Su: 'Sun' }
const span = (days) => (days.length > 2 ? `${DAY[days[0]]}–${DAY[days.at(-1)]}` : days.map((d) => DAY[d]).join(', '))
const areas = b.areaServed?.length ? b.areaServed : [b.address?.addressLocality].filter(Boolean)
const services = b.services ?? []

const lines = []
const section = (title, items) => items.length && lines.push('', title, ...items.map((i) => `- ${i}`))
lines.push(`${b.name} (${host})${areas.length ? ` serves ${areas.join(', ')}` : ''}.${b.description ? ` ${b.description}` : ''}`)
section('SERVICES', services.map((s) => (s.description ? `${s.name}: ${s.description}` : s.name)))
section('HOURS', [
  ...(b.open24h ? ['Open 24 hours, every day.'] : (b.hours ?? []).map((h) => `${span(h.days)}: ${h.opens}–${h.closes}`)),
  ...(b.hours && !b.open24h ? ['Closed at other times.'] : []),
  ...(b.emergency ? [`Emergencies: ${b.emergency}`] : []),
])
section('PRICING', [b.pricing ?? 'Prices are given on the phone or at an estimate. No price is quoted in chat.'])
section('LICENCE AND INSURANCE', [b.license].filter(Boolean))
section('QUESTIONS CUSTOMERS ASK', (b.faq ?? []).map((f) => `${f.q} ${f.a}`))
section('CALL-BACKS', [b.callback ?? 'Someone from the business calls back; no time is promised in chat.'])
lines.push('', `Contact: call ${phone}${b.email ? ` or email ${b.email}` : ''}.${b.address && b.showAddress !== false ? ` Address: ${b.address.streetAddress}, ${b.address.addressLocality}, ${b.address.addressRegion} ${b.address.postalCode}.` : ''}`)

const facts = lines.join('\n').replace(/\\/g, '\\\\').replace(/`/g, '\\`').replace(/\$\{/g, '\\${')
const q = (s) => JSON.stringify(s)
const suggestions = [...services.slice(0, 2).map((s) => `Do you do ${s.name.toLowerCase()}?`), b.open24h || b.emergency ? 'Can someone come tonight?' : 'How soon can you come?'].slice(0, 3)

console.log(`/**
 * ${b.name}: what the site assistant knows and how it looks there.
 *
 * Generated from the site's business.json by the site-kit skill (${new Date().toISOString().slice(0, 10)}).
 * The assistant answers only from \`facts\`: change business.json and regenerate rather than
 * editing them here. The booking link comes from BOOKING_URL_${id.toUpperCase()}.
 */
export default {
  id: ${q(id)},
  name: ${q(b.name)},
  origins: [${q(`https://${host}`)}, ${q(`https://www.${host}`)}],
  accent: ${q(accent)},
  greeting: ${q(`Hi, I'm ${b.name}'s assistant. Ask about a job, the areas covered, or how pricing works, and I can take your number for a call back.`)},
  suggestions: ${q(suggestions)},
  booking: { label: ${q(b.bookingLabel ?? 'Book an estimate')} },
  contact: { phone: ${q(phone)}${b.email ? `, email: ${q(b.email)}` : ''} },
  thanks: ${q(`Thanks, we've got your details. ${b.callback ?? 'Someone will call you back.'}`)},
  facts: \`${facts}\`,
}`)
