// Word (.docx) cursor/selection tracking, formatting/comment toolbar, and
// chat-driven batch edit bridge backed by MoonLeaf's `docx-ops` endpoint.

const HIGHLIGHT_COLORS = [
  { id: 'yellow', label: 'Yellow highlight', swatch: '#fef08a' },
  { id: 'green', label: 'Green highlight', swatch: '#bbf7d0' },
  { id: 'cyan', label: 'Cyan highlight', swatch: '#a5f3fc' },
  { id: 'magenta', label: 'Pink highlight', swatch: '#f5d0fe' },
  { id: 'none', label: 'Clear highlight', swatch: 'transparent' },
]

const SHADE_COLORS = [
  { id: 'FEF3C7', label: 'Warm paper shade', swatch: '#fef3c7' },
  { id: 'E8F0FE', label: 'Soft blue shade', swatch: '#e8f0fe' },
  { id: 'E6F4EA', label: 'Soft green shade', swatch: '#e6f4ea' },
  { id: 'none', label: 'Clear background', swatch: 'transparent' },
]

export function parseDocxSourceInfo(host) {
  let workspaceId = host?.dataset?.workspaceId || ''
  let path = host?.dataset?.documentPath || ''
  const sourceUrl = host?.dataset?.sourceUrl || ''
  if ((!workspaceId || !path) && sourceUrl) {
    try {
      const parsed = new URL(sourceUrl, globalThis.location?.origin || 'http://localhost')
      const match = parsed.pathname.match(/\/api\/workspaces\/([^/]+)\/office\/export/)
      if (match && !workspaceId) workspaceId = decodeURIComponent(match[1])
      if (!path) path = parsed.searchParams.get('path') || ''
    } catch {}
  }
  return { workspaceId, path }
}

export function extractDocxOpsFromText(markdownText) {
  const text = String(markdownText || '')
  const regex = /```(?:docx-ops|json)?\s*\n([\s\S]*?)```/gi
  let match
  while ((match = regex.exec(text)) !== null) {
    try {
      const parsed = JSON.parse(match[1].trim())
      if (parsed && Array.isArray(parsed.ops) && parsed.ops.length > 0) {
        return parsed.ops
      }
      if (Array.isArray(parsed) && parsed.length > 0 && parsed[0]?.op) {
        return parsed
      }
    } catch {}
  }
  return null
}

function paragraphUtf16Offset(paragraph, container, offset) {
  try {
    const probe = document.createRange()
    probe.setStart(paragraph, 0)
    probe.setEnd(container, offset)
    return probe.toString().length
  } catch {
    return 0
  }
}

function resolveSectionHeading(outline, paragraphIndex) {
  const headings = Array.isArray(outline?.headings) ? outline.headings : []
  let active = ''
  for (const heading of headings) {
    if (Number(heading?.paragraph_index) <= paragraphIndex && heading?.text) {
      active = String(heading.text)
    }
  }
  return active
}

function getShadowSelection(root) {
  if (typeof root?.getSelection === 'function') {
    const sel = root.getSelection()
    if (sel && sel.rangeCount > 0) return sel
  }
  const docSel = document.getSelection?.()
  if (docSel && docSel.rangeCount > 0) return docSel
  return null
}

function toolbarStyles() {
  return `
    .docx-ops-bar {
      position: sticky;
      top: 0;
      z-index: 12;
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 4px;
      padding: 6px 12px;
      background: color-mix(in srgb, var(--bg-raised, #ffffff) 94%, transparent);
      backdrop-filter: blur(8px);
      border-bottom: 1px solid rgba(15, 23, 42, 0.08);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 12px;
      color: #334155;
    }
    .docx-ops-group {
      display: inline-flex;
      align-items: center;
      gap: 2px;
      padding-right: 6px;
      margin-right: 2px;
      border-right: 1px solid rgba(15, 23, 42, 0.08);
    }
    .docx-ops-group:last-of-type { border-right: none; }
    .docx-ops-btn {
      appearance: none;
      border: 1px solid transparent;
      background: transparent;
      color: #1e293b;
      border-radius: 5px;
      height: 26px;
      min-width: 26px;
      padding: 0 7px;
      font-size: 12px;
      font-weight: 500;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 4px;
    }
    .docx-ops-btn:hover { background: rgba(15, 23, 42, 0.06); }
    .docx-ops-btn:disabled { opacity: 0.42; cursor: not-allowed; }
    .docx-ops-btn.primary {
      background: rgba(37, 99, 235, 0.09);
      color: #1d4ed8;
    }
    .docx-ops-btn.primary:hover { background: rgba(37, 99, 235, 0.16); }
    .docx-ops-swatch {
      width: 14px;
      height: 14px;
      border-radius: 3px;
      border: 1px solid rgba(15, 23, 42, 0.22);
      display: inline-block;
    }
    .docx-ops-status {
      margin-left: auto;
      font-size: 11px;
      color: #64748b;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      max-width: 260px;
    }
    .docx-ops-comment-pop {
      width: 100%;
      display: flex;
      align-items: center;
      gap: 6px;
      padding-top: 4px;
    }
    .docx-ops-comment-input {
      flex: 1;
      height: 28px;
      padding: 0 8px;
      border: 1px solid rgba(15, 23, 42, 0.16);
      border-radius: 5px;
      font-size: 12px;
      outline: none;
    }
    .docx-ops-comment-input:focus { border-color: #2563eb; }
    .docx-comment-badge {
      display: inline-flex;
      align-items: center;
      gap: 3px;
      margin-left: 6px;
      padding: 1px 6px;
      border-radius: 999px;
      background: rgba(245, 158, 11, 0.16);
      color: #92400e;
      font-size: 10px;
      font-weight: 600;
      vertical-align: middle;
      cursor: help;
      user-select: none;
    }
  `
}

