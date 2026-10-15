import { readReviewFindings, saveReviewFindings, linkSubmittedFindings, reconcileReviewFinding } from './review-findings.js'

// Preserve historical line numbers and file boundaries when moving between hunks.
export function reviewDiffSections(body) {
  const files = []
  let file, hunk, oldLine = 0, newLine = 0
  for (const text of String(body || '').split('\n')) {
    if (text.startsWith('diff --git ')) {
      file = { title: text.match(/ b\/(.+)$/)?.[1] || text.slice(11), previousPath: '', hunks: [], metadata: [] }
      files.push(file); hunk = null
    } else if (text.startsWith('+++ b/') && file) {
      file.title = text.slice(6)
    } else if (text.startsWith('--- a/') && file) {
      file.previousPath = text.slice(6)
    } else {
      const match = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(text)
      if (match && file) {
        oldLine = Number(match[1]); newLine = Number(match[2])
        hunk = { title: text, rows: [] }; file.hunks.push(hunk)
      } else if (hunk && /^[ +\-]/.test(text)) {
        const kind = text[0] === '+' ? 'added' : text[0] === '-' ? 'removed' : 'context'
        hunk.rows.push({ kind, text: text.slice(1), old: kind === 'added' ? '' : oldLine++, next: kind === 'removed' ? '' : newLine++ })
      } else if (file && !hunk && !text.startsWith('---')) file.metadata.push(text)
    }
  }
  return files
}

export function reviewFindingPrompt({ path = '', line = '', body = '', url = '', revision = '' }) {
  return `Address this review finding${path ? ` in ${path}${line ? `:${line}` : ''}` : ''}${revision ? ` (reviewed revision ${revision})` : ''}:\n\n${body}${url ? `\n\nDiscussion: ${url}` : ''}\n\nInspect the current code, make the appropriate change, and explain how it addresses the finding.`
}

export function reviewDiffPairs(rows) {
  const pairs = []
  for (let index = 0; index < rows.length;) {
    if (rows[index].kind === 'context') { pairs.push([rows[index], rows[index]]); index++; continue }
    const removed = [], added = []
    while (index < rows.length && rows[index].kind !== 'context') {
      const row = rows[index++]; (row.kind === 'removed' ? removed : added).push(row)
    }
    for (let pair = 0; pair < Math.max(removed.length, added.length); pair++) pairs.push([removed[pair] || null, added[pair] || null])
  }
  return pairs
}

export function reviewJsonChanges(before, after) {
  const changes = []
  const walk = (left, right, path) => {
    if (JSON.stringify(left) === JSON.stringify(right)) return
    if (left && right && typeof left === 'object' && typeof right === 'object' && Array.isArray(left) === Array.isArray(right)) {
      for (const key of [...new Set([...Object.keys(left), ...Object.keys(right)])].sort()) walk(left[key], right[key], `${path}/${key.replaceAll('~', '~0').replaceAll('/', '~1')}`)
    } else changes.push({ path: path || '/', kind: left === undefined ? 'added' : right === undefined ? 'removed' : 'changed', before: left, after: right })
  }
  walk(before.trim() ? JSON.parse(before) : undefined, after.trim() ? JSON.parse(after) : undefined, '')
  return changes
}

export function reviewChangedTokens(before, after) {
  const tokens = text => text.match(/\s+|[\p{L}\p{N}_]+|[^\s\p{L}\p{N}_]/gu) || []
  const left = tokens(before), right = tokens(after)
  let prefix = 0, suffix = 0
  while (prefix < left.length && prefix < right.length && left[prefix] === right[prefix]) prefix++
  while (suffix < left.length - prefix && suffix < right.length - prefix && left[left.length - suffix - 1] === right[right.length - suffix - 1]) suffix++
  const parts = values => [values.slice(0, prefix).join(''), values.slice(prefix, values.length - suffix).join(''), suffix ? values.slice(-suffix).join('') : '']
  return [parts(left), parts(right)]
}

