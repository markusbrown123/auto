#!/usr/bin/env node
// site-audit — what a launch check would catch, measured in a real browser.
//
//   node audit.mjs <url | folder | page.html> [--pages /,/services/] [--local] [--json out.json]
//
// Loads each page twice: as a phone on a throttled connection (390×844, 4× slower CPU, slow 4G,
// roughly what Lighthouse's mobile run does) and as a desktop (1440×900). Reports:
//   seo     title, description, one h1, lang, canonical, Open Graph, noindex, JSON-LD (parsed),
//           LocalBusiness fields and NAP against the page's click-to-call (with --local)
//   speed   LCP, CLS, bytes by type, the LCP image lazy-loaded, oversized / unsized images,
//           render-blocking scripts
//   access  axe-core (WCAG 2.2 A/AA), horizontal scroll and small tap targets on the phone
//   site    robots.txt and sitemap.xml (live sites), console errors, failed requests
// Every line is FAIL, WARN or ok. Exit code 1 when anything FAILs.
//
// Zero npm install: Node 22+ and an installed Chrome/Edge/Chromium (CHROME_PATH to pick one).
// axe-core is used from ./node_modules if the project has it, else fetched once with `npm pack`
// into ~/.cache/site-audit (skip with --no-axe).
import { execFileSync } from 'node:child_process'
import { createServer } from 'node:http'
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { homedir } from 'node:os'
import { extname, join, resolve } from 'node:path'
import { Browser, sleep } from './lib/cdp.mjs'

const args = process.argv.slice(2)
const flag = (name) => args.includes(name)
const opt = (name, d) => (args.includes(name) ? args[args.indexOf(name) + 1] : d)
const target = args.find((a, i) => !a.startsWith('--') && !['--pages', '--json', '--out'].includes(args[i - 1]))
if (!target) {
  console.error('usage: node audit.mjs <url | folder | page.html> [--pages /,/about/] [--local] [--json report.json] [--no-axe] [--out .site-audit]')
  process.exit(2)
}
const LOCAL_BIZ = flag('--local')
const OUT = resolve(opt('--out', '.site-audit'))

// ---------------------------------------------------------------- serving a local build
const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.avif': 'image/avif', '.gif': 'image/gif', '.woff2': 'font/woff2', '.woff': 'font/woff', '.mp4': 'video/mp4', '.ico': 'image/x-icon', '.txt': 'text/plain', '.xml': 'application/xml' }
let server = null
async function baseUrl() {
  if (/^https?:\/\//.test(target)) return { base: target.replace(/\/?$/, '/'), live: !/localhost|127\.0\.0\.1/.test(target) }
  const p = resolve(target)
  if (!existsSync(p)) throw new Error(`no such file or folder: ${p}`)
  const root = statSync(p).isDirectory() ? p : resolve(p, '..')
  const first = statSync(p).isDirectory() ? '' : p.slice(root.length + 1)
  server = createServer((req, res) => {
    let f = join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname))
    if (!f.startsWith(root)) return res.writeHead(403).end()
    if (existsSync(f) && statSync(f).isDirectory()) f = join(f, 'index.html')
    if (!existsSync(f)) return res.writeHead(404, { 'content-type': 'text/plain' }).end('not found')
    res.writeHead(200, { 'content-type': TYPES[extname(f).toLowerCase()] ?? 'application/octet-stream' })
    res.end(readFileSync(f))
  })
  await new Promise((r) => server.listen(0, '127.0.0.1', r))
  return { base: `http://127.0.0.1:${server.address().port}/`, first, live: false }
}

