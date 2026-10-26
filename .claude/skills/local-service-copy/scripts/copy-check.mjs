#!/usr/bin/env node
// copy-check — reads a site's pages the way a wary homeowner would and flags the words that lose the call.
//
//   node copy-check.mjs <build folder | page.html> [...more]
//
// FAIL: placeholder text left in (exit 1). WARN: phrases that read as filler or AI-written, claims that
// need a source, buttons that don't say what happens, copy about "we" more than "you", long forms.
// It's a lint, not a judge: a WARN you can defend in one sentence can stay.
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'

const targets = process.argv.slice(2)
if (!targets.length || !targets.every(existsSync)) {
  console.error('usage: node copy-check.mjs <build folder | page.html> [...more]')
  process.exit(2)
}

// Left in by a template or a draft; on a live site each one is a broken promise.
const PLACEHOLDER = [
  ['dummy text', /lorem ipsum/i],
  ['a template slot', /\[(?:city|town|business|company|name|phone|service|area)[^\]]*\]|\{\{[^}]*\}\}|your (?:business|company) name/i],
  ['a draft note', /\bTODO\b|\bTBD\b|\bFIXME\b/],
  ['a fictional 555 phone number', /\b555[-. ]?\d{4}\b|\(?\d{3}\)?[-. ]?XXX[-. ]?XXXX/i],
  ['an example.com address', /\bexample\.(?:com|org)\b/i],
]
// Filler that says nothing a competitor couldn't say, and the words that mark copy as machine-written.
const FILLER = ['look no further', 'trusted partner', 'one-stop shop', 'second to none', 'we pride ourselves', 'top-notch', 'state-of-the-art', 'cutting-edge', 'world-class', 'tailored solutions', 'comprehensive solutions', 'your satisfaction is our', 'dedicated team of', 'go above and beyond', 'above and beyond', 'unparalleled', 'elevate', 'seamless', 'unlock', "in today's", 'nestled', 'delve', 'embark', 'testament to', 'game-changer', 'revolutioniz', 'empower', 'leverag', 'meticulous', 'whether you need', 'no job too big or too small', 'quality you can trust', 'excellence']
// Claims a customer (or the FTC) can ask "says who?" about.
const CLAIMS = [/\b(?:the )?best \w+ in\b/i, /#\s?1\b|\bnumber one\b/i, /\btop[- ]rated\b/i, /\baward[- ]winning\b/i, /\b100% (?:satisfaction|guaranteed)\b/i, /\blowest price/i, /\bcheapest\b/i, /\bguarantee[ds]?\b/i, /\b\d{1,3}(?:,\d{3})*\+? (?:happy |satisfied )?(?:customers|clients|jobs|homes)\b/i]
const VAGUE_CTA = /^(?:submit|send|learn more|read more|click here|get started|more|continue|go|ok)$/i
const EMOJI = /\p{Extended_Pictographic}/u

const pages = []
const walk = (p) => {
  if (statSync(p).isDirectory()) {
    for (const f of readdirSync(p)) if (!f.startsWith('.') && f !== 'node_modules') walk(join(p, f))
  } else if (p.endsWith('.html')) pages.push(p)
}
targets.forEach(walk)

const strip = (h) => h.replace(/<!--[\s\S]*?-->/g, ' ').replace(/<(script|style|noscript|template|svg)[\s\S]*?<\/\1>/gi, ' ')
const text = (h) => strip(h).replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&#39;|&rsquo;/g, "'").replace(/\s+/g, ' ').trim()
const short = (s) => (s.length > 70 ? s.slice(0, 67) + '…' : s)

let fails = 0
let warns = 0
for (const p of pages) {
  const html = readFileSync(p, 'utf8')
  if (/<meta[^>]+http-equiv=["']refresh/i.test(html)) continue
  const body = text(html.replace(/^[\s\S]*?<body[^>]*>/i, ''))
  const words = body.split(/\s+/).filter((w) => /[a-z]/i.test(w))
  if (words.length < 30) continue
  const out = []
  const F = (m) => (out.push(`  FAIL ${m}`), fails++)
  const W = (m) => (out.push(`  WARN ${m}`), warns++)
  const around = (re) => {
    const m = body.match(re)
    return m ? short(body.slice(Math.max(0, m.index - 25), m.index + m[0].length + 25).trim()) : ''
  }

  for (const [what, re] of PLACEHOLDER) if (re.test(body)) F(`${what} left in: "${around(re)}"`)
  const lower = body.toLowerCase()
  const filler = FILLER.filter((f) => lower.includes(f))
  if (filler.length) W(`filler a competitor could say word for word (say what you actually do instead): ${filler.map((f) => `"${f}"`).join(', ')}`)
  for (const re of CLAIMS) if (re.test(body)) W(`claim that needs a source on the page, or out: "${around(re)}"`)

  const ctas = [...strip(html).matchAll(/<button\b[^>]*>([\s\S]*?)<\/button>|<a\b[^>]*class=["'][^"']*\b(?:btn|button|cta)[^"']*["'][^>]*>([\s\S]*?)<\/a>|<input\b[^>]*type=["']submit["'][^>]*value=["']([^"']*)["']/gi)]
    .map((m) => (m[1] ?? m[2] ?? m[3] ?? '').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim())
    .filter(Boolean)
  const vague = [...new Set(ctas.filter((c) => VAGUE_CTA.test(c)))]
  if (vague.length) W(`buttons that don't say what happens: ${vague.map((c) => `"${c}"`).join(', ')} → "Call (609) 555-…", "Get my price", "Book a time"`)
  const emojiCtas = ctas.filter((c) => EMOJI.test(c))
  const heads = [...strip(html).matchAll(/<h[1-3]\b[^>]*>([\s\S]*?)<\/h[1-3]>/gi)].map((m) => m[1].replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim())
  if (emojiCtas.length || heads.some((h) => EMOJI.test(h))) W('emoji in headings or buttons read as template or AI-made; use words or a real icon')

  const h1 = heads.length ? [...strip(html).matchAll(/<h1\b[^>]*>([\s\S]*?)<\/h1>/gi)].map((m) => m[1].replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim()) : []
  if (h1[0] && h1[0].split(' ').length > 12) W(`h1 is ${h1[0].split(' ').length} words; say what you do and where in under 10: "${short(h1[0])}"`)

  const we = (lower.match(/\b(?:we|we're|we've|our|ours|us)\b/g) ?? []).length
  const you = (lower.match(/\b(?:you|you're|you've|your|yours)\b/g) ?? []).length
  if (we > 8 && we > you * 1.5) W(`talks about itself (we/our ×${we}) more than the customer (you/your ×${you}); lead with their problem`)

  const dashes = (body.match(/—/g) ?? []).length
  if (dashes > 3 && dashes > words.length / 100) W(`${dashes} em dashes in ${words.length} words; heavy em-dash use is a known AI-copy tell, use full stops`)

  const sentences = body.split(/[.!?]+\s/).filter((s) => s.split(' ').length > 3)
  const avg = sentences.length ? words.length / sentences.length : 0
  if (avg > 22) W(`sentences average ${Math.round(avg)} words; homeowners skim on a phone, aim for under 18`)

  for (const [, form] of strip(html).matchAll(/<form\b[\s\S]*?<\/form>/gi).map((m) => [null, m[0]])) {
    const fields = [...form.matchAll(/<(input|select|textarea)\b([^>]*)>/gi)].filter(([, tag, attrs]) => tag !== 'input' || !/type=["'](?:hidden|submit|button|checkbox|radio)["']/i.test(attrs)).filter(([, , attrs]) => !/tabindex=["']-1["']|aria-hidden=["']true["']/i.test(attrs))
    if (fields.length > 5) W(`a form asks ${fields.length} things; name, phone, what's wrong and ZIP is enough to call someone back`)
  }

  const at = relative(process.cwd(), p)
  if (out.length) console.log(`${at.startsWith('..') ? p : at}\n${out.join('\n')}`)
}
console.log(`\n${pages.length} page(s): ${fails} FAIL, ${warns} WARN`)
process.exit(fails ? 1 : 0)