export function reviewAgentPrompt(target, value = '') {
  const scope = target === 'working' ? 'the staged and unstaged working-tree changes' : target === 'branch' ? `the changes on the current branch compared with ${value}` : target === 'commit' ? `commit ${value}` : value
  return `Review ${scope}. Inspect the relevant code and surrounding behavior. Report actionable findings with severity, file and line, why each matters, and a concrete suggested fix. Do not modify files during this review. Distinguish verified issues from questions, and summarize any important behavior you could not verify.`
}

const states = new WeakMap()
const element = (tag, text, className) => {
  const node = document.createElement(tag)
  if (text) node.textContent = text
  if (className) node.className = className
  return node
}
function button(text, action) {
  const node = element('button', text); node.type = 'button'
  node.addEventListener('click', action); return node
}
function storageRead(key) { try { return localStorage.getItem(key) || '' } catch { return '' } }
function storageWrite(key, value) { try { value ? localStorage.setItem(key, value) : localStorage.removeItem(key) } catch { /* The textarea still retains the reply. */ } }
function addFinding(prompt, status, source = {}) {
  const workspaceId = source.workspaceId || document.querySelector('[data-testid="mooncode-center"]')?.dataset.workspaceId || ''
  const findings = readReviewFindings()
  let finding = findings.find(item => item.workspaceId === workspaceId && item.prompt === prompt && item.status !== 'verified')
  if (!finding) {
    finding = { id: globalThis.crypto.randomUUID(), workspaceId, path: source.path || '', revision: source.revision || '', prompt, status: 'draft', createdAt: new Date().toISOString() }
    findings.push(finding); saveReviewFindings(findings)
  }
  globalThis.dispatchEvent(new CustomEvent('moondesk:add-context', {
    detail: { kind: 'review', label: 'Review finding', text: `[Review finding ${finding.id}]\n${prompt}`, path: finding.path, workspaceId, action: 'change' },
  }))
  status.textContent = 'Finding added to your chat context. Send it when ready.'
}
async function request(state, query = {}, payload) {
  const response = await fetch(`${state.endpoint}?${new URLSearchParams(query)}`, payload ? {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
  } : undefined)
  const data = await response.json()
  if (!response.ok) throw new Error(data.error?.message || data.error || data.message || 'Unable to load review. Try again.')
  return data
}
function message(state, text) { state.status.textContent = text }
async function run(state, action) {
  try { await action() } catch (error) { message(state, error.message) }
}

