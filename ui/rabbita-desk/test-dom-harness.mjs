import { JSDOM } from 'jsdom'

const voidElements = new Set(['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr'])
const booleanAttributes = new Set(['open', 'checked', 'disabled', 'selected', 'required', 'multiple', 'autofocus', 'readonly', 'hidden', 'controls', 'loop', 'muted', 'autoplay', 'async', 'defer', 'novalidate', 'formnovalidate', 'reversed', 'ismap', 'nomodule', 'allowfullscreen', 'playsinline'])
const escapeText = value => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
const escapeAttribute = value => escapeText(value).replaceAll('"', '&quot;').replaceAll("'", '&#39;')

// Serialize native DOM nodes, rather than rewriting serialized text. This keeps
// authored strings/comments intact while using canonical boolean/quote syntax.
function serializeNode(node) {
  if (node.nodeType === 3) {
    return node.parentElement?.namespaceURI === 'http://www.w3.org/1999/xhtml' &&
      ['script', 'style'].includes(node.parentElement.localName) ? node.data : escapeText(node.data)
  }
  if (node.nodeType === 8) return `<!--${node.data}-->`
  if (node.nodeType !== 1) return [...node.childNodes].map(serializeNode).join('')
  let attributes = [...node.attributes].map(attribute =>
    attribute.value === '' && booleanAttributes.has(attribute.name)
      ? ` ${attribute.name}` : ` ${attribute.name}="${escapeAttribute(attribute.value)}"`,
  ).join('')
  if (node.namespaceURI === 'http://www.w3.org/2000/svg' && node.localName === 'svg' && !node.hasAttribute('xmlns')) {
    attributes = ` xmlns="${node.namespaceURI}"${attributes}`
  }
  const opening = `<${node.localName}${attributes}>`
  const children = node.localName === 'template' && node.content ? node.content.childNodes : node.childNodes
  return node.namespaceURI === 'http://www.w3.org/1999/xhtml' && voidElements.has(node.localName)
    ? opening : `${opening}${[...children].map(serializeNode).join('')}</${node.localName}>`
}

// Snapshot real client rendering through Rabbita's supported App.mount API.
// No scripts or subresources are enabled. Each synchronous projection receives
// a fresh realm; closing it cancels the framework's pending animation frame.
export function renderWithDOM(mount, rabbitaSnapshot = false) {
  const dom = new JSDOM('<!doctype html><html><body><div id="rabbita-test-root"></div></body></html>', {
    url: 'http://localhost.test/',
    pretendToBeVisual: true,
  })
  const { window } = dom
  const root = window.document.getElementById('rabbita-test-root')
  const markers = new WeakSet()
  const createComment = window.document.createComment.bind(window.document)
  window.document.createComment = text => {
    const node = createComment(text)
    if (text === 'start' || text === 'end') markers.add(node)
    return node
  }
  const observer = new window.MutationObserver(() => {})
  const names = [
    'window', 'document', 'navigator', 'location', 'history',
    'Node', 'Element', 'HTMLElement', 'SVGElement', 'HTMLInputElement', 'HTMLTextAreaElement',
    'HTMLSelectElement', 'HTMLButtonElement', 'HTMLDialogElement',
    'Event', 'MouseEvent', 'KeyboardEvent', 'CustomEvent', 'Text',
    'DocumentFragment', 'MutationObserver', 'requestAnimationFrame',
    'cancelAnimationFrame', 'fetch',
  ].concat(Object.getOwnPropertyNames(window).filter(name => /^(?:HTML|SVG).+Element$/.test(name)))
  const previous = new Map(names.map(name => [name, Object.getOwnPropertyDescriptor(globalThis, name)]))
  try {
    for (const name of names) {
      const value = name === 'window' ? window
        : name === 'fetch' ? () => { throw new Error('DOM projection must not make network requests') }
          : name === 'requestAnimationFrame' || name === 'cancelAnimationFrame' ? window[name].bind(window)
            : window[name]
      Object.defineProperty(globalThis, name, { configurable: true, writable: true, value })
    }
    observer.observe(root, { childList: true })
    mount('rabbita-test-root')
    const records = observer.takeRecords()
    let bootstrap
    if (rabbitaSnapshot) {
      bootstrap = records[0]?.addedNodes[0]
      if (records[0]?.target !== root || records[0].addedNodes.length !== 1 ||
          bootstrap?.localName !== 'div' || bootstrap.childNodes.length !== 0) {
        throw new Error('Unsupported Rabbita mount bootstrap; projection snapshot cannot be normalized')
      }
    }
    const snapshot = root.cloneNode(true)
    const pairs = [[root, snapshot]]
    while (pairs.length > 0) {
      const [original, copy] = pairs.pop()
      if (original.localName === 'input') {
        if (original.value !== '' || original.hasAttribute('value')) copy.setAttribute('value', original.value)
        if (original.checked) copy.setAttribute('checked', '')
        else copy.removeAttribute('checked')
      } else if (original.localName === 'textarea') {
        copy.textContent = original.value
        continue
      }
      else if (original.localName === 'option') {
        if (original.selected) copy.setAttribute('selected', '')
        else copy.removeAttribute('selected')
      }
      if (original.localName === 'template' && original.content) pairs.push([original.content, copy.content])
      const originals = [...original.childNodes]
      const copies = [...copy.childNodes]
      for (let index = 0; index < originals.length; index++) {
        if (rabbitaSnapshot && (originals[index] === bootstrap || markers.has(originals[index]))) copies[index].remove()
        else pairs.push([originals[index], copies[index]])
      }
    }
    // HTML serialization omits live form properties. Reflect those real DOM
    // states into the snapshot so existing projection assertions retain them.
    // Canonical HTML notation preserves the previous assertion vocabulary,
    // while values and structure above come from the actual mounted DOM.
    return [...snapshot.childNodes].map(serializeNode).join('')
  } finally {
    observer.disconnect()
    window.close()
    for (const [name, descriptor] of previous) {
      if (descriptor) Object.defineProperty(globalThis, name, descriptor)
      else delete globalThis[name]
    }
  }
}