export async function syncDocxMetadata(host, view) {
  if (!view.baseline && host?.dataset?.baseline) {
    view.baseline = host.dataset.baseline
  }
  const { workspaceId, path } = parseDocxSourceInfo(host)
  if (!workspaceId || !path) return
  try {
    const url = `/api/workspaces/${encodeURIComponent(workspaceId)}/office?path=${encodeURIComponent(path)}`
    const response = await fetch(url, { credentials: 'same-origin', cache: 'no-store' })
    if (!response.ok) return
    const data = await response.json()
    if (data?.baseline) view.baseline = data.baseline
    if (data?.outline) view.outline = data.outline
    if (Array.isArray(data?.comments)) view.comments = data.comments
    renderCommentBadges(view)
  } catch {}
}

export function renderCommentBadges(view) {
  if (!view?.article) return
  for (const old of view.article.querySelectorAll('.docx-comment-badge')) old.remove()
  const comments = Array.isArray(view.comments) ? view.comments : []
  if (!comments.length) return
  const byPara = new Map()
  for (const c of comments) {
    const idx = Number(c?.paragraph_index)
    if (!Number.isFinite(idx) || idx < 0) continue
    if (!byPara.has(idx)) byPara.set(idx, [])
    byPara.get(idx).push(c)
  }
  for (const [idx, items] of byPara.entries()) {
    const para = view.nodes?.get(idx) || view.article.querySelector(`[data-paragraph="${idx}"]`)
    if (!para) continue
    const badge = document.createElement('span')
    badge.className = 'docx-comment-badge'
    badge.contentEditable = 'false'
    badge.textContent = `💬 ${items.length}`
    badge.title = items.map(item => `${item.author || 'Note'}: ${item.text || ''}`).join('\n')
    para.appendChild(badge)
  }
}