function showCommit(state, commit) {
  return run(state, async () => {
    const generation = ++state.generation
    message(state, 'Loading commit changes…')
    const result = await request(state, commit.finding ? { action: 'finding-diff', base: commit.oid, path: commit.finding.path } : commit.base ? { action: 'compare', base: commit.base } : { action: 'commit', oid: commit.oid })
    if (generation !== state.generation) return
    const files = reviewDiffSections(result.body)
    state.detail.replaceChildren(element('h4', commit.subject), element('p', `${commit.author} · ${commit.date} · ${commit.oid.slice(0, 8)}`))
    const toolbar = element('div', '', 'review-workflow-toolbar')
    const mode = button('Side by side', () => { view.classList.toggle('split'); mode.textContent = view.classList.contains('split') ? 'Unified' : 'Side by side' })
    const tokens = button('Highlight changed tokens', () => { view.classList.toggle('tokens'); if (view.classList.contains('tokens')) { view.classList.add('split'); mode.textContent = 'Unified' }; tokens.setAttribute('aria-pressed', String(view.classList.contains('tokens'))) })
    tokens.setAttribute('aria-pressed', 'false')
    const count = element('span')
    const view = element('div', '', 'review-workflow-diff')
    const anchors = []
    let selected = 0
    function navigate(delta) {
      if (!anchors.length) return
      selected = (selected + delta + anchors.length) % anchors.length
      anchors[selected].focus(); anchors[selected].scrollIntoView({ block: 'nearest' })
      count.textContent = `Change ${selected + 1} of ${anchors.length}`
    }
    toolbar.append(button('Previous change', () => navigate(-1)), button('Next change', () => navigate(1)), mode, tokens, count)
    state.detail.append(toolbar, view)
    for (const file of files) {
      const heading = element('h5', file.title); view.append(heading)
      if (!commit.base && !commit.finding && file.title.endsWith('.json')) view.append(button('Compare JSON structure', () => run(state, async () => {
        const content = await request(state, { action: 'structure', oid: commit.oid, path: file.title, previous_path: file.previousPath })
        const changes = reviewJsonChanges(content.before, content.after)
        const tree = element('div', '', 'review-workflow-structure')
        tree.append(element('strong', `${changes.length} JSON value changes`))
        for (const change of changes) tree.append(element('pre', `${change.kind} ${change.path}\n− ${JSON.stringify(change.before) ?? '(absent)'}\n+ ${JSON.stringify(change.after) ?? '(absent)'}`))
        heading.after(tree)
        message(state, 'JSON comparison loaded. Key order and formatting differences are ignored.')
      })))
      if (!file.hunks.length) view.append(element('pre', file.metadata.join('\n') || 'No text changes'))
      file.hunks.forEach((hunk, index) => {
        const section = element('section', '', 'review-workflow-hunk'); section.tabIndex = -1
        const header = element('div', '', 'review-workflow-toolbar')
        const key = `moondesk.review.viewed:${state.workspace}:${commit.oid}:${file.title}:${index}`
        const viewed = element('label'); const checkbox = element('input'); checkbox.type = 'checkbox'; checkbox.checked = storageRead(key) === 'yes'
        checkbox.addEventListener('change', () => { storageWrite(key, checkbox.checked ? 'yes' : ''); section.classList.toggle('viewed', checkbox.checked) })
        section.classList.toggle('viewed', checkbox.checked)
        viewed.append(checkbox, document.createTextNode('Viewed'))
        header.append(element('code', hunk.title), viewed)
        const note = element('textarea'); note.rows = 2; note.placeholder = 'Describe a change to request'; note.setAttribute('aria-label', `Finding for ${file.title}, ${hunk.title}`)
        section.append(header)
        const unified = element('div', '', 'review-workflow-unified')
        for (const row of hunk.rows) {
          const line = element('div', '', `review-workflow-line ${row.kind}`)
          line.append(element('span', String(row.old), 'old-line'), element('span', String(row.next), 'new-line'), element('code', `${row.kind === 'added' ? '+' : row.kind === 'removed' ? '-' : ' '}${row.text}`))
          unified.append(line)
        }
        const split = element('div', '', 'review-workflow-split')
        for (const [left, right] of reviewDiffPairs(hunk.rows)) {
          const pair = element('div', '', 'review-workflow-pair')
          const changed = reviewChangedTokens(left?.text || '', right?.text || '')
          for (const [row, side, parts] of [[left, 'old', changed[0]], [right, 'next', changed[1]]]) {
            const cell = element('div', '', `review-workflow-half ${row?.kind || ''}`)
            const code = element('code'); code.append(document.createTextNode(parts[0]), element('mark', parts[1]), document.createTextNode(parts[2]))
            cell.append(element('span', String(row?.[side] ?? '')), code)
            pair.append(cell)
          }
          split.append(pair)
        }
        section.append(unified, split)
        section.append(note, button('Ask for this change', () => {
          if (!note.value.trim()) { note.focus(); return }
          addFinding(reviewFindingPrompt({ path: file.title, revision: commit.oid, body: `${hunk.title}\n${note.value}` }), state.status, { workspaceId: state.workspace, path: file.title, revision: commit.oid })
        }))
        anchors.push(section); view.append(section)
      })
    }
    toolbar.append(button('Next unviewed', () => {
      for (let offset = 1; offset <= anchors.length; offset++) {
        const next = (selected + offset) % anchors.length
        if (!anchors[next].classList.contains('viewed')) { selected = next; navigate(0); return }
      }
      message(state, 'All displayed changes are marked viewed.')
    }))
    count.textContent = `${anchors.length} changes across ${files.length} files`
    const positionKey = `moondesk.review.position:${state.workspace}:${commit.oid}`
    let position = {}; try { position = JSON.parse(storageRead(positionKey) || '{}') } catch { /* No saved position. */ }
    view.classList.toggle('split', Boolean(position.split)); view.classList.toggle('tokens', Boolean(position.tokens))
    mode.textContent = position.split ? 'Unified' : 'Side by side'; tokens.setAttribute('aria-pressed', String(Boolean(position.tokens)))
    state.detail.scrollTop = Number(position.scrollTop) || 0
    state.detail.onscroll = () => storageWrite(positionKey, JSON.stringify({ scrollTop: state.detail.scrollTop, split: view.classList.contains('split'), tokens: view.classList.contains('tokens') }))
    message(state, files.length ? (commit.finding ? 'Current file changes since the reviewed revision. Inspect these before marking the finding verified.' : 'Commit changes loaded. This view does not change your working files.') : (commit.finding ? 'No changes in this file since the reviewed revision.' : 'This comparison has no text changes.'))
  })
}

