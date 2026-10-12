import { markdownLinks, prepareMarkdownLinkReplacement, applyMarkdownLinkReplacement } from './source-markdown-links.js'

const states = new WeakMap()
const PAGE_SIZE = 25
let generation = 0
const find = (panel, name) => panel.querySelector(`[data-markdown-links-${name}]`)
const action = (panel, name) => panel.querySelector(`[data-action="source-markdown-links-${name}"]`)
const identity = parts => JSON.stringify([parts.surface.dataset.workspaceId || '', parts.surface.dataset.sourcePath || ''])
const supported = parts => /\.(md|markdown)$/i.test(parts.surface.dataset.sourcePath || '')

function button(name, label) {
  const node = document.createElement('button'); node.type = 'button'; node.className = 'secondary-button'
  node.dataset.action = `source-markdown-links-${name}`; node.textContent = label
  return node
}

function createPanel(surface) {
  const panel = document.createElement('details'); panel.setAttribute('data-markdown-links', '')
  const title = document.createElement('summary'); title.textContent = 'Inspect and retarget Markdown links'
  const help = document.createElement('p')
  help.textContent = 'Inspect supported single-line inline links and images in this draft. Code, reference links, raw HTML blocks and blockquotes are excluded. This is a bounded source scanner, not a renderer or broken-link checker. Destinations are never opened or fetched.'
  const status = document.createElement('p'); status.setAttribute('data-markdown-links-status', ''); status.setAttribute('role', 'status')
  const results = document.createElement('div'); results.setAttribute('data-markdown-links-results', '')
  const edit = document.createElement('div'); edit.setAttribute('data-markdown-links-edit', ''); edit.hidden = true
  const selected = document.createElement('p'); selected.setAttribute('data-markdown-links-selected', '')
  const replacement = document.createElement('input'); replacement.setAttribute('data-markdown-links-replacement', '')
  replacement.setAttribute('aria-label', 'New Markdown destination token'); replacement.spellcheck = false
  replacement.placeholder = 'docs/guide.md or <docs/user guide.md>'
  const review = document.createElement('pre'); review.setAttribute('data-markdown-links-review', ''); review.style.whiteSpace = 'pre-wrap'; review.style.maxHeight = '16rem'; review.style.overflow = 'auto'
  edit.append(selected, replacement, button('review-one', 'Preview this occurrence'),
    button('review-matching', 'Preview all exact matching destinations'), review,
    button('apply', 'Apply reviewed destinations to draft'), button('cancel', 'Cancel link edit'))
  panel.append(title, help, button('inspect', 'Inspect current draft links'), status, results,
    button('previous', 'Previous links'), button('next', 'Next links'), edit)
  surface.append(panel)
  return panel
}

function invalidateReview(panel, state) {
  state.plan = null
  find(panel, 'review').textContent = ''
  action(panel, 'apply').disabled = true
}

function invalidate(panel, state, message) {
  state.links = null; state.selected = null; state.page = 0; state.generation = ++generation
  invalidateReview(panel, state)
  find(panel, 'results').replaceChildren(); find(panel, 'edit').hidden = true
  find(panel, 'status').textContent = message
  action(panel, 'previous').disabled = true; action(panel, 'next').disabled = true
}

export function syncMarkdownLinks(parts) {
  let panel = parts.surface.querySelector('[data-markdown-links]')
  if (!supported(parts)) {
    if (panel) { panel.hidden = true; states.delete(panel); find(panel, 'replacement').value = ''; find(panel, 'results').replaceChildren() }
    return
  }
  if (!panel) panel = createPanel(parts.surface)
  panel.hidden = false
  let state = states.get(panel)
  if (!state || state.identity !== identity(parts)) {
    state = { identity: identity(parts), text: parts.editor.value, disabled: parts.editor.disabled }
    states.set(panel, state); find(panel, 'replacement').value = ''
    invalidate(panel, state, 'Inspect the current draft to choose a link destination. Changes remain unsaved until ordinary Save.')
  }
  if (state.text !== parts.editor.value || state.disabled !== parts.editor.disabled) {
    invalidate(panel, state, 'Draft or editor availability changed. Inspect links again before editing.')
    state.text = parts.editor.value; state.disabled = parts.editor.disabled
  }
  for (const name of ['inspect', 'review-one', 'review-matching', 'cancel']) action(panel, name).disabled = parts.editor.disabled
  find(panel, 'replacement').disabled = parts.editor.disabled
}

export function changeMarkdownLinks(parts) {
  if (!parts) return
  syncMarkdownLinks(parts)
  const panel = parts.surface.querySelector('[data-markdown-links]'), state = states.get(panel)
  if (state) { invalidateReview(panel, state); find(panel, 'status').textContent = 'Destination changed. Preview it before applying.' }
}

