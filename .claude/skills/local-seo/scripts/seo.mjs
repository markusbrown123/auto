#!/usr/bin/env node
// local-seo — one facts file (business.json) in; everything search engines read out.
//
//   node seo.mjs check   business.json                 validate the facts
//   node seo.mjs schema  business.json [--service slug] the JSON-LD <script> for the home page or a service page
//   node seo.mjs meta    business.json [--service slug] [--city name]  title + description + Open Graph + canonical tags
//   node seo.mjs nap     business.json                 the name-address-phone footer block (HTML)
//   node seo.mjs files   business.json <build folder>  write robots.txt and sitemap.xml from the folder's pages
//   node seo.mjs verify  business.json <build folder>  every page's numbers, name, schema and claims match the facts
//
// No dependencies. Everything printed is HTML/JSON ready to paste, generated from the same facts,
// so the phone number in the schema, the footer and the click-to-call can never drift apart.
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import { join, relative } from 'node:path'

const [cmd, file, ...rest] = process.argv.slice(2)
const opt = (name) => (rest.includes(name) ? rest[rest.indexOf(name) + 1] : null)
if (!cmd || !file) {
  console.error('usage: node seo.mjs <check|schema|meta|nap|files|verify> business.json [--service slug] [--city name] [folder]')
  process.exit(2)
}
const b = JSON.parse(readFileSync(file, 'utf8'))