async function loadRepository(state) {
  const generation = ++state.generation
  message(state, 'Loading branches and worktrees…')
  const data = await request(state, { action: 'workspace' })
  if (generation !== state.generation) return
  state.list.replaceChildren(); state.detail.replaceChildren(element('h4', `Repository · ${data.repository.branch || 'Detached HEAD'}`))
  const branch = element('select'); branch.setAttribute('aria-label', 'Choose branch or comparison base')
  for (const name of data.branches) { const option = element('option', name); option.value = name; branch.append(option) }
  const operation = async (action, value) => {
    message(state, 'Updating repository…')
    const result = await request(state, {}, { action, value }); await loadRepository(state); message(state, result.output || 'Repository updated')
    document.querySelector('[data-testid="mooncode-git-refresh"]')?.click()
  }
  state.list.append(branch, button('Compare with this base', () => showCommit(state, { base: branch.value, oid: branch.value, subject: `Changes since ${branch.value}`, author: 'Current branch', date: '' })), button('Switch branch', () => run(state, () => operation('switch', branch.value))))
  const newBranch = element('input'); newBranch.placeholder = 'New branch name'; newBranch.setAttribute('aria-label', 'New branch name')
  state.list.append(newBranch, button('Create and switch branch', () => run(state, () => operation('branch', newBranch.value.trim()))))
  const worktree = button('Create isolated worktree', () => run(state, async () => {
    if (!newBranch.value.trim()) { newBranch.focus(); return }
    worktree.disabled = true; message(state, 'Creating a worktree from the current commit…')
    try {
      const result = await request(state, {}, { action: 'worktree', value: newBranch.value.trim() })
      await loadRepository(state); message(state, `Worktree created for ${result.branch}. Open it below to start coding.`)
    } finally { worktree.disabled = false }
  }))
  state.list.append(worktree, element('p', 'An isolated worktree starts from the current commit. Uncommitted edits stay in this book.'))
  const changes = element('section'); changes.append(element('h5', 'Stage changes'))
  for (const change of data.repository.changes || []) {
    const row = element('div', '', 'review-workflow-toolbar'); row.append(element('span', change.path))
    if (change.worktree_status !== ' ') row.append(button('Stage', () => run(state, () => operation('stage', change.path))))
    if (![' ', '?'].includes(change.index_status)) row.append(button('Unstage', () => run(state, () => operation('unstage', change.path))))
    changes.append(row)
  }
  if (!data.repository.changes.length) changes.append(element('p', 'No uncommitted changes.'))
  const commit = element('textarea'); commit.rows = 3; commit.placeholder = 'Commit message'; commit.setAttribute('aria-label', 'Commit message for staged changes')
  const key = `moondesk.review.commit:${state.workspace}`; commit.value = storageRead(key); commit.addEventListener('input', () => storageWrite(key, commit.value))
  const save = button('Commit staged changes', () => run(state, async () => {
    if (!commit.value.trim()) { commit.focus(); return }
    save.disabled = true
    try {
      const result = await request(state, {}, { action: 'commit', value: commit.value })
      storageWrite(key, ''); await loadRepository(state); message(state, result.output || 'Commit created.')
      document.querySelector('[data-testid="mooncode-git-refresh"]')?.click()
    } finally { save.disabled = false }
  }))
  changes.append(commit, save); state.detail.append(changes, element('h5', 'Worktrees'))
  for (const tree of data.worktrees) {
    const row = element('div', '', 'review-workflow-worktree'); row.append(element('strong', `${tree.branch || 'Detached HEAD'}${tree.current ? ' · current' : ''}`), element('p', tree.path))
    if (tree.workspace_id && !tree.current) row.append(button('Open book', () => globalThis.dispatchEvent(new CustomEvent('moondesk:open-workspace', { detail: { workspaceId: tree.workspace_id } }))))
    else if (!tree.workspace_id) row.append(element('span', 'This worktree is outside the book library.'))
    state.detail.append(row)
  }
  message(state, 'Choose changes to stage, a branch to compare, or a worktree to open.')
}