// ---------------------------------------------------------------- axe-core
function axeSource() {
  if (flag('--no-axe')) return null
  try {
    return readFileSync(createRequire(join(process.cwd(), 'x.js')).resolve('axe-core/axe.min.js'), 'utf8')
  } catch {}
  const cache = join(homedir(), '.cache', 'site-audit')
  const file = join(cache, 'package', 'axe.min.js')
  if (!existsSync(file)) {
    try {
      mkdirSync(cache, { recursive: true })
      const tgz = execFileSync('npm', ['pack', 'axe-core@4', '--silent'], { cwd: cache, encoding: 'utf8', timeout: 120000 }).trim().split('\n').pop()
      execFileSync('tar', ['-xzf', tgz, 'package/axe.min.js'], { cwd: cache, timeout: 60000 })
    } catch (e) {
      console.warn(`(axe-core unavailable: ${e.message.split('\n')[0]} — accessibility rules skipped; npm i -D axe-core to fix)`)
      return null
    }
  }
  return readFileSync(file, 'utf8')
}

// ---------------------------------------------------------------- one page in one viewport
const OBSERVE = `(() => {
  const a = (window.__audit = { lcp: 0, lcpEl: null, lcpSeen: 0, cls: 0, moved: {} });
  try { new PerformanceObserver((l) => { for (const e of l.getEntries()) { a.lcp = e.startTime; a.lcpSeen = performance.now(); a.lcpEl = e.element ? (e.element.tagName + (e.element.currentSrc || e.element.src ? ' ' + (e.element.currentSrc || e.element.src).split('/').pop().slice(0, 60) : '')) : null; a.lcpLazy = e.element ? e.element.loading === 'lazy' : false; } }).observe({ type: 'largest-contentful-paint', buffered: true }); } catch {}
  const label = (n) => !n || n.nodeType !== 1 ? (n?.parentElement ? label(n.parentElement) : '?') : n.tagName.toLowerCase() + (n.id ? '#' + n.id : '') + (typeof n.className === 'string' && n.className.trim() ? '.' + n.className.trim().split(/\\s+/)[0] : '');
  try { new PerformanceObserver((l) => { for (const e of l.getEntries()) if (!e.hadRecentInput) { a.cls += e.value; for (const s of e.sources ?? []) { const k = label(s.node); a.moved[k] = (a.moved[k] ?? 0) + e.value; } } }).observe({ type: 'layout-shift', buffered: true }); } catch {}
})();`

async function visit(browser, url, { mobile }) {
  const page = await browser.newPage(mobile ? { width: 390, height: 844, dsf: 3, mobile: true } : { width: 1440, height: 900, dsf: 1 })
  const net = new Map()
  const failed = []
  const S = page.sessionId
  const inflight = new Set()
  let lastNet = Date.now()
  const done = (id) => (inflight.delete(id), (lastNet = Date.now()))
  browser.on(S, 'Network.requestWillBeSent', (p) => (inflight.add(p.requestId), (lastNet = Date.now())))
  browser.on(S, 'Network.responseReceived', (p) => net.set(p.requestId, { url: p.response.url, type: p.type, status: p.response.status, bytes: 0 }))
  browser.on(S, 'Network.loadingFinished', (p) => (net.has(p.requestId) && (net.get(p.requestId).bytes = p.encodedDataLength), done(p.requestId)))
  browser.on(S, 'Network.loadingFailed', (p) => (!p.canceled && failed.push(`${p.errorText} ${net.get(p.requestId)?.url ?? ''}`.trim()), done(p.requestId)))
  await page.send('Network.enable')
  await page.send('Network.setCacheDisabled', { cacheDisabled: true })
  if (mobile) {
    // Lighthouse's mobile defaults, near enough: 4× CPU, 150 ms RTT, 1.6 Mbps down.
    await page.send('Emulation.setCPUThrottlingRate', { rate: 4 })
    await page.send('Network.emulateNetworkConditions', { offline: false, latency: 150, downloadThroughput: (1.6 * 1024 * 1024) / 8, uploadThroughput: (750 * 1024) / 8 })
  }
  await page.send('Page.addScriptToEvaluateOnNewDocument', { source: OBSERVE })
  const t0 = Date.now()
  const how = await page.goto(url, { timeoutMs: 45000, settleMs: 500 })
  const loadMs = Date.now() - t0
  // Lazy images on the first screen, read now: a slider may have moved on by the time the page is quiet.
  const lazyTop = await page.eval(`[...document.images].filter((i) => { const r = i.getBoundingClientRect(); return i.loading === 'lazy' && r.top < innerHeight && r.bottom > 0 && r.width > 1 && (i.checkVisibility?.({ opacityProperty: true, visibilityProperty: true }) ?? true) }).map((i) => (i.currentSrc || i.src).split('/').pop().slice(0, 60))`).catch(() => [])
  // A throttled phone can paint the biggest thing long after the load event, so wait until the
  // network has been idle for a second and LCP hasn't changed for two (at most 25 s), then read.
  for (const until = Date.now() + 25000; Date.now() < until; await sleep(250)) {
    const a = await page.eval('({ lcp: __audit.lcp, quiet: performance.now() - __audit.lcpSeen })').catch(() => null)
    if (a && a.lcp > 0 && a.quiet > 2000 && inflight.size === 0 && Date.now() - lastNet > 1000) break
  }
  const dom = await page.eval(collect, { mobile })
  for (const r of net.values()) if (r.status >= 400) failed.push(`${r.status} ${r.url}`)
  const bytes = {}
  for (const r of net.values()) {
    const k = { Script: 'js', Stylesheet: 'css', Image: 'images', Font: 'fonts', Document: 'html', Media: 'media' }[r.type] ?? 'other'
    bytes[k] = (bytes[k] ?? 0) + r.bytes
  }
  bytes.total = Object.values(bytes).reduce((a, b) => a + b, 0)
  return { page, how, loadMs, lazyTop, dom, bytes, failed, consoleErrors: page.consoleErrors, requests: net.size }
}

