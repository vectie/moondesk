// Platform-hosted MoonDesk shares an origin with other products. Keep every
// browser request owned by this app below its named path without changing
// standalone, root-mounted development builds.
(() => {
  const script = document.currentScript
  const path = script ? new URL(script.src, location.href).pathname : ''
  const base = path.endsWith('/platform-base.js')
    ? path.slice(0, -'/platform-base.js'.length)
    : ''
  if (!base) return

  const otherProducts = ['/mana', '/user', '/docs', '/moonrobo', '/comfyui', '/moontown']
  const rewrite = input => {
    const url = new URL(input, location.href)
    const sameOrigin = url.host === location.host && (
      url.protocol === location.protocol ||
      (location.protocol === 'https:' && url.protocol === 'wss:') ||
      (location.protocol === 'http:' && url.protocol === 'ws:')
    )
    if (!sameOrigin || !url.pathname.startsWith('/')) return input
    if (url.pathname === base || url.pathname.startsWith(`${base}/`)) return input
    if (otherProducts.some(prefix => url.pathname === prefix || url.pathname.startsWith(`${prefix}/`))) return input
    url.pathname = `${base}${url.pathname}`
    return url.href
  }

  const originalFetch = globalThis.fetch.bind(globalThis)
  globalThis.fetch = (input, init) => {
    if (input instanceof Request) {
      const target = rewrite(input.url)
      return originalFetch(target === input.url ? input : new Request(target, input), init)
    }
    return originalFetch(rewrite(input), init)
  }

  const NativeWebSocket = globalThis.WebSocket
  if (NativeWebSocket) {
    globalThis.WebSocket = class extends NativeWebSocket {
      constructor(url, protocols) {
        super(rewrite(url), protocols)
      }
    }
  }

  const NativeEventSource = globalThis.EventSource
  if (NativeEventSource) {
    globalThis.EventSource = class extends NativeEventSource {
      constructor(url, options) {
        super(rewrite(url), options)
      }
    }
  }

  const urlAttributes = new Set(['href', 'src', 'action', 'poster'])
  const originalSetAttribute = Element.prototype.setAttribute
  Element.prototype.setAttribute = function (name, value) {
    return originalSetAttribute.call(
      this,
      name,
      urlAttributes.has(String(name).toLowerCase()) ? rewrite(String(value)) : value,
    )
  }

  // Rabbita can set URL properties directly rather than calling setAttribute.
  for (const [constructor, property] of [
    [globalThis.HTMLAnchorElement, 'href'],
    [globalThis.HTMLImageElement, 'src'],
    [globalThis.HTMLIFrameElement, 'src'],
    [globalThis.HTMLFormElement, 'action'],
  ]) {
    if (!constructor) continue
    const descriptor = Object.getOwnPropertyDescriptor(constructor.prototype, property)
    if (!descriptor?.set) continue
    Object.defineProperty(constructor.prototype, property, {
      ...descriptor,
      set(value) { descriptor.set.call(this, rewrite(String(value))) },
    })
  }

  globalThis.__MOONDESK_BASE_PATH = base
  globalThis.__MOONDESK_REWRITE_URL = rewrite
})()
