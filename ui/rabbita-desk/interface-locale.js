import english from '../../locales/en-US.json'
import chinese from '../../locales/zh-Hans.json'

// Compile catalogs with the app so a release cannot ship stale translations.
const catalogs = { 'en-US': english, 'zh-Hans': chinese }
const zhHans = Object.fromEntries(Object.keys(english).map(key => [english[key], chinese[key]]))
const COOKIE = 'moonsuite_interface_locale'
const STORAGE = 'moonsuite.interfaceLocale'
const WINDOW_NAME_PREFIX = 'moonsuite-locale:'
const validPreferences = new Set(['system', 'en-US', 'zh-Hans'])
const attributes = ['placeholder', 'title', 'aria-label', 'data-tooltip']
const keyedSelector = ['[data-i18n]', ...attributes.map(attribute => `[data-i18n-${attribute}]`)].join(',')
// Documents, messages, names and paths belong to the user, even when they
// happen to equal a UI label such as "Review" or "Ready".
const contentSelector = [
  '[data-i18n-scope="content"]', '[data-i18n-scope="technical"]', '[translate="no"]',
  'script', 'style', 'code', 'pre', '[contenteditable="true"]',
  '.office-supported-preview', '.document-preview', '.markdown-body', '.chat-message-content',
  '.mooncode-message-body', '.wiki-chat-message > p',
  '.mooncode-message-content', '.mooncode-transcript-content',
  '.work-book-option',
  '.desk-workspace-name', '.desk-entry-name', '.desk-workspace-row strong', '.pack-card-identity h2',
  '.desk-file-name:not([data-i18n-scope="interface"])', '.folder-label:not([data-i18n-scope="interface"])', '.mooncode-session strong',
  '.wiki-chat-header h2:not([data-i18n-scope="interface"])', '.wiki-viewer-header h2:not([data-i18n-scope="interface"])',
  'select[name="skill-file"] option', '[data-mooncode-control="model"] option', '.xterm',
  '.coding-setup-presets strong', '.coding-setup-presets article > div > p',
  '.coding-setup-knowledge-hit strong', '.coding-setup-knowledge-hit > p',
].join(',')

function normalizedPreference(value) { return validPreferences.has(value) ? value : null }
function selectedPreference() {
  const query = normalizedPreference(new URLSearchParams(location.search).get('locale'))
  const cookie = document.cookie.match(new RegExp('(?:^|; )' + COOKIE + '=([^;]+)'))
  const name = window.name.startsWith(WINDOW_NAME_PREFIX) ? window.name.slice(WINDOW_NAME_PREFIX.length) : null
  return query || (cookie && normalizedPreference(decodeURIComponent(cookie[1]))) ||
    normalizedPreference(name) || normalizedPreference(localStorage.getItem(STORAGE)) || 'system'
}
function selectedLocale() {
  const preference = selectedPreference()
  const raw = preference === 'system' ? navigator.languages?.[0] || navigator.language || 'en-US' : preference
  return /^(zh(?:-|_)(?:Hans|CN|SG)|zh$)/i.test(raw) ? 'zh-Hans' : 'en-US'
}
function storeLocale(preference) {
  preference = normalizedPreference(preference) || 'system'
  document.cookie = COOKIE + '=' + encodeURIComponent(preference) + '; Path=/; Max-Age=31536000; SameSite=Lax'
  localStorage.setItem(STORAGE, preference)
  window.name = WINDOW_NAME_PREFIX + preference
  // An explicit choice must override a locale used in a shared/preview URL.
  const url = new URL(location.href)
  url.searchParams.delete('locale')
  history.replaceState(history.state, '', url)
  location.reload()
}
function formatMessage(template, params = {}) {
  return template.replace(/\{([A-Za-z][A-Za-z0-9_]*)\}/g, (match, name) =>
    Object.prototype.hasOwnProperty.call(params, name) ? String(params[name]) : match)
}
function message(key, params = {}) {
  return formatMessage(catalogs[selectedLocale()]?.[key] ?? english[key] ?? key, params)
}
function compileTemplate(source, target) {
  const names = []
  let cursor = 0, pattern = '^'
  const escape = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const numeric = new Set(['count', 'selected', 'total', 'items', 'folders', 'files', 'ran', 'failed', 'ready', 'installed'])
  for (const match of source.matchAll(/\{([A-Za-z][A-Za-z0-9_]*)\}/g)) {
    pattern += escape(source.slice(cursor, match.index)) + (numeric.has(match[1]) ? '([0-9]+)' : '(.+?)')
    names.push(match[1]); cursor = match.index + match[0].length
  }
  return { regex: new RegExp(pattern + escape(source.slice(cursor)) + '$'), names, target }
}
const templates = Object.keys(english)
  .filter(key => key !== 'pack.open_app' && /\{[A-Za-z][A-Za-z0-9_]*\}/.test(english[key]))
  // Match specific sentences before a shorter generic action template.
  .sort((a, b) => english[b].replace(/\{[^}]+\}/g, '').length - english[a].replace(/\{[^}]+\}/g, '').length)
  .map(key => compileTemplate(english[key], chinese[key]))
