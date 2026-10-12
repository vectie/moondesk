import { compareJsonDocuments, jsonComparisonReport } from './source-json-comparison.js'

const states = new WeakMap()
const PAGE_SIZE = 25
const PREVIEW_SIZE = 1000
const find = (panel, name) => panel.querySelector(`[data-json-compare-${name}]`)
const action = (panel, name) => panel.querySelector(`[data-action="source-json-compare-${name}"]`)
const identity = parts => JSON.stringify([parts.surface.dataset.workspaceId || '', parts.surface.dataset.sourcePath || ''])

function button(name, label) {
  const item = document.createElement('button'); item.type = 'button'; item.className = 'secondary-button'
  item.dataset.action = `source-json-compare-${name}`; item.textContent = label
  return item
}

function createPanel(surface) {
  const panel = document.createElement('details'); panel.setAttribute('data-json-comparison', '')
  const title = document.createElement('summary'); title.textContent = 'Compare JSON versions'
  const help = document.createElement('p')
  help.textContent = 'Paste reference JSON to compare against the entire current draft. Object order and equivalent string escapes are ignored; number tokens are exact. Arrays compare by position, not record ID. Neither input is changed or saved.'
  const reference = document.createElement('textarea'); reference.setAttribute('data-json-compare-reference', '')
  reference.setAttribute('aria-label', 'Reference JSON before the current draft'); reference.rows = 6; reference.spellcheck = false
  const status = document.createElement('p'); status.setAttribute('data-json-compare-status', ''); status.setAttribute('role', 'status')
  const results = document.createElement('div'); results.setAttribute('data-json-compare-results', '')
  panel.append(title, help, reference, button('run', 'Compare versions'), button('clear', 'Clear comparison'), status,
    button('download', 'Download difference report'), results, button('previous', 'Previous differences'), button('next', 'Next differences'))
  surface.append(panel)
  return panel
}

function invalidate(panel, state, message) {
  state.result = null; state.page = 0; state.generation += 1
  find(panel, 'results').replaceChildren(); find(panel, 'status').textContent = message
  for (const name of ['download', 'previous', 'next']) action(panel, name).disabled = true
}

export function syncJsonComparison(parts) {
  let panel = parts.surface.querySelector('[data-json-comparison]')
  if (parts.language !== 'JSON') {
    if (panel) { panel.hidden = true; find(panel, 'reference').value = ''; states.delete(panel); find(panel, 'results').replaceChildren() }
    return
  }
  if (!panel) panel = createPanel(parts.surface)
  panel.hidden = false
  let state = states.get(panel)
  if (!state || state.identity !== identity(parts)) {
    state = { identity: identity(parts), text: parts.editor.value, disabled: parts.editor.disabled, generation: 0 }
    states.set(panel, state); find(panel, 'reference').value = ''
    invalidate(panel, state, 'Paste a reference JSON document, then compare it with the current draft.')
  }
  if (state.text !== parts.editor.value || state.disabled !== parts.editor.disabled) {
    invalidate(panel, state, 'Draft or editor availability changed. Compare versions again; the reference is retained.')
    state.text = parts.editor.value; state.disabled = parts.editor.disabled
  }
  find(panel, 'reference').disabled = parts.editor.disabled
  action(panel, 'run').disabled = parts.editor.disabled
  action(panel, 'clear').disabled = parts.editor.disabled
}

export function changeJsonComparison(parts) {
  if (!parts) return
  syncJsonComparison(parts)
  const panel = parts.surface.querySelector('[data-json-comparison]'), state = states.get(panel)
  if (state) invalidate(panel, state, 'Reference changed. Compare versions again.')
}