// The schema.org types for trades; anything else falls back to the general one.
const TYPES = ['Plumber', 'Electrician', 'HVACBusiness', 'RoofingContractor', 'HousePainter', 'Locksmith', 'GeneralContractor', 'MovingCompany', 'HomeAndConstructionBusiness', 'LocalBusiness', 'ProfessionalService', 'AutoRepair', 'RealEstateAgent']
// What a customer types, for the home page title when there's no "tagline".
const PLAIN = { HVACBusiness: 'Heating & Air Conditioning', RoofingContractor: 'Roofing', HousePainter: 'House Painting', HomeAndConstructionBusiness: 'Home Services', AutoRepair: 'Auto Repair', RealEstateAgent: 'Real Estate Agent' }
const DAYS = { Mo: 'Monday', Tu: 'Tuesday', We: 'Wednesday', Th: 'Thursday', Fr: 'Friday', Sa: 'Saturday', Su: 'Sunday' }
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
const url = (path = '') => new URL(path.replace(/^\//, ''), b.url.replace(/\/?$/, '/')).href
const digits = (p) => String(p).replace(/\D/g, '')
const e164 = (p) => {
  const d = digits(p)
  return d.length === 10 ? `+1${d}` : `+${d}`
}
const pretty = (p) => {
  const d = digits(p).replace(/^1(?=\d{10}$)/, '')
  return d.length === 10 ? `(${d.slice(0, 3)}) ${d.slice(3, 6)}-${d.slice(6)}` : p
}
const service = (slug) => {
  const s = (b.services ?? []).find((x) => x.slug === slug)
  if (!s) throw new Error(`no service "${slug}" in ${file} (have: ${(b.services ?? []).map((x) => x.slug).join(', ')})`)
  return s
}

function check() {
  const P = []
  const need = (cond, msg) => cond || P.push(msg)
  need(b.name, 'name: the business name, exactly as on the Google Business Profile')
  need(TYPES.includes(b.type), `type: one of ${TYPES.join(', ')}`)
  need(/^https:\/\//.test(b.url ?? ''), 'url: the live https:// address')
  need(digits(b.telephone ?? '').length >= 10, 'telephone: the main number customers call (not a tracking number unless it is the one everywhere)')
  need(b.address || b.areaServed?.length, 'address (a place customers visit) or areaServed (the towns you go to) — a service-area business needs areaServed')
  if (b.address) need(['streetAddress', 'addressLocality', 'addressRegion', 'postalCode'].every((k) => b.address[k]), 'address: streetAddress, addressLocality, addressRegion and postalCode')
  if (b.hours) need(b.hours.every((h) => h.days?.every((d) => DAYS[d]) && /^\d\d:\d\d$/.test(h.opens) && /^\d\d:\d\d$/.test(h.closes)), 'hours: [{ "days": ["Mo","Tu"], "opens": "07:00", "closes": "18:00" }]')
  else need(b.open24h, 'hours, or "open24h": true')
  for (const s of b.services ?? []) need(s.name && /^[a-z0-9-]+$/.test(s.slug ?? ''), `service "${s.name ?? '?'}": a name and a lowercase-hyphen slug`)
  if (b.reviews && !b.reviews.source) P.push('reviews: say where they are from (e.g. "Google") — and only real numbers')
  if (P.length) {
    console.log(`${file}: ${P.length} to fix`)
    P.forEach((p) => console.log(`  - ${p}`))
    process.exit(1)
  }
  console.log(`${file}: ok — ${b.type} "${b.name}", ${b.services?.length ?? 0} services, ${b.address && b.showAddress !== false ? 'shows its address' : `serves ${(b.areaServed ?? []).length} areas`}`)
}

function business() {
  const node = {
    '@type': b.type,
    '@id': url('#business'),
    name: b.name,
    url: url(),
    telephone: e164(b.telephone),
  }
  if (b.email) node.email = b.email
  if (b.logo) node.logo = b.logo
  if (b.image) node.image = b.image
  if (b.description) node.description = b.description
  if (b.priceRange) node.priceRange = b.priceRange
  if (b.founded) node.foundingDate = String(b.founded)
  // A shopfront shows its address; a service-area business (most trades) keeps a home address off the web.
  if (b.address && b.showAddress !== false) node.address = { '@type': 'PostalAddress', addressCountry: 'US', ...b.address }
  else if (b.address) node.address = { '@type': 'PostalAddress', addressLocality: b.address.addressLocality, addressRegion: b.address.addressRegion, postalCode: b.address.postalCode, addressCountry: b.address.addressCountry ?? 'US' }
  if (b.geo) node.geo = { '@type': 'GeoCoordinates', latitude: b.geo.latitude, longitude: b.geo.longitude }
  if (b.areaServed?.length) node.areaServed = b.areaServed.map((n) => ({ '@type': 'City', name: n }))
  if (b.open24h) node.openingHoursSpecification = [{ '@type': 'OpeningHoursSpecification', dayOfWeek: Object.values(DAYS), opens: '00:00', closes: '23:59' }]
  else if (b.hours) node.openingHoursSpecification = b.hours.map((h) => ({ '@type': 'OpeningHoursSpecification', dayOfWeek: h.days.map((d) => DAYS[d]), opens: h.opens, closes: h.closes }))
  if (b.sameAs?.length) node.sameAs = b.sameAs
  if (b.services?.length)
    node.hasOfferCatalog = {
      '@type': 'OfferCatalog',
      name: `${b.name} services`,
      itemListElement: b.services.map((s) => ({ '@type': 'Offer', itemOffered: { '@type': 'Service', name: s.name, ...(s.slug ? { url: url(`/${s.slug}/`) } : {}) } })),
    }
  // No aggregateRating here: Google ignores self-published review stars for local businesses, and
  // marking them up risks a manual action. Show real reviews on the page, linked to their source.
  return node
}

function schema() {
  const graph = [business(), { '@type': 'WebSite', '@id': url('#website'), url: url(), name: b.name, publisher: { '@id': url('#business') } }]
  const slug = opt('--service')
  if (slug) {
    const s = service(slug)
    graph.push({
      '@type': 'Service',
      '@id': url(`/${s.slug}/#service`),
      name: s.name,
      serviceType: s.name,
      ...(s.description ? { description: s.description } : {}),
      provider: { '@id': url('#business') },
      areaServed: (b.areaServed ?? [b.address?.addressLocality]).filter(Boolean).map((n) => ({ '@type': 'City', name: n })),
      url: url(`/${s.slug}/`),
    })
  }
  console.log(`<script type="application/ld+json">\n${JSON.stringify({ '@context': 'https://schema.org', '@graph': graph }, null, 2)}\n</script>`)
}

function meta() {
  const slug = opt('--service')
  const city = opt('--city') ?? b.areaServed?.[0] ?? b.address?.addressLocality ?? ''
  const region = b.address?.addressRegion ? `, ${b.address.addressRegion}` : ''
  const s = slug ? service(slug) : null
  const path = s ? `/${s.slug}/` : '/'
  const what = s ? s.name : (b.tagline ?? PLAIN[b.type] ?? b.type.replace(/([a-z])([A-Z])/g, '$1 $2'))
  let title = `${what} in ${city}${region} | ${b.name}`
  if (title.length > 65) title = `${what} in ${city} | ${b.name}`
  if (title.length > 65) title = `${what} | ${b.name}`
  const promise = s?.description ?? b.description ?? ''
  let description = `${promise} Call ${pretty(b.telephone)}.`.trim()
  if (description.length > 160) description = `${promise.slice(0, 160 - 22).replace(/\s+\S*$/, '')}… Call ${pretty(b.telephone)}.`
  const lines = [
    `<title>${esc(title)}</title>`,
    `<meta name="description" content="${esc(description)}">`,
    `<link rel="canonical" href="${url(path)}">`,
    `<meta property="og:type" content="website">`,
    `<meta property="og:url" content="${url(path)}">`,
    `<meta property="og:title" content="${esc(title)}">`,
    `<meta property="og:description" content="${esc(description)}">`,
    b.ogImage || b.image ? `<meta property="og:image" content="${esc(b.ogImage ?? b.image)}">` : '<!-- og:image: add "ogImage" (1200×630, absolute URL) to business.json -->',
  ]
  console.log(lines.join('\n'))
  console.error(`(title ${title.length} chars, description ${description.length} chars)`)
}

function nap() {
  const a = b.address
  const showAddr = a && b.showAddress !== false
  const html = `<address class="nap">
  <strong>${esc(b.name)}</strong><br>
${showAddr ? `  ${esc(a.streetAddress)}<br>\n  ${esc(a.addressLocality)}, ${esc(a.addressRegion)} ${esc(a.postalCode)}<br>\n` : b.areaServed?.length ? `  Serving ${esc(b.areaServed.join(', '))}<br>\n` : ''}  <a href="tel:${e164(b.telephone)}">${esc(pretty(b.telephone))}</a>${b.email ? `<br>\n  <a href="mailto:${esc(b.email)}">${esc(b.email)}</a>` : ''}${b.license ? `<br>\n  ${esc(b.license)}` : ''}
</address>`
  console.log(html)
}

function files() {
  const dir = rest.find((r) => !r.startsWith('--'))
  if (!dir || !existsSync(dir)) throw new Error('files: give the built site folder')
  const pages = []
  const walk = (d) => {
    for (const f of readdirSync(d)) {
      const p = join(d, f)
      if (f.startsWith('.') || f === 'node_modules') continue
      if (statSync(p).isDirectory()) walk(p)
      else if (f.endsWith('.html') && !/^(404|offline)\.html$/.test(f)) {
        const html = readFileSync(p, 'utf8')
        if (/<meta[^>]+name=["']robots["'][^>]+noindex/i.test(html)) continue
        const rel = relative(dir, p).replace(/\\/g, '/')
        pages.push(rel.endsWith('index.html') ? rel.slice(0, -'index.html'.length) : rel)
      }
    }
  }
  walk(dir)
  const today = new Date().toISOString().slice(0, 10)
  const sitemap = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${pages
    .sort((x, y) => x.length - y.length)
    .map((p) => `  <url><loc>${url('/' + p)}</loc><lastmod>${today}</lastmod></url>`)
    .join('\n')}\n</urlset>\n`
  writeFileSync(join(dir, 'sitemap.xml'), sitemap)
  writeFileSync(join(dir, 'robots.txt'), `User-agent: *\nAllow: /\n\nSitemap: ${url('/sitemap.xml')}\n`)
  console.log(`wrote ${join(dir, 'sitemap.xml')} (${pages.length} pages) and ${join(dir, 'robots.txt')}`)
}

// The built pages against the facts: every number, name and claim on the site must be the one in business.json.
function verify() {
  const dir = rest.find((r) => !r.startsWith('--'))
  if (!dir || !existsSync(dir)) throw new Error('verify: give the built site folder')
  const want = e164(b.telephone)
  const P = []
  const pages = []
  const walk = (d) => readdirSync(d).forEach((f) => {
    const p = join(d, f)
    if (f.startsWith('.') || f === 'node_modules') return
    if (statSync(p).isDirectory()) walk(p)
    else if (f.endsWith('.html')) pages.push(p)
  })
  walk(dir)
  for (const p of pages) {
    const html = readFileSync(p, 'utf8')
    const at = relative(dir, p)
    const text = html.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/gi, ' ').replace(/<[^>]+>/g, ' ')
    for (const [, tel] of html.matchAll(/href=["']tel:([^"']+)["']/gi)) if (e164(tel) !== want) P.push(`${at}: tel:${tel} is not ${want}`)
    for (const [, n] of text.matchAll(/(\(?\b\d{3}\)?[\s.-]?\d{3}[\s.-]\d{4}\b)/g)) if (e164(n) !== want) P.push(`${at}: shows ${n.trim()}, not ${pretty(b.telephone)}`)
    for (const [, json] of html.matchAll(/<script[^>]+application\/ld\+json[^>]*>([\s\S]*?)<\/script>/gi)) {
      let data
      try {
        data = JSON.parse(json)
      } catch {
        P.push(`${at}: a JSON-LD block doesn't parse — Google ignores all of it`)
        continue
      }
      const nodes = [data, ...(data['@graph'] ?? [])].flat()
      for (const n of nodes) {
        if (n.telephone && e164(n.telephone) !== want) P.push(`${at}: JSON-LD telephone ${n.telephone} is not ${want}`)
        if (n.aggregateRating || n.review) P.push(`${at}: JSON-LD has review stars — Google ignores self-published ratings for local businesses and can penalise them; show real reviews on the page instead`)
      }
    }
    if (!text.includes(b.name)) P.push(`${at}: the business name "${b.name}" isn't on the page`)
    if (!b.open24h && /\b24\s*\/\s*7\b|\b24 hours\b|\baround the clock\b/i.test(text)) P.push(`${at}: says 24/7 but business.json doesn't — only if dispatch really answers at 3 am`)
  }
  if (P.length) {
    console.log(`${pages.length} pages, ${P.length} to fix`)
    P.forEach((p) => console.log(`  - ${p}`))
    process.exit(1)
  }
  console.log(`${pages.length} pages agree with ${file}: one number (${pretty(b.telephone)}), the name on every page, no claims it doesn't make`)
}

const COMMANDS = { check, schema, meta, nap, files, verify }
if (!COMMANDS[cmd]) {
  console.error(`unknown command ${cmd} (have: ${Object.keys(COMMANDS).join(', ')})`)
  process.exit(2)
}
try {
  COMMANDS[cmd]()
} catch (e) {
  console.error(e.message)
  process.exit(1)
}