function translateText(text) {
  const leading = text.match(/^\s*/)?.[0] || '', trailing = text.match(/\s*$/)?.[0] || ''
  const core = text.slice(leading.length, text.length - trailing.length)
  if (Object.hasOwn(zhHans, core)) return leading + zhHans[core] + trailing
  for (const template of templates) {
    const match = core.match(template.regex)
    if (match) return leading + formatMessage(template.target,
      Object.fromEntries(template.names.map((name, index) => [name, match[index + 1]]))) + trailing
  }
  return text
}
function translateAttribute(text) { return translateText(text) }
function translateKeyedElement(element) {
  if (element.tagName === 'OPTION' && !element.hasAttribute('value')) element.value = element.textContent
  let params = {}
  try { params = JSON.parse(element.getAttribute('data-i18n-params') || '{}') } catch {}
  const key = element.getAttribute('data-i18n')
  if (key && Object.hasOwn(english, key)) {
    const value = message(key, params)
    if (element.textContent !== value) element.textContent = value
  }
  for (const attribute of attributes) {
    const key = element.getAttribute('data-i18n-' + attribute)
    if (!key || !Object.hasOwn(english, key)) continue
    const value = message(key, params)
    if (element.getAttribute(attribute) !== value) element.setAttribute(attribute, value)
  }
}
function translate(root) {
  if (root.closest?.(contentSelector)) return
  for (const element of [root, ...root.querySelectorAll?.(keyedSelector) || []]) {
    if (element.matches?.(keyedSelector) && !element.closest(contentSelector)) translateKeyedElement(element)
  }
  if (selectedLocale() !== 'zh-Hans') return
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
    acceptNode: node => /\S/.test(node.nodeValue || '') &&
      !node.parentElement?.closest(contentSelector + ',textarea,[data-i18n]:not([data-i18n=""])') ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT,
  })
  const nodes = []
  while (walker.nextNode()) nodes.push(walker.currentNode)
  for (const node of nodes) {
    const value = translateText(node.nodeValue)
    if (node.nodeValue !== value) {
      const parent = node.parentElement
      if (parent?.tagName === 'OPTION' && !parent.hasAttribute('value')) parent.value = parent.textContent
      node.nodeValue = value
    }
  }
  const selector = attributes.map(attribute => `[${attribute}]`).join(',')
  for (const element of [root, ...root.querySelectorAll?.(selector) || []]) {
    if (!element.getAttribute || element.closest(contentSelector)) continue
    for (const attribute of attributes) {
      if (!element.hasAttribute(attribute) || element.hasAttribute('data-i18n-' + attribute)) continue
      if (element.getAttribute('data-i18n-preserve')?.split(/\s+/).includes(attribute)) continue
      const value = translateAttribute(element.getAttribute(attribute))
      if (element.getAttribute(attribute) !== value) element.setAttribute(attribute, value)
    }
  }
}
let languageControl
function mountSelector() {
  const host = document.querySelector('.work-tools-options')
  if (host && languageControl && languageControl.parentElement !== host) host.append(languageControl)
}
function installSelector() {
  if (document.getElementById('moonsuite-language')) return
  const label = document.createElement('label')
  label.id = 'moonsuite-language'
  const title = selectedLocale() === 'zh-Hans' ? '界面语言' : 'Interface language'
  label.setAttribute('aria-label', title)
  const caption = document.createElement('span'); caption.textContent = title; label.append(caption)
  const select = document.createElement('select')
  select.setAttribute('aria-label', title)
  for (const [value, text] of [['system', selectedLocale() === 'zh-Hans' ? '系统语言' : 'System language'], ['en-US', 'English'], ['zh-Hans', '简体中文']]) {
    const option = document.createElement('option'); option.value = value; option.textContent = text; select.append(option)
  }
  select.value = selectedPreference()
  select.addEventListener('change', () => storeLocale(select.value))
  label.append(select); languageControl = label; document.body.append(label); mountSelector()
}
function boot() {
  document.documentElement.lang = selectedLocale()
  document.documentElement.dir = 'ltr'
  window.name = WINDOW_NAME_PREFIX + selectedPreference()
  translate(document.body)
  installSelector()
  new MutationObserver(records => {
    const roots = new Set()
    for (const record of records) {
      if (record.type === 'childList') for (const node of record.addedNodes) {
        if (node.nodeType === Node.ELEMENT_NODE) roots.add(node)
        else if (node.nodeType === Node.TEXT_NODE && node.parentElement) roots.add(node.parentElement)
      }
      if (record.type === 'characterData' && record.target.parentElement) roots.add(record.target.parentElement)
      if (record.type === 'attributes') roots.add(record.target)
    }
    for (const root of roots) if (root.isConnected) translate(root)
    mountSelector()
  }).observe(document.body, {
    childList: true, characterData: true, attributes: true, subtree: true,
    attributeFilter: [...attributes, 'data-i18n', 'data-i18n-params', 'data-i18n-preserve', ...attributes.map(attribute => 'data-i18n-' + attribute)],
  })
}
window.MoonSuiteI18n = Object.freeze({ locale: selectedLocale, preference: selectedPreference, message, translate,
  text: value => selectedLocale() === 'zh-Hans' ? translateText(value) : value })
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot, { once: true })
else boot()