function render(panel, state) {
  state.generation = ++generation
  const start = state.page * PAGE_SIZE
  find(panel, 'status').textContent = state.links.length
    ? `${state.links.length} supported inline destinations. Showing ${start + 1}–${Math.min(start + PAGE_SIZE, state.links.length)}. Exact matching includes both links and images; excluded syntax is not included.`
    : 'No supported inline destinations found. Reference links and excluded syntax are not included.'
  find(panel, 'results').replaceChildren(...state.links.slice(start, start + PAGE_SIZE).map((link, offset) => {
    const row = document.createElement('div'), label = document.createElement('p')
    label.textContent = `${link.kind} · L${link.line}:${link.column} · ${link.label.slice(0, 120)} → ${link.destination.slice(0, 300)}${link.destination.length > 300 ? ' [shortened; full token in edit field]' : ''}`
    row.append(label)
    for (const [kind, title] of [['select', 'Select destination in editor'], ['edit', 'Edit destination']]) {
      const control = button(kind, title); control.dataset.markdownLinksIndex = String(start + offset); control.dataset.markdownLinksGeneration = String(state.generation)
      row.append(control)
    }
    return row
  }))
  action(panel, 'previous').disabled = state.page === 0
  action(panel, 'next').disabled = start + PAGE_SIZE >= state.links.length
}

export function actMarkdownLinks(parts, target, reveal) {
  if (!parts || !supported(parts) || parts.editor.disabled || !parts.surface.isConnected || target.disabled) return
  const panel = parts.surface.querySelector('[data-markdown-links]'), previous = states.get(panel)
  syncMarkdownLinks(parts)
  const state = states.get(panel)
  if (!previous || previous !== state) return
  const kind = target.dataset.action.slice('source-markdown-links-'.length)
  if (kind === 'inspect') {
    invalidate(panel, state, '')
    try { state.links = markdownLinks(parts.editor.value); render(panel, state) }
    catch (error) { invalidate(panel, state, error.message) }
    return
  }
  if (!state.links) return
  if (kind === 'previous' || kind === 'next') {
    state.page = Math.max(0, Math.min(Math.ceil(state.links.length / PAGE_SIZE) - 1, state.page + (kind === 'next' ? 1 : -1)))
    render(panel, state); return
  }
  if (kind === 'select' || kind === 'edit') {
    if (target.dataset.markdownLinksGeneration !== String(state.generation)) return
    const link = state.links[Number(target.dataset.markdownLinksIndex)]
    if (!link) return
    if (kind === 'select') reveal(parts, { path: parts.surface.dataset.sourcePath, start: link.destinationStart, end: link.destinationEnd, line: link.line })
    else {
      invalidateReview(panel, state); state.selected = link
      find(panel, 'edit').hidden = false; find(panel, 'replacement').value = link.destination
      find(panel, 'selected').textContent = `Editing ${link.kind} at L${link.line}:${link.column}. Enter one destination token; labels and titles stay unchanged.`
      find(panel, 'replacement').focus()
    }
    return
  }
  if (kind === 'cancel') {
    invalidateReview(panel, state); state.selected = null; find(panel, 'edit').hidden = true; find(panel, 'replacement').value = ''
    find(panel, 'status').textContent = 'Link edit cancelled. The draft is unchanged.'; return
  }
  if (!state.selected) return
  try {
    const replacement = find(panel, 'replacement').value
    if (kind === 'review-one' || kind === 'review-matching') {
      invalidateReview(panel, state)
      state.plan = prepareMarkdownLinkReplacement(parts.editor.value, state.selected.destinationStart, replacement, kind === 'review-one' ? 'one' : 'matching')
      const plan = state.plan
      const shortened = Math.max(plan.before.length, replacement.length) > 4000
      find(panel, 'review').textContent = `Before:\n${plan.before.slice(0, 4000)}\nAfter:\n${replacement.slice(0, 4000)}\nAffected occurrences (${plan.matches.length}):\n` +
        plan.matches.map(link => `${link.kind} L${link.line}:${link.column}`).join('\n') +
        (shortened ? '\nToken previews shortened at 4,000 UTF-16 units. Inspect the full destination field and source before applying.' : '')
      find(panel, 'status').textContent = plan.changed
        ? `Review ${plan.matches.length} destination replacement${plan.matches.length === 1 ? '' : 's'} in the current draft. No file is saved.`
        : 'No change: the destination token is already identical.'
      action(panel, 'apply').disabled = !plan.changed
    } else if (kind === 'apply') {
      const plan = state.plan
      const output = applyMarkdownLinkReplacement(plan, parts.editor.value, state.selected.destinationStart, replacement, plan?.scope)
      if (!plan.changed) return
      const selection = [parts.editor.selectionStart, parts.editor.selectionEnd, parts.editor.selectionDirection]
      const first = plan.matches[0], last = plan.matches.at(-1)
      // One setRangeText + one input enters the existing EditDraft/history boundary.
      const end = last.destinationEnd + plan.matches.reduce((delta, link) => delta + replacement.length - link.destination.length, 0)
      invalidateReview(panel, state)
      try {
        parts.editor.setRangeText(output.slice(first.destinationStart, end), first.destinationStart, last.destinationEnd, 'select')
        if (parts.editor.value !== output) throw new Error('Editor did not retain the reviewed destination replacements.')
      } catch (error) {
        parts.editor.value = plan.text; parts.editor.setSelectionRange(...selection); throw error
      }
      const count = plan.matches.length
      parts.editor.dispatchEvent(new Event('input', { bubbles: true })); parts.editor.focus()
      find(panel, 'status').textContent = `Replaced ${count} destination${count === 1 ? '' : 's'} in the unsaved draft. Use ordinary Undo/Redo or Save; inspect links again for another edit.`
    }
  } catch (error) { invalidateReview(panel, state); find(panel, 'status').textContent = error.message }
}
