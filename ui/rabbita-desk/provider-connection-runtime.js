import jsQR from 'jsqr'
import { connectedWorkspaceUrl } from './provider-handoff-runtime.js'

export function parseProviderConnection(text) {
  if (typeof text !== 'string' || new TextEncoder().encode(text).length > 8192) throw new Error('Invalid connection settings.')
  let value
  try { value = JSON.parse(text) } catch { throw new Error('Invalid connection settings.') }
  if (!value || value.version !== 'openai.connection.v1' || value.api !== 'chat.completions') throw new Error('Unsupported connection format.')
  if (typeof value.base_url !== 'string' || value.base_url.length > 2048 || /[\s\\?#@]/.test(value.base_url)) throw new Error('Invalid provider URL.')
  let url
  try { url = new URL(value.base_url) } catch { throw new Error('Invalid provider URL.') }
  const loopback = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname)
  if (url.protocol !== 'https:' && !(url.protocol === 'http:' && loopback)) throw new Error('Use HTTPS for a remote provider.')
  if (url.username || url.password || /\/chat\/completions\/?$/.test(url.pathname)) throw new Error('Use the API base URL.')
  if (typeof value.api_key !== 'string' || !/^[\x21-\x7e]{1,512}$/.test(value.api_key) || value.api_key.startsWith('api-key-')) throw new Error('Use an API secret, not a key record ID.')
  if (typeof value.model !== 'string' || !/^[\x21-\x7e]{1,256}$/.test(value.model)) throw new Error('Invalid model ID.')
  if (!Number.isInteger(value.max_output_tokens) || value.max_output_tokens < 1 || value.max_output_tokens > 131072) throw new Error('Invalid output limit.')
  return { version: value.version, api: value.api, base_url: value.base_url.replace(/\/$/, ''), api_key: value.api_key, model: value.model, max_output_tokens: value.max_output_tokens }
}

export function providerConnectionRequest(value) {
  const settings = parseProviderConnection(JSON.stringify(value))
  return { method: 'POST', credentials: 'same-origin', cache: 'no-store', redirect: 'error', headers: { 'Content-Type': 'application/json', Accept: 'application/json' }, body: JSON.stringify(settings) }
}

export function decodeProviderConnection(imageData) {
  const decoded = jsQR(imageData.data, imageData.width, imageData.height, { inversionAttempts: 'dontInvert' })
  return decoded ? parseProviderConnection(decoded.data) : null
}

export const connectionPreview = value => ({ base_url: value.base_url, model: value.model, max_output_tokens: value.max_output_tokens, api_key: '••••••••' })
let currentDialog = null
const t = (english, chinese) => document.documentElement.lang.startsWith('zh') ? chinese : english
function node(tag, text) { const result = document.createElement(tag); if (text) result.textContent = text; return result }

export function openProviderConnection() {
  if (currentDialog) { currentDialog.focus(); return }
  const trigger = document.activeElement
  const dialog = node('dialog'); dialog.className = 'provider-connection-dialog'; dialog.setAttribute('aria-labelledby', 'provider-connection-title')
  const title = node('h2', t('Connect a model', '连接模型')); title.id = 'provider-connection-title'
  const message = node('p', t('Scan the private connection QR from your model service.', '扫描模型服务页面中的私密连接二维码。'))
  const status = node('p'); status.setAttribute('role', 'status')
  const camera = node('button', t('Use camera', '使用摄像头')); camera.type = 'button'
  const fileLabel = node('label', t('Choose QR image', '选择二维码图片'))
  const file = node('input'); file.type = 'file'; file.accept = 'image/*'; fileLabel.append(file)
  const video = node('video'); video.autoplay = true; video.playsInline = true; video.hidden = true
  const advanced = node('details'); advanced.append(node('summary', t('Paste connection settings', '粘贴连接配置')))
  const text = node('textarea'); text.maxLength = 8192; text.autocomplete = 'off'; text.setAttribute('aria-label', t('Private connection JSON', '私密连接 JSON'))
  const parse = node('button', t('Review settings', '预览配置')); parse.type = 'button'; advanced.append(text, parse)
  const preview = node('dl'); preview.hidden = true
  const privacy = node('p', t('Review the destination before connecting. Your model gateway saves the API key; QR images stay on this device.', '连接前请核对服务地址。API 密钥交由模型网关保存，二维码图片仅在本机处理。'))
  const actions = node('div'); actions.className = 'provider-connection-actions'
  const cancel = node('button', t('Cancel', '取消')); cancel.type = 'button'
  const connect = node('button', t('Connect', '连接')); connect.type = 'button'; connect.disabled = true
  actions.append(cancel, connect); dialog.append(title, message, camera, fileLabel, video, advanced, preview, privacy, status, actions)
  let candidate = null, stream = null, timer = null, closed = false, pending = false, sourceGeneration = 0
  const stopCamera = () => { clearTimeout(timer); timer = null; stream?.getTracks().forEach(track => track.stop()); stream = null; video.srcObject = null; video.hidden = true }
  const finish = () => { closed = true; sourceGeneration++; stopCamera(); candidate = null; text.value = ''; file.value = ''; currentDialog = null; dialog.remove(); window.removeEventListener('pagehide', stopCamera); if (trigger?.isConnected) trigger.focus() }
  window.addEventListener('pagehide', stopCamera)
  cancel.addEventListener('click', () => { if (!pending) dialog.close() })
  dialog.addEventListener('cancel', event => { if (pending) event.preventDefault() })
  dialog.addEventListener('close', finish, { once: true })
  const clearCandidate = () => { sourceGeneration++; candidate = null; preview.hidden = true; preview.replaceChildren(); connect.disabled = true }
  text.addEventListener('input', clearCandidate)
  const accept = value => {
    if (closed) return
    stopCamera(); candidate = value; text.value = ''; file.value = ''; preview.replaceChildren()
    for (const [label, item] of Object.entries(connectionPreview(value))) preview.append(node('dt', label), node('dd', String(item)))
    preview.hidden = false; connect.disabled = false; status.textContent = t('Ready to connect. Check the URL and model.', '可以连接，请核对地址和模型。')
  }
  const report = error => { if (!closed) { status.textContent = error.message || t('Could not read the QR code.', '无法读取二维码。'); connect.disabled = !candidate } }
  parse.addEventListener('click', () => { clearCandidate(); try { accept(parseProviderConnection(text.value)) } catch (error) { report(error) } })
  const pixels = source => {
    const width = source.videoWidth || source.width, height = source.videoHeight || source.height
    if (!width || !height) return null
    const scale = Math.min(1, 1600 / Math.max(width, height)), canvas = document.createElement('canvas')
    canvas.width = Math.max(1, Math.round(width * scale)); canvas.height = Math.max(1, Math.round(height * scale))
    const context = canvas.getContext('2d', { willReadFrequently: true }); context.drawImage(source, 0, 0, canvas.width, canvas.height)
    return context.getImageData(0, 0, canvas.width, canvas.height)
  }
  file.addEventListener('change', async () => {
    const image = file.files?.[0]
    if (!image) return
    clearCandidate(); stopCamera()
    const generation = sourceGeneration
    if (image.size > 10 * 1024 * 1024) { report(new Error(t('Choose an image smaller than 10 MiB.', '请选择小于 10 MiB 的图片。'))); return }
    let bitmap
    try { bitmap = await createImageBitmap(image); if (closed || generation !== sourceGeneration) return; const value = decodeProviderConnection(pixels(bitmap)); if (!value) throw new Error(t('No connection QR found.', '未找到连接二维码。')); accept(value) }
    catch (error) { report(error) } finally { bitmap?.close(); file.value = '' }
  })
  camera.addEventListener('click', async () => {
    stopCamera(); clearCandidate()
    const generation = sourceGeneration
    try {
      const capture = await navigator.mediaDevices.getUserMedia({ audio: false, video: { facingMode: { ideal: 'environment' }, width: { ideal: 640 } } })
      if (closed || generation !== sourceGeneration) { capture.getTracks().forEach(track => track.stop()); return }
      stream = capture; video.srcObject = capture; video.hidden = false; await video.play()
      const scan = () => {
        if (closed || generation !== sourceGeneration || !stream) return
        try { const image = pixels(video); const value = image && decodeProviderConnection(image); if (value) { accept(value); return } } catch (error) { report(error); stopCamera(); return }
        timer = setTimeout(scan, 250)
      }
      scan()
    } catch { report(new Error(t('Camera unavailable. Choose a QR image or paste settings.', '摄像头不可用，请选择二维码图片或粘贴配置。'))) }
  })
  connect.addEventListener('click', async () => {
    if (!candidate || pending) return
    pending = true; stopCamera(); connect.disabled = true; cancel.disabled = true; camera.disabled = true; file.disabled = true; parse.disabled = true
    status.textContent = t('Verifying and connecting…', '正在验证并连接…')
    try {
      const response = await fetch('/api/desktop/provider-connection', providerConnectionRequest(candidate)), result = await response.json()
      if (!response.ok || result.ok !== true || result.status !== 'connected') throw new Error(typeof result.error === 'string' ? result.error : t('Connection was not confirmed.', '尚未确认连接成功。'))
      candidate = null; text.value = ''; status.textContent = t('Connected.', '已连接。'); window.location.assign(connectedWorkspaceUrl(window.location.href))
    } catch (error) { report(error); connect.disabled = false } finally { pending = false; cancel.disabled = false; camera.disabled = false; file.disabled = false; parse.disabled = false }
  })
  document.body.append(dialog); currentDialog = dialog; dialog.showModal()
}

if (typeof document !== 'undefined') document.addEventListener('click', event => { if (event.target.closest('[data-provider-connection-import]')) openProviderConnection() })