// Runs in the page.
function collect({ mobile }) {
  const q = (s) => document.querySelector(s)
  const all = (s) => [...document.querySelectorAll(s)]
  const meta = (n) => q(`meta[name="${n}"]`)?.content ?? q(`meta[property="${n}"]`)?.content ?? null
  const vw = innerWidth
  const vh = innerHeight
  const visible = (el) => {
    const r = el.getBoundingClientRect()
    const s = getComputedStyle(el)
    // Off-screen, see-through or 1-px things (skip links, trap fields for bots) aren't for tapping.
    return r.width > 1 && r.height > 1 && r.right > 0 && r.left < innerWidth && s.visibility !== 'hidden' && s.display !== 'none' && Number(s.opacity) > 0.05 && (el.checkVisibility?.({ opacityProperty: true, visibilityProperty: true }) ?? true)
  }
  const ld = all('script[type="application/ld+json"]').map((s) => {
    try {
      return { ok: true, data: JSON.parse(s.textContent) }
    } catch (e) {
      return { ok: false, error: String(e.message).slice(0, 120) }
    }
  })
  const tels = all('a[href^="tel:"]').map((a) => {
    const r = a.getBoundingClientRect()
    return { digits: a.getAttribute('href').replace(/\D/g, '').replace(/^1(?=\d{10}$)/, ''), aboveFold: visible(a) && r.top < vh && r.bottom > 0 }
  })
  const imgs = all('img').map((i) => {
    const r = i.getBoundingClientRect()
    return {
      src: (i.currentSrc || i.src).split('/').pop().slice(0, 60),
      alt: i.hasAttribute('alt'),
      sized: i.hasAttribute('width') && i.hasAttribute('height'),
      lazy: i.loading === 'lazy',
      natural: i.naturalWidth,
      shown: Math.round(r.width),
      belowFold: r.top > vh * 1.2,
      firstScreen: r.top < vh && r.bottom > 0,
      visible: visible(i),
    }
  })
  const blocking = all('head script[src]').filter((s) => !s.defer && !s.async && s.type !== 'module').map((s) => s.src.split('/').pop())
  // Tap targets under 24px (WCAG 2.2 2.5.8), not counting links inside running text.
  const name = (el) => `${el.tagName.toLowerCase()}${el.id ? '#' + el.id : ''}${el.className && typeof el.className === 'string' ? '.' + el.className.trim().split(/\s+/)[0] : ''} "${(el.textContent || el.getAttribute('aria-label') || '').trim().slice(0, 24)}"`
  const small = mobile
    ? all('a[href], button, input:not([type=hidden]), select, textarea, summary, [role=button]')
        .filter((el) => {
          if (!visible(el)) return false
          const r = el.getBoundingClientRect()
          if (r.width >= 24 && r.height >= 24) return false
          return !(el.tagName === 'A' && el.closest('p, li') && getComputedStyle(el).display === 'inline')
        })
        .map(name)
    : []
  return {
    title: document.title,
    description: meta('description'),
    h1: all('h1').filter(visible).length,
    lang: document.documentElement.lang,
    viewport: meta('viewport'),
    canonical: q('link[rel="canonical"]')?.href ?? null,
    robots: meta('robots'),
    og: { title: meta('og:title'), description: meta('og:description'), image: meta('og:image') },
    ld,
    tels,
    imgs,
    blocking,
    stylesheets: all('link[rel="stylesheet"]').length,
    overflow: document.documentElement.scrollWidth > vw + 1,
    small,
    audit: window.__audit ?? {},
  }
}

