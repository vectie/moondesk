// Runtime views can localize individual parts of a composite status without
// translating task names, model IDs, paths or response content.
export const uiText = value => globalThis.window?.MoonSuiteI18n?.text?.(String(value)) ?? String(value)
export const uiLocale = () => globalThis.window?.MoonSuiteI18n?.locale?.() || undefined
export function setUiText(node, text) {
  const value = uiText(text)
  if (node && node.textContent !== value) node.textContent = value
}
export function userContent(node) {
  node.setAttribute('data-i18n-scope', 'content')
  return node
}