function showAgentReview(state) {
  ++state.generation; state.list.replaceChildren(); state.detail.replaceChildren(element('h4', 'Ask an agent to review'))
  const target = element('select'); target.setAttribute('aria-label', 'Review scope')
  for (const [value, label] of [['working', 'Working changes'], ['branch', 'Current branch against a base'], ['commit', 'A commit'], ['custom', 'Custom scope']]) { const option = element('option', label); option.value = value; target.append(option) }
  const value = element('textarea'); value.rows = 3; value.disabled = true; value.setAttribute('aria-label', 'Base branch, commit or review instructions')
  target.addEventListener('change', () => { value.disabled = target.value === 'working'; value.placeholder = target.value === 'branch' ? 'Base branch, for example main' : target.value === 'commit' ? 'Commit revision' : 'Describe files, behavior or questions to review' })
  state.detail.append(target, value, button('Prepare review in chat', () => {
    if (target.value !== 'working' && !value.value.trim()) { value.focus(); return }
    globalThis.dispatchEvent(new CustomEvent('moondesk:add-context', { detail: { kind: 'review', label: 'Agent code review', text: reviewAgentPrompt(target.value, value.value.trim()), action: 'ask' } }))
    message(state, 'Review scope added to the chat. Send it to start the agent review.')
  }))
  message(state, 'Choose what to review. Findings will appear in your coding conversation.')
}

async function showFindings(state) {
  const generation = ++state.generation
  state.list.replaceChildren(button('Refresh task status', () => run(state, () => showFindings(state))))
  state.detail.replaceChildren(element('h4', 'Findings and follow-up work'))
  message(state, 'Reading linked coding tasks…')
  let findings = readReviewFindings().filter(item => item.workspaceId === state.workspace)
  const conversations = new Map()
  for (const session of new Set(findings.map(item => item.sessionId).filter(Boolean))) {
    try {
      const response = await fetch(`/api/mooncode/sessions/${encodeURIComponent(session)}/task-controls`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'inspect' }) })
      if (response.ok) conversations.set(session, (await response.json()).context?.conversation || [])
    } catch { /* Keep last known task state and allow an explicit refresh. */ }
  }
  if (generation !== state.generation) return
  findings = findings.map(item => reconcileReviewFinding(item, conversations.get(item.sessionId) || []))
  const byId = new Map(findings.map(item => [item.id, item]))
  saveReviewFindings(readReviewFindings().map(item => byId.get(item.id) || item))
  if (!findings.length) state.detail.append(element('p', 'Use “Ask for this change” on a review note or discussion. Its coding task and resulting file changes will appear here.'))
  for (const finding of findings) {
    const card = element('section', '', 'review-workflow-thread')
    card.append(element('h5', finding.path || 'Review follow-up'), element('p', finding.prompt))
    const status = finding.status === 'verified' ? 'Verified by you' : finding.commandId ? `Task ${typeof finding.taskStatus === 'string' ? finding.taskStatus : JSON.stringify(finding.taskStatus)}` : finding.sessionId ? 'Submitted · waiting for the conversation to record this turn' : 'Added to draft · send it from chat to start'
    card.append(element('strong', status))
    if (finding.commandId) card.append(element('small', `Turn ${finding.commandId}`))
    if (finding.taskAnswer) {
      const answer = element('details'); answer.append(element('summary', 'Agent response'), element('p', typeof finding.taskAnswer === 'string' ? finding.taskAnswer : JSON.stringify(finding.taskAnswer))); card.append(answer)
    }
    if (finding.sessionId) card.append(button('Open coding conversation', () => globalThis.dispatchEvent(new CustomEvent('moondesk:open-code-session', { detail: { sessionId: finding.sessionId } }))))
    if (finding.path && /^[a-f0-9]{40}$/.test(finding.revision)) card.append(button('Inspect resulting file changes', () => showCommit(state, { oid: finding.revision, subject: finding.path, author: 'Current file compared with reviewed revision', date: '', finding })))
    card.append(button(finding.status === 'verified' ? 'Reopen finding' : 'Mark verified after review', () => {
      saveReviewFindings(readReviewFindings().map(item => item.id === finding.id ? { ...item, status: finding.status === 'verified' ? 'submitted' : 'verified' } : item))
      run(state, () => showFindings(state))
    }))
    state.detail.append(card)
  }
  message(state, `${findings.length} findings. Task status comes from the coding conversation; verification is your review decision.`)
}