// ---------------------------------------------------------------- the rules
const LOCAL_TYPES = /^(LocalBusiness|HomeAndConstructionBusiness|Plumber|Electrician|HVACBusiness|RoofingContractor|HousePainter|Locksmith|GeneralContractor|MovingCompany|ProfessionalService|AutomotiveBusiness|AutoRepair|EmergencyService|RealEstateAgent|Dentist|LegalService|Attorney|HealthAndBeautyBusiness|FoodEstablishment|Restaurant|Store|LodgingBusiness|SportsActivityLocation)$/
const kb = (n) => `${Math.round(n / 1024)} KB`

function flatLd(ld) {
  const out = []
  const walk = (n) => {
    if (Array.isArray(n)) return n.forEach(walk)
    if (n && typeof n === 'object') {
      if (n['@type']) out.push(n)
      if (n['@graph']) walk(n['@graph'])
    }
  }
  ld.filter((x) => x.ok).forEach((x) => walk(x.data))
  return out
}

function judge(path, m, d, live) {
  const L = []
  const add = (level, area, text) => L.push({ level, area, text })
  const x = m.dom
  // seo
  if (!x.title) add('FAIL', 'seo', 'no <title>')
  else if (x.title.length < 25 || x.title.length > 65) add('WARN', 'seo', `title is ${x.title.length} characters (aim 25–65): "${x.title.slice(0, 70)}"`)
  if (!x.description) add('FAIL', 'seo', 'no meta description')
  else if (x.description.length < 70 || x.description.length > 160) add('WARN', 'seo', `meta description is ${x.description.length} characters (aim 70–160)`)
  if (x.h1 === 0) add('FAIL', 'seo', 'no visible <h1>')
  else if (x.h1 > 1) add('WARN', 'seo', `${x.h1} visible <h1>s (one says what the page is)`)
  if (!x.lang) add('WARN', 'seo', '<html> has no lang')
  if (!x.viewport) add('FAIL', 'seo', 'no meta viewport: phones get the desktop layout shrunk')
  if (/noindex/i.test(x.robots ?? '')) add(live ? 'FAIL' : 'WARN', 'seo', `robots meta says "${x.robots}": search engines will drop this page`)
  if (!x.canonical) add('WARN', 'seo', 'no canonical link')
  const ogMissing = Object.entries(x.og).filter(([, v]) => !v).map(([k]) => `og:${k}`)
  if (ogMissing.length) add('WARN', 'seo', `no ${ogMissing.join(', ')} (link previews in texts and socials)`)
  for (const bad of x.ld.filter((l) => !l.ok)) add('FAIL', 'seo', `JSON-LD does not parse: ${bad.error}`)
  const nodes = flatLd(x.ld)
  const biz = nodes.find((n) => [].concat(n['@type']).some((t) => LOCAL_TYPES.test(t)))
  if (LOCAL_BIZ || biz) {
    if (!biz) add('FAIL', 'seo', 'no LocalBusiness JSON-LD (or a subtype such as Plumber, Electrician, HVACBusiness, RoofingContractor)')
    else {
      const need = { name: biz.name, telephone: biz.telephone, url: biz.url, 'address or areaServed': biz.address || biz.areaServed }
      const miss = Object.entries(need).filter(([, v]) => !v).map(([k]) => k)
      if (miss.length) add('WARN', 'seo', `${[].concat(biz['@type']).join('/')} JSON-LD is missing: ${miss.join(', ')}`)
      if (biz.address && typeof biz.address === 'object') {
        const a = biz.address
        const am = ['streetAddress', 'addressLocality', 'addressRegion', 'postalCode'].filter((k) => !a[k])
        if (am.length) add('WARN', 'seo', `address is missing ${am.join(', ')} (or use areaServed for a service-area business with no shopfront)`)
      }
      if (!biz.openingHoursSpecification && !biz.openingHours) add('WARN', 'seo', 'no opening hours in the JSON-LD')
      const ldPhone = String(biz.telephone ?? '').replace(/\D/g, '').replace(/^1(?=\d{10}$)/, '')
      if (ldPhone && x.tels.length && !x.tels.some((t) => t.digits === ldPhone)) add('WARN', 'seo', `the JSON-LD telephone (${biz.telephone}) doesn't match any click-to-call link: keep name, address and phone identical everywhere`)
    }
    if (d === 'mobile') {
      if (!x.tels.length) add('FAIL', 'seo', 'no click-to-call (tel:) link: on a phone the call is the conversion')
      else if (!x.tels.some((t) => t.aboveFold)) add('WARN', 'seo', 'no click-to-call link on the first phone screen')
    }
  }
  // speed (judged on the throttled phone load; the desktop one is reported)
  if (d === 'mobile') {
    const lcp = Math.round(x.audit.lcp ?? 0)
    if (!lcp) add('WARN', 'speed', 'no LCP within 25 s: nothing on the first screen counted as painted (everything fades in from opacity 0, or the page stayed blank). Lighthouse reports NO_LCP and Google can\'t score the page; show the hero text and image without a fade from 0')
    else add(lcp > 4000 ? 'FAIL' : lcp > 2500 ? 'WARN' : 'ok', 'speed', `LCP ${(lcp / 1000).toFixed(2)} s on a throttled phone (good ≤ 2.5 s)${x.audit.lcpEl ? ` — ${x.audit.lcpEl}` : ''}`)
    if (x.audit.lcpLazy || m.lazyTop.length) add('FAIL', 'speed', `first-screen image(s) set to loading="lazy" — they load last instead of first: ${m.lazyTop.slice(0, 3).join(', ') || x.audit.lcpEl}`)
    const cls = Number((x.audit.cls ?? 0).toFixed(3))
    const moved = Object.entries(x.audit.moved ?? {}).sort((p, q) => q[1] - p[1]).slice(0, 3).map(([k]) => k)
    add(cls > 0.25 ? 'FAIL' : cls > 0.1 ? 'WARN' : 'ok', 'speed', `CLS ${cls} (good ≤ 0.1)${cls > 0.1 && moved.length ? ` — moved: ${moved.join(', ')}` : ''}`)
    const b = m.bytes
    add(b.total > 3e6 ? 'FAIL' : b.total > 1.5e6 ? 'WARN' : 'ok', 'speed', `${kb(b.total)} over ${m.requests} requests (js ${kb(b.js ?? 0)}, css ${kb(b.css ?? 0)}, images ${kb(b.images ?? 0)}, fonts ${kb(b.fonts ?? 0)}, media ${kb(b.media ?? 0)})`)
    if ((b.js ?? 0) > 300 * 1024) add('WARN', 'speed', `${kb(b.js)} of JavaScript (aim under 300 KB for a brochure site)`)
    if (x.blocking.length) add('WARN', 'speed', `render-blocking scripts in <head> (add defer): ${x.blocking.slice(0, 4).join(', ')}`)
    const unsized = x.imgs.filter((i) => i.visible && !i.sized)
    if (unsized.length) add('WARN', 'speed', `${unsized.length} image(s) without width and height (layout shift): ${unsized.slice(0, 3).map((i) => i.src).join(', ')}`)
    const big = x.imgs.filter((i) => i.visible && i.natural && i.shown && i.natural > i.shown * 3 * 1.5)
    if (big.length) add('WARN', 'speed', `${big.length} image(s) much larger than shown on a phone: ${big.slice(0, 3).map((i) => `${i.src} ${i.natural}px for ${i.shown}px`).join(', ')}`)
    const eager = x.imgs.filter((i) => i.belowFold && !i.lazy)
    if (eager.length > 2) add('WARN', 'speed', `${eager.length} below-the-fold images without loading="lazy"`)
  }
  // access
  if (d === 'mobile' && x.overflow) add('FAIL', 'access', 'the page scrolls sideways on a 390 px phone')
  if (d === 'mobile' && x.small.length) add('WARN', 'access', `${x.small.length} tap target(s) under 24×24 px on the phone: ${x.small.slice(0, 3).join(', ')}`)
  const noAlt = x.imgs.filter((i) => !i.alt)
  if (noAlt.length) add('FAIL', 'access', `${noAlt.length} <img> without alt: ${noAlt.slice(0, 3).map((i) => i.src).join(', ')}`)
  for (const v of m.axe ?? []) add(['critical', 'serious'].includes(v.impact) ? 'FAIL' : 'WARN', 'access', `axe ${v.id} (${v.impact}) ×${v.nodes}: ${v.help} — e.g. ${v.target}`)
  // site
  for (const f of [...new Set(m.failed)].slice(0, 6)) {
    if (/\/favicon\.ico$/.test(f)) add('WARN', 'site', 'no favicon (browsers ask for /favicon.ico; add one or a <link rel="icon">)')
    else add(/^[45]\d\d /.test(f) ? 'FAIL' : 'WARN', 'site', `request failed: ${f.slice(0, 140)}`)
  }
  for (const e of [...new Set(m.consoleErrors)].slice(0, 4)) add('WARN', 'site', `script error: ${e.split('\n')[0]}`)
  if (m.how === 'timeout') add('WARN', 'site', 'the load event never fired within 45 s')
  return L
}

