// Interactive PPTX slide preview, shape text editor, speaker notes, and AI chat
// integration backed by MoonLeaf `preview_json` SVG + `pptx-ops`.

const cache = new Map()

function resolveWorkspaceAndPath(host) {
  const url = new URL(globalThis.location.href)
  const workspaceId = host?.dataset?.workspaceId || url.searchParams.get('workspace') || ''
  const path = host?.dataset?.documentPath || url.searchParams.get('path') || ''
  return { workspaceId, path }
}

function slideIndexFromHost(host, summary) {
  if (host?.dataset?.pptxSlideIndex !== undefined && host.dataset.pptxSlideIndex !== '') {
    const explicit = Number(host.dataset.pptxSlideIndex)
    if (Number.isFinite(explicit) && explicit >= 0) return explicit
  }
  const section = host?.dataset?.section || ''
  const slides = summary?.slides || []
  if (section) {
    const byPart = slides.findIndex(s => s.part === section || s.part.endsWith('/' + section))
    if (byPart >= 0) return byPart
  }
  return 0
}

async function fetchOfficePptx(workspaceId, path, force = false) {
  const key = `${workspaceId}::${path}`
  if (!force && cache.has(key)) return cache.get(key)
  const res = await fetch(
    `/api/workspaces/${encodeURIComponent(workspaceId)}/office?path=${encodeURIComponent(path)}`,
    { credentials: 'same-origin', cache: 'no-store' },
  )
  if (!res.ok) return null
  const data = await res.json()
  cache.set(key, data)
  return data
}

async function savePptxOps(workspaceId, path, baseline, ops) {
  const send = async (base) => fetch(
    `/api/workspaces/${encodeURIComponent(workspaceId)}/office/save`,
    {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ path, baseline, operation: 'pptx-ops', ops }),
    },
  )
  let res = await send(baseline)
  let data = await res.json().catch(() => ({}))
  if (res.status === 409 && data?.current_baseline) {
    res = await send(data.current_baseline)
    data = await res.json().catch(() => ({}))
  }
  if (!res.ok || !data?.ok) {
    throw new Error(data?.error || `Save failed (${res.status})`)
  }
  cache.set(`${workspaceId}::${path}`, data)
  return data
}

function makeBtn(label, title, onClick, primary = false) {
  const btn = document.createElement('button')
  btn.type = 'button'
  btn.className = primary ? 'primary-button' : 'secondary-button'
  btn.style.cssText = 'height:28px;padding:0 10px;font-size:12px;border-radius:6px;'
  btn.textContent = label
  btn.title = title
  btn.addEventListener('click', onClick)
  return btn
}