async function loadHistory(state, append = false) {
  message(state, 'Loading repository history…')
  const generation = ++state.generation
  const result = await request(state, { action: 'history', offset: append ? state.offset : 0 })
  if (generation !== state.generation) return
  state.commits = append ? [...state.commits, ...result.commits] : result.commits
  if (!append) state.detail.replaceChildren(element('p', 'Choose a commit to review its changes.'))
  state.offset = result.next_offset
  const filter = element('input'); filter.type = 'search'; filter.placeholder = 'Find a commit'; filter.setAttribute('aria-label', 'Find a loaded commit by message, author or revision')
  const list = element('div', '', 'review-workflow-commits')
  const render = () => {
    const query = filter.value.trim().toLowerCase()
    list.replaceChildren(...state.commits.filter(c => `${c.subject} ${c.author} ${c.oid}`.toLowerCase().includes(query)).map(commit => {
      const item = button('', () => showCommit(state, commit))
      item.append(element('strong', commit.subject), element('span', `${commit.oid.slice(0, 8)} · ${commit.author} · ${commit.date.slice(0, 10)}`))
      return item
    }))
    if (!list.childElementCount) list.append(element('p', 'No matching commits in the loaded history.'))
  }
  filter.addEventListener('input', render); render()
  state.list.replaceChildren(filter, list)
  if (result.has_more) state.list.append(button('Load older commits', () => run(state, () => loadHistory(state, true))))
  message(state, `${state.commits.length} commits loaded`)
}