async function runAxe(page, src) {
  if (!src) return null
  await page.eval(src + ';0')
  const res = await page.eval(`axe.run(document, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'] }, resultTypes: ['violations'] }).then(r => r.violations.map(v => ({ id: v.id, impact: v.impact, help: v.help, nodes: v.nodes.length, target: String(v.nodes[0]?.target?.[0] ?? '').slice(0, 80) })))`)
  return res
}

async function siteFiles(base) {
  const out = []
  for (const f of ['robots.txt', 'sitemap.xml']) {
    try {
      const r = await fetch(new URL('/' + f, base), { redirect: 'follow', signal: AbortSignal.timeout(15000) })
      const text = r.ok ? await r.text() : ''
      if (!r.ok) out.push({ level: 'WARN', area: 'site', text: `no /${f} (${r.status})` })
      else if (f === 'robots.txt' && /^\s*disallow:\s*\/\s*$/im.test(text) && /user-agent:\s*\*/i.test(text)) out.push({ level: 'FAIL', area: 'site', text: 'robots.txt disallows everything' })
      else out.push({ level: 'ok', area: 'site', text: `/${f} present` })
    } catch (e) {
      out.push({ level: 'WARN', area: 'site', text: `couldn't fetch /${f}: ${e.message}` })
    }
  }
  return out
}