async function enhancePptxHost(host) {
  if (!host || host.dataset.pptxRendering === 'true') return
  const { workspaceId, path } = resolveWorkspaceAndPath(host)
  if (!workspaceId || !path || !path.toLowerCase().endsWith('.pptx')) return
  const slideIdxHint = host.dataset.section || ''
  const renderKey = `${workspaceId}::${path}::${slideIdxHint}`
  if (host.dataset.pptxRenderedKey === renderKey && host.querySelector('.pptx-svg-stage')) return

  host.dataset.pptxRendering = 'true'
  try {
    const data = await fetchOfficePptx(workspaceId, path)
    if (!data || !host.isConnected) return
    const preview = data.pptx_preview
    const summary = data.pptx_summary
    if (!preview || !Array.isArray(preview.slides) || !preview.slides.length) return

    const idx = Math.min(Math.max(0, slideIndexFromHost(host, summary)), preview.slides.length - 1)
    const slide = preview.slides[idx]
    const slideMeta = summary?.slides?.[idx] || { shapes: [], notes: '' }

    const slideBox = host.querySelector('.office-preview-slide')
    if (!slideBox) return
    const geomBox = host.querySelector('.office-preview-geometry')
    if (geomBox) geomBox.style.display = 'none'

    // Replace raw unstyled div boxes with MoonLeaf SVG stage
    slideBox.innerHTML = ''
    slideBox.style.cssText = 'position:relative;width:100%;aspect-ratio:16/9;background:#fff;border:1px solid rgba(15,23,42,0.12);border-radius:8px;overflow:hidden;box-shadow:0 4px 18px rgba(15,23,42,0.07);'
    const svgStage = document.createElement('div')
    svgStage.className = 'pptx-svg-stage'
    svgStage.style.cssText = 'width:100%;height:100%;'
    svgStage.innerHTML = slide.svg || ''
    const svgEl = svgStage.querySelector('svg')
    if (svgEl) {
      svgEl.style.cssText = 'width:100%;height:100%;display:block;'
    }
    slideBox.appendChild(svgStage)

    // Remove old inspector/toolbar if re-rendering
    host.querySelector('.pptx-ops-panel')?.remove()
    const panel = document.createElement('div')
    panel.className = 'pptx-ops-panel'
    panel.style.cssText = 'margin-top:10px;padding:10px 12px;border:1px solid rgba(15,23,42,0.1);border-radius:8px;background:var(--bg-raised,#fff);display:flex;flex-direction:column;gap:8px;font-size:12px;'

    const bar = document.createElement('div')
    bar.style.cssText = 'display:flex;flex-wrap:wrap;align-items:center;gap:6px;'
    const status = document.createElement('span')
    status.style.cssText = 'margin-left:auto;color:#64748b;font-size:11px;'
    status.textContent = `Slide ${idx + 1} / ${preview.slides.length}`

    const duplicateBtn = makeBtn('+ Duplicate slide', 'Clone this slide after current', async () => {
      status.textContent = 'Duplicating…'
      try {
        await savePptxOps(workspaceId, path, data.baseline, [
          { op: 'clone_slide', template_slide: idx, insert_at: idx + 1 },
        ])
        host.dataset.pptxRenderedKey = ''
        status.textContent = 'Duplicated'
        await enhancePptxHost(host)
      } catch (e) {
        status.textContent = String(e?.message || e)
      }
    })

    const askAiBtn = makeBtn('✨ Ask AI', 'Send slide context to Wiki Chat', () => {
      const label = `${path} · Slide ${idx + 1}`
      globalThis.dispatchEvent(new CustomEvent('moondesk:docx-chat-action', {
        detail: {
          type: 'add-context',
          focusChat: true,
          item: {
            id: `pptx:${path}:${idx}`.slice(0, 150),
            kind: 'selection',
            label: label.slice(0, 150),
            value: path,
            detail: JSON.stringify({
              path,
              slide_index: idx,
              slide_count: preview.slides.length,
              title: slide.title || '',
              shapes: slideMeta.shapes || [],
              notes: slideMeta.notes || '',
            }),
          },
        },
      }))
      status.textContent = 'Sent to Wiki Chat'
    }, true)

    const prevBtn = makeBtn('◀ Prev', 'Previous slide', () => {
      if (idx <= 0) return
      host.dataset.pptxSlideIndex = String(idx - 1)
      host.dataset.pptxRenderedKey = ''
      void enhancePptxHost(host)
    })
    prevBtn.disabled = idx <= 0

    const nextBtn = makeBtn('Next ▶', 'Next slide', () => {
      if (idx >= preview.slides.length - 1) return
      host.dataset.pptxSlideIndex = String(idx + 1)
      host.dataset.pptxRenderedKey = ''
      void enhancePptxHost(host)
    })
    nextBtn.disabled = idx >= preview.slides.length - 1

    bar.append(prevBtn, nextBtn, duplicateBtn, askAiBtn, status)

    // Inline shape editor when user clicks a shape in the SVG
    const shapeEditor = document.createElement('div')
    shapeEditor.style.cssText = 'display:none;flex-direction:column;gap:6px;padding-top:6px;border-top:1px solid rgba(15,23,42,0.08);'
    const shapeLabel = document.createElement('strong')
    const shapeInput = document.createElement('textarea')
    shapeInput.id = 'pptx-shape-text-input'
    shapeInput.name = 'pptx_shape_text'
    shapeInput.rows = 3
    shapeInput.style.cssText = 'width:100%;padding:6px 8px;border:1px solid rgba(15,23,42,0.16);border-radius:6px;font-size:12px;font-family:inherit;'
    let activeShapeId = ''
    const saveShapeBtn = makeBtn('Save text', 'Save shape text to PPTX', async () => {
      if (!activeShapeId) return
      status.textContent = 'Saving…'
      try {
        await savePptxOps(workspaceId, path, data.baseline, [{
          op: 'replace_shape_text',
          slide: idx,
          shape_id: activeShapeId,
          paragraphs: shapeInput.value.split('\n'),
        }])
        host.dataset.pptxRenderedKey = ''
        await enhancePptxHost(host)
      } catch (e) {
        status.textContent = String(e?.message || e)
      }
    }, true)
    shapeEditor.append(shapeLabel, shapeInput, saveShapeBtn)

    for (const g of svgStage.querySelectorAll('g[data-shape-id]')) {
      const sid = g.getAttribute('data-shape-id') || ''
      const meta = (slideMeta.shapes || []).find(s => String(s.id) === sid)
      if (!meta) continue
      g.style.cursor = 'pointer'
      g.addEventListener('click', () => {
        activeShapeId = sid
        shapeLabel.textContent = `Edit ${meta.name || `Shape #${meta.index + 1}`}`
        shapeInput.value = meta.text || ''
        shapeEditor.style.display = 'flex'
        shapeInput.focus()
      })
    }

    // Speaker notes inline editor
    const notesRow = document.createElement('div')
    notesRow.style.cssText = 'display:flex;gap:6px;align-items:center;'
    const notesInput = document.createElement('input')
    notesInput.id = 'pptx-slide-notes-input'
    notesInput.name = 'pptx_slide_notes'
    notesInput.type = 'text'
    notesInput.value = slideMeta.notes || ''
    notesInput.placeholder = 'Speaker notes for this slide…'
    notesInput.style.cssText = 'flex:1;height:28px;padding:0 8px;border:1px solid rgba(15,23,42,0.14);border-radius:6px;font-size:12px;'
    const saveNotesBtn = makeBtn('Save notes', 'Save speaker notes to PPTX', async () => {
      status.textContent = 'Saving notes…'
      try {
        await savePptxOps(workspaceId, path, data.baseline, [{
          op: 'set_notes',
          slide: idx,
          text: notesInput.value,
        }])
        host.dataset.pptxRenderedKey = ''
        status.textContent = 'Notes saved'
        await enhancePptxHost(host)
      } catch (e) {
        status.textContent = String(e?.message || e)
      }
    })
    notesRow.append(notesInput, saveNotesBtn)

    panel.append(bar, shapeEditor, notesRow)
    host.appendChild(panel)
    host.dataset.pptxRenderedKey = renderKey
  } finally {
    host.dataset.pptxRendering = 'false'
  }
}

export function installWikiPptxRuntime() {
  const run = () => {
    for (const host of document.querySelectorAll('[data-testid="office-pptx-preview"]')) {
      void enhancePptxHost(host)
    }
  }
  const observer = new MutationObserver(run)
  observer.observe(document.getElementById('app') || document.body, { childList: true, subtree: true })
  run()
}