function renderThreads(state, pull, append) {
  if (!append) {
    state.detail.replaceChildren(element('h4', pull.title))
    const conversation = element('details', '', 'review-workflow-thread')
    conversation.append(element('summary', `Conversation · ${pull.comments?.nodes?.length || 0} recent comments`))
    for (const comment of pull.comments?.nodes || []) {
      const article = element('article'); article.append(element('strong', comment.author?.login || 'Former contributor'), element('p', comment.body))
      const link = element('a', 'Open on GitHub'); link.href = comment.url; link.target = '_blank'; link.rel = 'noreferrer'
      article.append(link, button('Add to coding task', () => addFinding(reviewFindingPrompt({ body: comment.body, url: comment.url }), state.status)))
      conversation.append(article)
    }
    if (pull.comments?.pageInfo?.hasPreviousPage) {
      const older = element('a', 'Read earlier conversation on GitHub'); older.href = pull.url; older.target = '_blank'; older.rel = 'noreferrer'; conversation.append(older)
    }
    const draftKey = `moondesk.review.conversation:${state.workspace}:${state.number}`
    const reply = element('textarea'); reply.rows = 3; reply.value = storageRead(draftKey); reply.setAttribute('aria-label', 'Add a pull request conversation comment')
    reply.addEventListener('input', () => storageWrite(draftKey, reply.value))
    const feedback = element('p'); feedback.setAttribute('role', 'status')
    const send = button('Post comment to GitHub', () => run(state, async () => {
      if (!reply.value.trim()) { reply.focus(); return }
      send.disabled = true; feedback.textContent = 'Posting comment…'
      try {
        await request(state, {}, { action: 'comment', number: state.number, body: reply.value })
        const article = element('article'); article.append(element('strong', 'Your comment'), element('p', reply.value)); conversation.insertBefore(article, reply)
        reply.value = ''; storageWrite(draftKey, ''); feedback.textContent = 'Comment posted.'
      } catch (error) { feedback.textContent = `${error.message} Your draft is preserved.` }
      finally { send.disabled = false }
    }))
    conversation.append(reply, send, feedback); state.detail.append(conversation)
  }
  for (const thread of pull.reviewThreads.nodes) {
    const card = element('section', '', 'review-workflow-thread')
    card.append(element('h5', `${thread.path}${thread.line || thread.originalLine ? `:${thread.line || thread.originalLine}` : ''}`))
    const status = element('span', thread.isResolved ? 'Resolved' : thread.isOutdated ? 'Open · earlier revision' : 'Open')
    card.append(status)
    for (const comment of thread.comments.nodes) {
      const article = element('article')
      article.append(element('strong', comment.author?.login || 'Former contributor'), element('p', comment.body))
      const link = element('a', 'Open on GitHub'); link.href = comment.url; link.target = '_blank'; link.rel = 'noreferrer'
      article.append(link, button('Ask for this change', () => addFinding(reviewFindingPrompt({ path: thread.path, line: thread.line || thread.originalLine, body: comment.body, url: comment.url }), state.status, { workspaceId: state.workspace, path: thread.path, revision: pull.headRefOid || '' })))
      card.append(article)
    }
    if (thread.comments.pageInfo.hasNextPage) card.append(element('p', 'Showing the first 50 comments. Open the discussion on GitHub to see the rest.'))
    const draftKey = `moondesk.review.reply:${state.workspace}:${thread.id}`
    const reply = element('textarea'); reply.rows = 3; reply.value = storageRead(draftKey); reply.placeholder = 'Reply to this discussion'; reply.setAttribute('aria-label', `Reply about ${thread.path}`)
    reply.addEventListener('input', () => storageWrite(draftKey, reply.value))
    const feedback = element('p'); feedback.setAttribute('role', 'status')
    const send = button('Post reply to GitHub', () => run(state, async () => {
      if (!reply.value.trim()) { reply.focus(); return }
      send.disabled = true; feedback.textContent = 'Posting reply…'
      try {
        await request(state, {}, { action: 'reply', thread_id: thread.id, body: reply.value })
        const posted = element('article'); posted.append(element('strong', 'Your reply'), element('p', reply.value)); card.insertBefore(posted, reply)
        reply.value = ''; storageWrite(draftKey, ''); feedback.textContent = 'Reply posted.'
      } catch (error) { feedback.textContent = `${error.message} Your draft is preserved.` }
      finally { send.disabled = false }
    }))
    const resolve = button(thread.isResolved ? 'Reopen discussion' : 'Resolve discussion', () => run(state, async () => {
      resolve.disabled = true
      try {
        await request(state, {}, { action: 'resolve', thread_id: thread.id, resolved: !thread.isResolved })
        thread.isResolved = !thread.isResolved; status.textContent = thread.isResolved ? 'Resolved' : 'Open'; resolve.textContent = thread.isResolved ? 'Reopen discussion' : 'Resolve discussion'
        feedback.textContent = thread.isResolved ? 'Discussion resolved on GitHub.' : 'Discussion reopened on GitHub.'
      } catch (error) { feedback.textContent = error.message }
      finally { resolve.disabled = false }
    }))
    card.append(reply, send, resolve, feedback); state.detail.append(card)
  }
  if (!pull.reviewThreads.nodes.length) state.detail.append(element('p', 'No review discussions on this pull request.'))
  if (pull.reviewThreads.pageInfo.hasNextPage) {
    const more = button('Load more discussions', () => run(state, async () => {
      more.disabled = true
      const generation = state.generation
      try { const next = await request(state, { action: 'discussions', number: state.number, cursor: pull.reviewThreads.pageInfo.endCursor }); if (generation !== state.generation) return; more.remove(); renderThreads(state, next, true) }
      catch (error) { more.disabled = false; throw error }
    }))
    state.detail.append(more)
  }
}