// ---------------------------------------------------------------- main
const { base, first = '', live } = await baseUrl()
const pages = (opt('--pages', '') || '/' + first).split(',').map((p) => p.trim()).filter(Boolean)
const axe = axeSource()
mkdirSync(OUT, { recursive: true })
const browser = await Browser.launch({})
const report = { target, at: new Date().toISOString(), pages: [] }
let fails = 0
try {
  if (live) report.site = await siteFiles(base)
  for (const p of pages) {
    const url = new URL(p.replace(/^\//, ''), base).href
    const entry = { path: p, url, lines: [] }
    for (const d of ['mobile', 'desktop']) {
      const m = await visit(browser, url, { mobile: d === 'mobile' })
      if (d === 'mobile') m.axe = await runAxe(m.page, axe).catch((e) => (console.warn('(axe failed:', e.message.split('\n')[0] + ')'), null))
      const name = p.replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '') || 'home'
      const shot = join(OUT, `${name}-${d}.jpg`)
      await m.page.screenshot({ path: shot })
      if (d === 'mobile') writeFileSync(join(OUT, `${name}.html`), '<!doctype html>\n' + (await m.page.eval('document.documentElement.outerHTML')))
      entry[d] = { loadMs: m.loadMs, bytes: m.bytes, lcp: Math.round(m.dom.audit.lcp ?? 0), cls: Number((m.dom.audit.cls ?? 0).toFixed(3)), screenshot: shot }
      // The page-level rules once (from the phone); the desktop pass adds only what differs.
      const lines = judge(p, m, d, live).filter((l) => d === 'mobile' || l.area === 'site')
      entry.lines.push(...lines.map((l) => ({ ...l, view: d })))
      await m.page.close()
    }
    entry.lines = entry.lines.filter((l, i, a) => a.findIndex((o) => o.text === l.text) === i)
    report.pages.push(entry)
  }
} finally {
  await browser.close()
  server?.close()
}

// ---------------------------------------------------------------- print
const order = { FAIL: 0, WARN: 1, ok: 2 }
const paint = { FAIL: '\x1b[31mFAIL\x1b[0m', WARN: '\x1b[33mWARN\x1b[0m', ok: '\x1b[32m ok \x1b[0m' }
console.log(`SITE AUDIT  ${target}${axe ? '' : '  (no axe-core)'}\n`)
for (const s of report.site ?? []) {
  if (s.level === 'FAIL') fails++
  console.log(`${paint[s.level]}  site    ${s.text}`)
}
for (const e of report.pages) {
  console.log(`\n${e.path}  — phone: LCP ${(e.mobile.lcp / 1000).toFixed(2)} s, CLS ${e.mobile.cls}, ${kb(e.mobile.bytes.total)}; desktop: LCP ${(e.desktop.lcp / 1000).toFixed(2)} s`)
  for (const l of [...e.lines].sort((a, b) => order[a.level] - order[b.level])) {
    if (l.level === 'FAIL') fails++
    console.log(`${paint[l.level]}  ${l.area.padEnd(6)}  ${l.text}`)
  }
  console.log(`      screenshots: ${e.mobile.screenshot}, ${e.desktop.screenshot}`)
}
const warns = report.pages.flatMap((e) => e.lines).filter((l) => l.level === 'WARN').length + (report.site ?? []).filter((l) => l.level === 'WARN').length
console.log(`\nRESULT: ${fails} FAIL, ${warns} WARN${fails ? ' — fix the FAILs before launch' : ''}`)
if (opt('--json')) writeFileSync(opt('--json'), JSON.stringify(report, null, 2))
await sleep(10)
process.exit(fails ? 1 : 0)