function render(panel, state) {
  const start = state.page * PAGE_SIZE, total = state.result.counts.total
  find(panel, 'status').textContent = total
    ? `${state.result.counts.added} added, ${state.result.counts.removed} removed, ${state.result.counts.changed} changed subtrees. Differences ${start + 1}–${Math.min(start + PAGE_SIZE, total)} of ${total}. Previews show up to 1,000 UTF-16 units; the report contains complete changed values.`
    : 'No value differences under these comparison rules. Formatting, object member order and equivalent string escapes may still differ.'
  find(panel, 'results').replaceChildren(...state.result.changes.slice(start, start + PAGE_SIZE).map((change, offset) => {
    const row = document.createElement('div')
    const heading = document.createElement('p'); heading.textContent = `${change.kind} · ${JSON.stringify(change.pointer)}${change.pointer === '' ? ' (root)' : ''}`
    row.append(heading)
    for (const [label, value] of [['Reference', change.before], ['Current draft', change.after]]) {
      const preview = document.createElement('pre'); preview.style.whiteSpace = 'pre-wrap'; preview.style.maxHeight = '10rem'; preview.style.overflow = 'auto'
      preview.textContent = value ? `${label} (${value.type}):\n${value.json.slice(0, PREVIEW_SIZE)}${value.json.length > PREVIEW_SIZE ? '\n[Preview shortened; full value in report]' : ''}` : `${label}: absent`
      row.append(preview)
    }
    const select = button('select', 'Select current value in editor')
    select.dataset.jsonCompareIndex = String(start + offset); select.dataset.jsonCompareGeneration = String(state.generation)
    select.disabled = !change.after; row.append(select)
    return row
  }))
  action(panel, 'download').disabled = false
  action(panel, 'previous').disabled = state.page === 0
  action(panel, 'next').disabled = start + PAGE_SIZE >= total
}

export function actJsonComparison(parts, target, reveal) {
  if (!parts || parts.language !== 'JSON' || parts.editor.disabled || !parts.surface.isConnected || target.disabled) return
  const panel = parts.surface.querySelector('[data-json-comparison]')
  const previous = states.get(panel)
  syncJsonComparison(parts)
  const state = states.get(panel)
  // A stale control from a previous file must not operate on its replacement.
  if (!previous || previous !== state) return
  const kind = target.dataset.action.slice('source-json-compare-'.length)
  if (kind === 'clear') {
    find(panel, 'reference').value = ''; invalidate(panel, state, 'Comparison cleared. Paste reference JSON to start again.'); return
  }
  if (kind === 'run') {
    invalidate(panel, state, '')
    try {
      state.reference = find(panel, 'reference').value
      state.result = compareJsonDocuments(state.reference, parts.editor.value)
      render(panel, state)
    } catch (error) { invalidate(panel, state, error.message) }
    return
  }
  if (!state.result) return
  if (state.reference !== find(panel, 'reference').value) {
    invalidate(panel, state, 'Reference changed. Compare versions again.'); return
  }
  if (kind === 'previous' || kind === 'next') {
    state.page = Math.max(0, Math.min(Math.ceil(state.result.counts.total / PAGE_SIZE) - 1, state.page + (kind === 'next' ? 1 : -1)))
    state.generation += 1; render(panel, state)
  } else if (kind === 'select') {
    if (target.dataset.jsonCompareGeneration !== String(state.generation)) return
    const selected = state.result.changes[Number(target.dataset.jsonCompareIndex)]?.after
    if (selected) reveal(parts, { path: parts.surface.dataset.sourcePath, start: selected.start, end: selected.end,
      line: parts.editor.value.slice(0, selected.start).split('\n').length })
  } else if (kind === 'download') {
    let url
    try {
      url = URL.createObjectURL(new Blob([jsonComparisonReport(state.result, parts.surface.dataset)], { type: 'application/json;charset=utf-8' }))
      const link = document.createElement('a'); link.href = url; link.download = 'json-differences.json'
      try { document.body.append(link); link.click() } finally { link.remove() }
      find(panel, 'status').textContent = 'Difference report download requested. It contains complete changed values from the reference and current draft; neither input was saved.'
    } catch (error) { find(panel, 'status').textContent = `Could not download comparison: ${error.message}` }
    finally { if (url) setTimeout(() => URL.revokeObjectURL(url), 1000) }
  }
}