async function loadDiscussions(state) {
  const generation = ++state.generation
  state.list.replaceChildren(); state.detail.replaceChildren()
  const label = element('label', 'Pull request number ')
  const number = element('input'); number.type = 'number'; number.min = '1'; number.value = String(state.number || ''); label.append(number)
  const open = button('Open discussions', () => run(state, async () => {
    if (!Number.isInteger(Number(number.value)) || Number(number.value) < 1) { number.focus(); return }
    state.number = Number(number.value); const generation = ++state.generation
    message(state, 'Loading review discussions…')
    const pull = await request(state, { action: 'discussions', number: state.number })
    if (generation !== state.generation) return
    renderThreads(state, pull, false); message(state, 'Discussions loaded')
  }))
  state.list.append(label, open)
  message(state, 'Open a pull request to read, reply or resolve review discussions.')
  // Offer the actual open PRs; users may also enter a closed PR number.
  try {
    const response = await fetch(`/api/workspaces/${encodeURIComponent(state.workspace)}/git/github`)
    const context = await response.json()
    if (generation !== state.generation) return
    for (const pull of context.pull_requests || []) state.list.append(button(`#${pull.number} ${pull.title}`, () => { number.value = String(pull.number); open.click() }))
  } catch { /* Manual number entry remains available. */ }
}

export function enhanceReviewWorkflow(scope = document) {
  for (const host of scope.querySelectorAll('[data-runtime="review-workflow-v1"]')) {
    if (states.has(host)) continue
    const root = element('details', '', 'review-workflow'); root.append(element('summary', 'History & review discussions'))
    const tabs = element('div', '', 'review-workflow-toolbar')
    const status = element('p'); status.setAttribute('role', 'status')
    const panes = element('div', '', 'review-workflow-panes'); const list = element('nav'); list.setAttribute('aria-label', 'Review history'); const detail = element('div', '', 'review-workflow-detail'); panes.append(list, detail)
    const state = { workspace: host.dataset.workspaceId, endpoint: `/api/workspaces/${encodeURIComponent(host.dataset.workspaceId)}/git/workflow`, root, status, list, detail, generation: 0, commits: [], offset: 0 }
    states.set(host, state)
    tabs.append(button('Commit history', () => run(state, () => loadHistory(state))), button('PR discussions', () => run(state, () => loadDiscussions(state))), button('Findings', () => run(state, () => showFindings(state))), button('Repository', () => run(state, () => loadRepository(state))), button('Agent review', () => showAgentReview(state)))
    root.append(tabs, status, panes); host.append(root)
    root.addEventListener('toggle', () => { if (root.open && !state.started) { state.started = true; run(state, () => loadHistory(state)) } })
  }
  for (const finding of scope.querySelectorAll('[data-review-finding]')) {
    if (finding.dataset.reviewFindingInstalled) continue
    finding.dataset.reviewFindingInstalled = 'true'
    const status = element('span'); status.setAttribute('role', 'status')
    finding.append(button('Ask for this change', () => addFinding(reviewFindingPrompt({ path: finding.dataset.path, line: Number(finding.dataset.line) || '', body: finding.dataset.reviewFinding }), status, { path: finding.dataset.path, revision: finding.dataset.revision })), status)
  }
}

export function installReviewWorkflow() {
  globalThis.addEventListener('moondesk:context-submitted', event => saveReviewFindings(linkSubmittedFindings(readReviewFindings(), event.detail)))
  enhanceReviewWorkflow()
  const observer = new MutationObserver(() => enhanceReviewWorkflow())
  observer.observe(document.body, { childList: true, subtree: true })
  return () => observer.disconnect()
}