export function installDocxOpsToolbar(host, view, reloadView) {
  if (!view?.root || view.opsBar) return
  const style = document.createElement('style')
  style.textContent = toolbarStyles()
  view.root.appendChild(style)

  const bar = document.createElement('div')
  bar.className = 'docx-ops-bar'
  bar.dataset.testid = 'docx-ops-toolbar'

  const status = document.createElement('span')
  status.className = 'docx-ops-status'
  status.textContent = 'Click text to format or ask AI'

  const setStatus = (msg) => { status.textContent = msg }

  const captureCursor = () => {
    const sel = getShadowSelection(view.root)
    if (!sel || sel.rangeCount === 0) return view.cursor || null
    const range = sel.getRangeAt(0)
    const startEl = range.startContainer.nodeType === 1 ? range.startContainer : range.startContainer.parentElement
    const para = startEl?.closest?.('[data-paragraph]')
    if (!para || !view.article.contains(para)) return view.cursor || null
    const paragraphIndex = Number(para.dataset.paragraph)
    if (!Number.isFinite(paragraphIndex)) return view.cursor || null
    const start = paragraphUtf16Offset(para, range.startContainer, range.startOffset)
    const endNode = range.endContainer.nodeType === 1 ? range.endContainer : range.endContainer.parentElement
    const samePara = endNode?.closest?.('[data-paragraph]') === para
    const end = samePara ? paragraphUtf16Offset(para, range.endContainer, range.endOffset) : start
    const lo = Math.min(start, end)
    const hi = Math.max(start, end)
    const paragraphText = String(para.textContent || '').replace(/💬\s*\d+$/g, '').trimEnd()
    const selectedText = hi > lo ? range.toString() : ''
    const section = resolveSectionHeading(view.outline, paragraphIndex)
    const { workspaceId, path } = parseDocxSourceInfo(host)
    const cursor = {
      workspace_id: workspaceId,
      path,
      paragraph_index: paragraphIndex,
      start: lo,
      end: hi,
      selected_text: selectedText,
      paragraph_text: paragraphText,
      section,
    }
    view.cursor = cursor
    globalThis.__moondeskDocxCursor = cursor
    const secLabel = section ? ` · ${section}` : ''
    setStatus(
      selectedText
        ? `¶${paragraphIndex + 1} (${selectedText.length} chars)${secLabel}`
        : `¶${paragraphIndex + 1} cursor${secLabel}`,
    )
    return cursor
  }

  const applyOps = async (ops, opts = {}) => {
    const { workspaceId, path } = parseDocxSourceInfo(host)
    if (!workspaceId || !path) {
      setStatus('Document path missing')
      return { ok: false, error: 'Document path missing' }
    }
    if (!view.baseline) await syncDocxMetadata(host, view)
    if (!view.baseline) {
      setStatus('Document not ready yet')
      return { ok: false, error: 'Document baseline unavailable' }
    }
    const saveOnce = async (baseline) => fetch(
      `/api/workspaces/${encodeURIComponent(workspaceId)}/office/save`,
      {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          path,
          baseline,
          operation: 'docx-ops',
          author: opts.author || 'User',
          ops,
        }),
      },
    )
    setStatus('Applying…')
    try {
      let response = await saveOnce(view.baseline)
      let payload = await response.json().catch(() => ({}))
      if (response.status === 409 && payload?.current_baseline) {
        view.baseline = payload.current_baseline
        response = await saveOnce(view.baseline)
        payload = await response.json().catch(() => ({}))
      }
      if (!response.ok || !payload?.ok) {
        const errMsg = payload?.error || `Save failed (${response.status})`
        setStatus(errMsg)
        return { ok: false, error: errMsg }
      }
      if (payload.baseline) view.baseline = payload.baseline
      if (payload.outline) view.outline = payload.outline
      if (Array.isArray(payload.comments)) view.comments = payload.comments
      if (typeof reloadView === 'function') {
        await reloadView(host, view)
      }
      renderCommentBadges(view)
      setStatus('Saved')
      return { ok: true, payload }
    } catch (error) {
      const errMsg = String(error?.message || error || 'Save failed')
      setStatus(errMsg)
      return { ok: false, error: errMsg }
    }
  }

  globalThis.__moondeskApplyDocxOps = (ops, opts) => applyOps(ops, opts)

  const formatWithStyle = async (style) => {
    const cursor = captureCursor()
    if (!cursor) {
      setStatus('Place cursor in a paragraph first')
      return
    }
    const hasRange = cursor.end > cursor.start && cursor.selected_text
    const op = hasRange
      ? {
          op: 'format_range',
          target: { paragraph_index: cursor.paragraph_index },
          range: { start: cursor.start, end: cursor.end },
          selected_text: cursor.selected_text,
          style,
        }
      : {
          op: 'format',
          target: { paragraph_index: cursor.paragraph_index },
          style,
        }
    await applyOps([op])
  }

  const mkBtn = (label, title, onClick, className = 'docx-ops-btn') => {
    const btn = document.createElement('button')
    btn.type = 'button'
    btn.className = className
    btn.textContent = label
    btn.title = title
    btn.setAttribute('aria-label', title)
    btn.addEventListener('mousedown', (e) => e.preventDefault())
    btn.addEventListener('click', onClick)
    return btn
  }

  const textGroup = document.createElement('span')
  textGroup.className = 'docx-ops-group'
  textGroup.append(
    mkBtn('B', 'Bold', () => void formatWithStyle({ bold: true })),
    mkBtn('I', 'Italic', () => void formatWithStyle({ italic: true })),
    mkBtn('U', 'Underline', () => void formatWithStyle({ underline: true })),
    mkBtn('S', 'Strikethrough', () => void formatWithStyle({ strike: true })),
  )

  const highlightGroup = document.createElement('span')
  highlightGroup.className = 'docx-ops-group'
  let hlIndex = 0
  const hlBtn = mkBtn('', 'Highlight text', () => {
    const item = HIGHLIGHT_COLORS[hlIndex % HIGHLIGHT_COLORS.length]
    hlIndex += 1
    void formatWithStyle({ highlight: item.id })
  })
  const hlSwatch = document.createElement('span')
  hlSwatch.className = 'docx-ops-swatch'
  hlSwatch.style.background = '#fef08a'
  hlBtn.append('HL ', hlSwatch)

  let shadeIndex = 0
  const shadeBtn = mkBtn('', 'Background shading', () => {
    const cursor = captureCursor()
    if (!cursor) {
      setStatus('Place cursor in a paragraph first')
      return
    }
    const item = SHADE_COLORS[shadeIndex % SHADE_COLORS.length]
    shadeIndex += 1
    const hasRange = cursor.end > cursor.start && cursor.selected_text
    void formatWithStyle(hasRange ? { shade: item.id } : { paragraph_shade: item.id })
  })
  const shadeSwatch = document.createElement('span')
  shadeSwatch.className = 'docx-ops-swatch'
  shadeSwatch.style.background = '#e8f0fe'
  shadeBtn.append('Bg ', shadeSwatch)
  highlightGroup.append(hlBtn, shadeBtn)

  const noteGroup = document.createElement('span')
  noteGroup.className = 'docx-ops-group'
  let commentPop = null
  const closeCommentPop = () => {
    commentPop?.remove()
    commentPop = null
  }
  noteGroup.append(
    mkBtn('💬 Note', 'Add Word comment/note', () => {
      const cursor = captureCursor()
      if (!cursor) {
        setStatus('Place cursor in a paragraph first')
        return
      }
      if (commentPop) {
        closeCommentPop()
        return
      }
      commentPop = document.createElement('div')
      commentPop.className = 'docx-ops-comment-pop'
      const input = document.createElement('input')
      input.type = 'text'
      input.className = 'docx-ops-comment-input'
      input.placeholder = cursor.selected_text
        ? `Comment on "${cursor.selected_text.slice(0, 28)}"…`
        : `Add note on paragraph ${cursor.paragraph_index + 1}…`
      const saveBtn = mkBtn('Add note', 'Save Word comment', async () => {
        const text = input.value.trim()
        if (!text) return
        const op = {
          op: 'comment',
          target: { paragraph_index: cursor.paragraph_index },
          text,
        }
        if (cursor.end > cursor.start && cursor.selected_text) {
          op.range = { start: cursor.start, end: cursor.end }
        }
        closeCommentPop()
        await applyOps([op], { author: 'Reviewer' })
      }, 'docx-ops-btn primary')
      const cancelBtn = mkBtn('Cancel', 'Cancel note', closeCommentPop)
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') saveBtn.click()
        if (e.key === 'Escape') closeCommentPop()
      })
      commentPop.append(input, saveBtn, cancelBtn)
      bar.appendChild(commentPop)
      input.focus()
    }),
  )

  const aiGroup = document.createElement('span')
  aiGroup.className = 'docx-ops-group'
  aiGroup.append(
    mkBtn('✨ Ask AI', 'Send cursor/selection context to Wiki Chat', () => {
      const cursor = captureCursor()
      if (!cursor) {
        setStatus('Place cursor in a paragraph first')
        return
      }
      const label = cursor.selected_text
        ? `${cursor.path} · ¶${cursor.paragraph_index + 1} (${cursor.selected_text.slice(0, 24)})`
        : `${cursor.path} · ¶${cursor.paragraph_index + 1}`
      const contextId = `docx:${cursor.path}:${cursor.paragraph_index}:${cursor.start}-${cursor.end}`.slice(0, 150)
      globalThis.dispatchEvent(new CustomEvent('moondesk:docx-chat-action', {
        detail: {
          type: 'add-context',
          focusChat: true,
          item: {
            id: contextId,
            kind: 'selection',
            label: label.slice(0, 150),
            value: cursor.path,
            detail: JSON.stringify({
              path: cursor.path,
              paragraph_index: cursor.paragraph_index,
              range: { start: cursor.start, end: cursor.end },
              section: cursor.section,
              selected_text: cursor.selected_text,
              paragraph_text: cursor.paragraph_text,
            }),
          },
        },
      }))
      setStatus('Sent to Wiki Chat')
    }, 'docx-ops-btn primary'),
  )

  bar.append(textGroup, highlightGroup, noteGroup, aiGroup, status)
  view.root.insertBefore(bar, view.article)
  view.opsBar = bar

  view.article.addEventListener('mouseup', captureCursor)
  view.article.addEventListener('keyup', captureCursor)
  view.article.addEventListener('focusin', captureCursor)
  document.addEventListener('selectionchange', () => {
    if (host.isConnected && view.root?.contains(view.article)) {
      const sel = getShadowSelection(view.root)
      if (sel && sel.rangeCount > 0) {
        const node = sel.getRangeAt(0).startContainer
        if (view.article.contains(node)) captureCursor()
      }
    }
  })

  void syncDocxMetadata(host, view)
}
