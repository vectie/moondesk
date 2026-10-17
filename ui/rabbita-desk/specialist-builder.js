import { readTaskFile, withTaskFiles } from './specialist-task-files.js'
import { portableByteLimit, validImportSource, exportCreator, parseCreator, matchingCreatorBooks, bindImportedCreator, downloadCreator } from './specialist-portable.js'
import { taskInputKeys, validTaskForm, fillTaskForm } from './specialist-task-form.js'
import { taskCsvLimits, parseTaskCsv, inspectTaskCsv } from './specialist-task-csv.js'
import { parseTaskJsonl } from './specialist-task-jsonl.js'
import { defaultTaskExploration, taskExplorationStatuses, validateTaskExploration, exploreTaskRows } from './specialist-task-explorer.js'
import { taskBatchByteLimit, exportTaskBatch, parseTaskBatch } from './specialist-task-batch.js'
import { taskResultLimits, captureTaskObservation, appendTaskObservation, sameObservedTask, exportTaskResults } from './specialist-task-results.js'
import { beginTaskRefinement, refinedTaskBrief } from './specialist-task-refinement.js'
import { compositionContract, maxCompositionStages, sameCompositionBook, compositionSelections, validComposition, compositionInstructions } from './specialist-composition.js'

// A specialist is a browser-local brief over one installed MoonBook. It is
// neither an installed pack nor adopted Book behavior or a permission grant.
export const specialistStorageKey = 'moondesk.specialist-presets.v1'
export const specialistStorageKeyFor = scope => specialistStorageKey + ':' + encodeURIComponent(scope)
const contract = 'moondesk.specialist-preset.v1'
const maxRecords = 64
const maxText = 8000
const clone = value => JSON.parse(JSON.stringify(value))
const text = value => typeof value === 'string' ? value : ''
const unique = values => [...new Set(values)]
const browserStorage = () => { try { return globalThis.localStorage } catch { return null } }
const safePath = value => typeof value === 'string' && value.length <= 1024 &&
  /^(wiki|raw)\//.test(value) && !/[\\\x00-\x1f\x7f]/.test(value) &&
  value.split('/').every(part => part && part !== '.' && part !== '..')
const safeText = (value, max = maxText) => typeof value === 'string' &&
  value.trim().length > 0 && value.length <= max && !/[\x00]/.test(value)

function validVariant(lineage, record) {
  return lineage?.contract === 'moondesk.specialist-variant.v1' &&
    Object.keys(lineage).every(key => ['contract', 'source_id', 'source_revision', 'source_name'].includes(key)) &&
    safeText(lineage.source_id, 128) && lineage.source_id !== record.id &&
    Number.isSafeInteger(lineage.source_revision) && lineage.source_revision >= 1 &&
    safeText(lineage.source_name, 100)
}

function validPreset(record) {
  return record?.contract === contract && safeText(record.id, 128) &&
    Number.isSafeInteger(record.revision) && record.revision >= 1 &&
    safeText(record.name, 100) && safeText(record.purpose) && safeText(record.example) &&
    safeText(record.book?.workspace_id, 512) && safeText(record.book?.book_id, 512) &&
    safeText(record.book?.version, 128) && safeText(record.book?.name, 256) &&
    Array.isArray(record.capabilities) && record.capabilities.length <= 16 &&
    record.capabilities.every(value => safeText(value, 128)) &&
    Array.isArray(record.knowledge_paths) && record.knowledge_paths.length <= 20 &&
    record.knowledge_paths.every(safePath) &&
    (!Object.hasOwn(record, 'imported_from') || (validImportSource(record.imported_from) && record.imported_from.source_id !== record.id)) &&
    (!Object.hasOwn(record, 'variant') || validVariant(record.variant, record)) &&
    (!Object.hasOwn(record, 'task_form') || validTaskForm(record.task_form)) &&
    (!Object.hasOwn(record, 'composition') || validComposition(record.composition, record))
}

function parseStore(raw) {
  if (!raw) return []
  if (raw.length > 2000000) throw new Error('Saved specialists exceed the local size limit.')
  const data = JSON.parse(raw)
  if (data?.contract !== 'moondesk.specialist-library.v1' ||
      !Array.isArray(data.records) || data.records.length > maxRecords ||
      !data.records.every(validPreset) ||
      new Set(data.records.map(item => item.id)).size !== data.records.length) {
    throw new Error('Saved specialists could not be read. Existing storage was left unchanged.')
  }
  return data.records
}

function catalogRecords(payload) {
  if (payload?.contract_id !== 'moonsuite.agent-catalog.v1' || payload.ok !== true ||
      !Array.isArray(payload.agents)) throw new Error('Installed MoonBooks could not be verified.')
  const records = payload.agents.filter(item =>
    item?.contract_id === 'moonsuite.agent-passport.v1' && item.source_kind === 'moonbook' &&
    safeText(item.workspace_id, 512) && safeText(item.book_id, 512) &&
    safeText(item.version, 128) && safeText(item.name, 256) &&
    Array.isArray(item.capabilities) && item.capabilities.length <= 16 &&
    item.capabilities.every(value => safeText(value, 128)))
  if (records.length !== payload.agents.length) throw new Error('Installed MoonBook catalog contains an invalid passport.')
  if (new Set(records.map(item => item.workspace_id)).size !== records.length) {
    throw new Error('Installed MoonBook identities are ambiguous.')
  }
  return records
}

export function specialistBrief(preset, task) {
  if (!validPreset(preset)) throw new Error('Complete the specialist before preparing a trial.')
  return [
    `Specialist: ${preset.name} (revision ${preset.revision})`,
    ...(preset.imported_from ? [`Imported definition: ${preset.imported_from.source_name} · original revision ${preset.imported_from.source_revision}. File provenance is unverified; this is an independent local creator.`] : []),
    ...(preset.variant ? [`Variant source: ${preset.variant.source_name} [${preset.variant.source_id}] · saved revision ${preset.variant.source_revision}. This is an independently edited copy; knowledge references remain live.`] : []),
    `Purpose:\n${preset.purpose}`,
    `Representative task:\n${task ?? preset.example}`,
    `Selected MoonBook: ${preset.book.name} [${preset.book.book_id}] version ${preset.book.version}`,
    `Preferred capabilities: ${preset.capabilities.join(', ') || 'Ordinary Book chat'}`,
    `Selected knowledge references:\n${preset.knowledge_paths.map(path => '@' + path).join('\n') || '(No additional files selected)'}`,
    ...(preset.composition ? [compositionInstructions(preset.composition)] : []),
    'Use the selected knowledge references where relevant. Preserve source links and distinguish facts from inference. Report missing or changed sources.',
    'This brief expresses task preferences. It grants no tools, access, external effects, or recurring work. Existing Book context and runtime permissions still apply.',
  ].join('\n\n')
}

export function createSpecialistController({
  scope,
  fetch: request = globalThis.fetch?.bind(globalThis),
  storage = browserStorage(),
  dispatch = (...args) => {
    if (typeof globalThis.__moondeskWorkspaceFeaturesDispatch !== 'function') throw new Error('The chat bridge is unavailable. Reload Desk before trying again.')
    globalThis.__moondeskWorkspaceFeaturesDispatch(...args)
  },
  id = () => globalThis.crypto.randomUUID(),
  changed = () => {},
} = {}) {
  const storageKey = specialistStorageKeyFor(scope)
  const state = { open: false, loading: false, searching: false, preparing: false,
    records: [], agents: [], hits: [], draft: null, created: null, editing: true,
    status: '', storage_error: '', pending: '', prepared: '', taskValues: {}, taskPreview: '', csv: null, csvLoading: false, portableImport: null, importLoading: false, taskFiles: [], taskFileLoading: false, stageReplacement: null, refinement: null }
  let baseRecord = null
  let storeSnapshot = null, generation = 0, searchGeneration = 0, tryGeneration = 0, csvGeneration = 0, importGeneration = 0, taskFileGeneration = 0
  const notify = () => changed(state)
  const fail = error => { state.status = error?.message || 'This action could not be completed.'; notify(); return false }
  const readStore = () => {
    try {
      if (!safeText(scope, 8192) || scope === '["","",""]') throw new Error('The Desk library scope is not ready. Refresh Pack Home before building a specialist.')
      if (!storage) throw new Error('Browser storage is unavailable. You can create and try, but saving is unavailable.')
      storeSnapshot = storage.getItem(storageKey)
      state.records = parseStore(storeSnapshot)
      state.storage_error = ''
    } catch (error) { state.storage_error = error.message; state.records = [] }
  }
  const loadCatalog = async () => {
    const response = await request('/api/desktop/agents')
    if (!response.ok) throw new Error('Installed MoonBooks could not be loaded. Retry when Desk is connected.')
    return catalogRecords(await response.json())
  }
  const selectedAgent = () => state.agents.find(item => item.workspace_id === state.draft?.book?.workspace_id)
  const validateBook = preset => {
    if (!safeText(scope, 8192) || scope === '["","",""]') throw new Error('The Desk library scope is not ready. Refresh Pack Home first.')
    const agent = state.agents.find(item => item.workspace_id === preset.book.workspace_id)
    if (!agent || agent.status !== 'ready') throw new Error('This MoonBook is unavailable. Choose a ready Book before trying or saving.')
    if (agent.book_id !== preset.book.book_id || agent.version !== preset.book.version) {
      throw new Error('The MoonBook identity or version changed. Revise and reselect it before trying or saving.')
    }
    if (preset.capabilities.some(value => !agent.capabilities.includes(value))) {
      throw new Error('A selected capability is no longer declared. Revise the selection.')
    }
  }
  const resetCsv = () => { csvGeneration++; state.csv = null; state.csvLoading = false }
  const resetImport = () => { importGeneration++; state.portableImport = null; state.importLoading = false }
  const invalidateFilePreviews = () => { state.taskPreview = ''; if (state.csv) { state.csv.inspected = []; state.csv.selected = null } }
  const resetFiles = () => { taskFileGeneration++; state.taskFileLoading = false; state.taskFiles = []; invalidateFilePreviews() }
  const taskBrief = (preset, task) => withTaskFiles(specialistBrief(preset, task), state.taskFiles)
  const inspectCsvRows = (csv, corrections = csv.corrections) => inspectTaskCsv(csv.creator.task_form, csv, csv.mapping, corrections).map(row => {
    let brief = ''
    if (!row.errors.length) {
      try { brief = taskBrief(csv.creator, row.task) } catch (error) { row.errors.push(error.message) }
      if (brief.length > 48000) { row.errors.push('The filled brief exceeds the 48,000-character chat limit.'); brief = '' }
    }
    return { ...row, brief }
  })
  const savedTaskCreator = () => {
    const creator = state.created
    if (!creator?.task_form || !state.records.some(record => JSON.stringify(record) === JSON.stringify(creator))) throw new Error('Choose an unchanged saved creator with a task form, or save this revision first.')
    if (!storage || state.storage_error || storage.getItem(storageKey) !== storeSnapshot) throw new Error('Saved creators changed or storage is unavailable. Close and reopen before restoring a checkpoint; your current batch is kept.')
    return creator
  }
  const resetTask = () => { state.stageReplacement = null; resetFiles(); resetImport(); state.taskValues = {}; state.taskPreview = ''; resetCsv() }
  const newDraft = () => { if (state.preparing || state.refinement) return false; state.draft = { name: '', purpose: '', example: '', book: null,
    capabilities: [], knowledge_paths: [] }; state.created = null; state.editing = true;
    resetTask(); state.hits = []; state.prepared = ''; state.status = ''; baseRecord = null; searchGeneration++; notify() }
  const prepareBrief = async (preset, preparedPrompt) => {
    if (!state.open || state.preparing || state.csvLoading || state.importLoading || state.taskFileLoading) return false
    preset = clone(preset)
    state.preparing = true; state.status = 'Checking the Book before preparing your example…'; const current = ++tryGeneration; notify()
    try {
      const agents = await loadCatalog()
      if (current !== tryGeneration || !state.open) return false
      state.agents = agents; validateBook(preset)
      const record = clone(preset), requestId = id()
      const prompt = preparedPrompt
      if (prompt.length > 48000) throw new Error('The specialist brief exceeds the 48,000-character chat limit. Revise it before trying.')
      state.pending = requestId
      dispatch('prepare-specialist', record.book.workspace_id, prompt, JSON.stringify({
        request_id: requestId, library_scope: scope, book_id: record.book.book_id, version: record.book.version,
        capabilities: record.capabilities, knowledge_paths: record.knowledge_paths,
      }), '')
      // The native UI reducer acknowledges preparation; dispatch is not a run receipt.
      return true
    } catch (error) { if (current === tryGeneration) { state.preparing = false; state.pending = ''; return fail(error) } return false }
  }
  const replacementDraft = (index, sourceId) => {
    const draft = state.draft, stages = draft?.composition?.stages
    if (!Number.isInteger(index) || !stages?.[index]) throw new Error('Choose an existing stage to replace.')
    if (!storage || state.storage_error || storage.getItem(storageKey) !== storeSnapshot) throw new Error('Saved specialists changed or storage is unavailable. Close and reopen before reviewing a replacement; your draft is kept.')
    const source = state.records.find(record => record.id === sourceId)
    if (!source || source.composition || !validPreset(source)) throw new Error('Choose a saved single-stage specialist for the replacement.')
    if (source.id === state.created?.id || stages.some((stage, position) => position !== index && stage.source.id === source.id)) throw new Error('This replacement would duplicate another stage or include the creator itself.')
    if (!sameCompositionBook(draft.book, source.book)) throw new Error('The replacement must use the same exact MoonBook and version. Your draft is unchanged.')
    validateBook(source)
    if (JSON.stringify(stages[index].source) === JSON.stringify(source)) throw new Error('This stage already uses that exact saved definition.')
    const candidate = clone(draft)
    candidate.composition.stages[index].source = clone(source)
    const selections = compositionSelections(candidate.composition)
    if (selections.knowledge_paths.length > 20 || selections.capabilities.length > 16) throw new Error('The replacement would exceed 20 knowledge files or 16 capabilities. Your draft is unchanged.')
    Object.assign(candidate, selections)
    return candidate
  }
  const api = {
    state, selectedAgent, taskBrief,
    improveTaskCreator(index) {
      if (!state.open || state.editing || state.refinement || state.preparing || state.loading || state.csvLoading || state.importLoading || state.taskFileLoading || state.csv?.editor || state.csv?.resultEditor) return false
      try {
        const { draft, context } = beginTaskRefinement(state.csv, index, specialistBrief)
        state.refinement = context; state.draft = draft; state.created = null; state.editing = true; baseRecord = null
        resetImport(); state.hits = []; state.prepared = ''; state.searching = false; searchGeneration++
        state.status = 'Write a concrete correction in Purpose, then Create specialist. This independent variant keeps the original creator and observation; retry uses the exact captured task and task files.'
        notify(); return true
      } catch (error) { return fail(error) }
    },
    prepareRefinedTask() {
      if (!state.open || state.editing || !state.refinement || !state.created || state.preparing) return false
      try {
        const prompt = refinedTaskBrief(state.refinement, state.created, specialistBrief)
        if (prompt !== state.refinement.preview) throw new Error('The corrected brief changed. Revise and create it again before retrying.')
        return prepareBrief(state.created, prompt)
      } catch (error) { return fail(error) }
    },
    returnToTaskObservations() {
      if (!state.open || !state.refinement || state.preparing) return false
      const source = state.refinement.source
      state.created = clone(source); state.draft = clone(source); state.editing = false; baseRecord = JSON.stringify(source)
      state.refinement = null; state.hits = []; state.prepared = ''; state.searching = false; searchGeneration++
      state.status = 'Returned to the original observation batch. Saved variants are kept; unsaved correction edits were discarded.'
      notify(); return true
    },
    taskObservationStatuses() {
      try { const rows = inspectCsvRows(state.csv); return (state.csv.observations || []).map(item => sameObservedTask(item, state.csv, rows[item.row_index])) } catch { return (state.csv?.observations || []).map(() => false) }
    },
    beginTaskObservation(index) {
      try {
        const csv = state.csv
        if (!state.open || state.editing || !csv || csv.editor || csv.resultEditor || state.preparing || state.csvLoading || state.taskFileLoading) return false
        const row = inspectCsvRows(csv)[index]
        if (!row || row.errors.length || csv.selected !== index || row.brief !== csv.inspected[index]?.brief) throw new Error('Inspect and select a valid current task before recording its response.')
        csv.resultEditor = { index, binding: captureTaskObservation(csv, index, row, 'placeholder', ''), output: '', notes: '' }
        state.status = 'Paste the response you observed separately. Saving records your observation, not a verified run or successful completion.'
        notify(); return true
      } catch (error) { return fail(error) }
    },
    editTaskObservation(key, value) {
      const editor = state.csv?.resultEditor
      if (!state.open || !editor || state.preparing || state.csvLoading || !['output', 'notes'].includes(key) || typeof value !== 'string') return false
      if (value.length > taskResultLimits[key]) return fail(new Error(`Keep ${key} within ${taskResultLimits[key]} characters. The prior text is kept.`))
      editor[key] = value; state.status = 'Observation edited locally; save it before exporting.'; return true
    },
    saveTaskObservation() {
      try {
        const csv = state.csv, editor = csv?.resultEditor
        if (!state.open || !editor || state.preparing || state.csvLoading || state.taskFileLoading) return false
        const row = inspectCsvRows(csv)[editor.index]
        if (!sameObservedTask(editor.binding, csv, row)) throw new Error('The task changed while this observation was being edited. Your response is kept. Restore the exact inputs/files or cancel and select the intended task again.')
        const observation = captureTaskObservation(csv, editor.index, row, editor.output, editor.notes)
        csv.observations = appendTaskObservation(csv, observation)
        // Session-local sidecar: results/checkpoint/creator export schemas stay
        // unchanged. Only successfully read and observed task files are copied.
        ;(csv.observationFiles ||= [])[csv.observations.length - 1] = clone(state.taskFiles)
        csv.resultEditor = null
        if (!exploreTaskRows(csv).entries.some(entry => entry.index === csv.selected)) csv.selected = null
        state.status = `Recorded operator observation ${csv.observations.length}. No task was sent, marked successful or accepted as Book knowledge.`
        notify(); return true
      } catch (error) { return fail(error) }
    },
    cancelTaskObservation() {
      if (!state.open || !state.csv?.resultEditor || state.preparing || state.csvLoading) return false
      state.csv.resultEditor = null; state.status = 'Unfinished observation cancelled; saved observations are kept.'; notify(); return true
    },
    exportTaskResults(format, deliver) {
      try {
        if (!state.open || (state.editing && !state.refinement) || !state.csv || state.preparing || state.csvLoading || state.taskFileLoading) return false
        let rows
        try { rows = inspectCsvRows(state.csv) } catch (error) { rows = state.csv.rows.map(() => ({ errors: [error.message] })) }
        const packet = exportTaskResults(state.csv, rows, format, validPreset)
        if (deliver) deliver(packet)
        state.status = deliver ? 'Task results download requested. Check browser downloads. It contains operator responses, captured task inputs and complete briefs, including selected task-file text. JSON/Markdown preserve exact text; CSV text cells are JSON literals to prevent formula execution.' : 'Task results prepared from operator observations.'
        notify(); return packet
      } catch (error) { return fail(error) }
    },
    async open() {
      state.open = true; readStore(); if (!state.draft) newDraft()
      state.loading = true; const current = ++generation; notify()
      try {
        const agents = await loadCatalog()
        if (current !== generation || !state.open) return
        state.agents = agents; state.status = agents.length ? '' : 'Create or import a MoonBook first, then return here.'
      } catch (error) { if (current === generation && state.open) fail(error) }
      finally { if (current === generation) { state.loading = false; notify() } }
    },
    close() { state.stageReplacement = null; state.open = false; state.preparing = false; state.pending = ''; generation++; searchGeneration++; tryGeneration++; csvGeneration++; importGeneration++; taskFileGeneration++; state.taskFileLoading = false; state.csvLoading = false; state.importLoading = false; notify() },
    newDraft,
    exportSaved(sourceId, deliver) {
      try {
        if (!state.open || state.preparing) return false
        const source = state.records.find(record => record.id === sourceId)
        if (!source) throw new Error('Choose a saved creator revision to export.')
        // Detect external saves rather than exporting an old in-memory revision.
        if (!storage || state.storage_error || storage.getItem(storageKey) !== storeSnapshot) throw new Error('Saved creators changed or storage is unavailable. Close and reopen before exporting.')
        const packet = exportCreator(source, validPreset)
        if (deliver) deliver(packet)
        state.status = deliver ? 'Local download requested. Check your browser downloads. Only the selected saved definition is included; reference file contents and task inputs are excluded.' : 'Portable definition prepared from the selected saved revision.'
        notify(); return packet
      } catch (error) { return fail(error) }
    },
    async importCreatorFile(file) {
      if (!state.open || state.loading || state.preparing || state.refinement) return false
      const current = ++importGeneration
      state.portableImport = null; state.importLoading = true; state.status = 'Reading local creator definition…'; notify()
      try {
        if (!file || typeof file.arrayBuffer !== 'function' || !Number.isFinite(file.size) || file.size < 0 || file.size > portableByteLimit) throw new Error('Choose a UTF-8 creator JSON file no larger than 256 KiB.')
        const bytes = await file.arrayBuffer()
        if (current !== importGeneration || !state.open) return false
        if (bytes.byteLength > portableByteLimit) throw new Error('Choose a creator JSON file no larger than 256 KiB.')
        let content
        try { content = new TextDecoder('utf-8', { fatal: true }).decode(bytes) } catch { throw new Error('The creator file must contain valid UTF-8 text.') }
        const creator = parseCreator(content, validPreset)
        if (specialistBrief(creator).length > 48000) throw new Error('The imported brief exceeds the 48,000-character chat limit.')
        // Review is retained even if the catalog is temporarily unavailable.
        state.portableImport = { creator, name: text(file.name).slice(0, 200), workspace: '' }
        const agents = await loadCatalog()
        if (current !== importGeneration || !state.open) return false
        state.agents = agents
        state.status = matchingCreatorBooks(creator, agents).length
          ? 'Review the imported definition and explicitly choose its installed Book. Use imported definition replaces only the current draft; Create and Save remain separate.'
          : 'No compatible installed Book is ready. The exact Book ID, version and preferred capabilities must match. Nothing has been imported or saved.'
        return true
      } catch (error) { if (current === importGeneration && state.open) return fail(error); return false }
      finally { if (current === importGeneration) { state.importLoading = false; notify() } }
    },
    chooseImportBook(workspace) {
      const pending = state.portableImport
      if (!state.open || !pending || state.importLoading || state.preparing) return false
      pending.workspace = matchingCreatorBooks(pending.creator, state.agents).some(agent => agent.workspace_id === workspace) ? workspace : ''
      state.status = ''; notify(); return !!pending.workspace
    },
    cancelCreatorImport() {
      if (!state.open || state.preparing) return false
      resetImport(); state.status = 'Creator import cancelled. Your current draft and saved creators are unchanged.'; notify(); return true
    },
    async useImportedCreator() {
      const pending = state.portableImport
      if (!state.open || state.loading || !pending || state.importLoading || state.preparing || state.refinement) return false
      const current = ++importGeneration
      const before = JSON.stringify([state.draft, state.created, state.editing, state.taskValues, state.csv])
      try {
        if (!pending.workspace) throw new Error('Choose an exact compatible installed Book before using this definition.')
        state.importLoading = true; state.status = 'Rechecking the selected installed Book…'; notify()
        const agents = await loadCatalog()
        if (current !== importGeneration || !state.open || state.portableImport !== pending) return false
        state.agents = agents
        if (before !== JSON.stringify([state.draft, state.created, state.editing, state.taskValues, state.csv])) throw new Error('Your current draft changed during the Book check. Review it, then use the imported definition again if you want to replace it.')
        const agent = matchingCreatorBooks(pending.creator, agents).find(agent => agent.workspace_id === pending.workspace)
        if (!agent) { pending.workspace = ''; throw new Error('The selected Book is no longer compatible or ready. Choose its exact identity and version again; your current work is unchanged.') }
        const draft = bindImportedCreator(pending.creator, agent)
        validateBook(draft)
        state.draft = draft; state.created = null; state.editing = true; baseRecord = null
        resetTask(); state.hits = []; state.searching = false; searchGeneration++; state.prepared = ''
        state.status = 'Imported into an independent draft. Review the fields, then Create specialist, Try in chat and Save specialist. Nothing has been saved or sent.'
        notify(); return true
      } catch (error) { if (current === importGeneration && state.open) return fail(error); return false }
      finally { if (current === importGeneration) { state.importLoading = false; notify() } }
    },
    forkSaved(sourceId) {
      try {
        if (state.preparing || state.refinement) return false
        const source = state.records.find(record => record.id === sourceId)
        if (!source || !validPreset(source)) throw new Error('Choose a saved specialist to create a variant.')
        const draft = clone(source)
        delete draft.id; delete draft.revision; delete draft.contract
        draft.name = source.name.slice(0, 92) + ' variant'
        delete draft.imported_from // This new variant's immediate source is the local saved creator.
        draft.variant = { contract: 'moondesk.specialist-variant.v1', source_id: source.id,
          source_revision: source.revision, source_name: source.name }
        state.draft = draft; state.created = null; state.editing = true; baseRecord = null
        resetTask(); state.hits = []; state.prepared = ''; state.searching = false; searchGeneration++
        state.status = 'Name and edit this independent variant, then create, try and save it. The saved source is unchanged.'
        notify(); return true
      } catch (error) { return fail(error) }
    },
    newComposition() {
      if (state.preparing || state.refinement) return false
      newDraft()
      state.draft.composition = { contract: compositionContract, stages: [] }
      state.status = 'Choose 2–4 saved single-stage specialists from the same Book and version, then define their outputs.'
      notify(); return true
    },
    addStage(sourceId) {
      try {
        if (!state.editing || !state.draft?.composition || state.preparing) return false
        const source = state.records.find(item => item.id === sourceId)
        if (!source || source.composition || !validPreset(source)) throw new Error('Choose a saved single-stage specialist.')
        validateBook(source)
        const stages = state.draft.composition.stages
        if (stages.length >= maxCompositionStages) throw new Error('Compose at most four stages.')
        if (stages.some(stage => stage.source.id === source.id)) throw new Error('This specialist is already a stage.')
        if (state.created?.id === source.id) throw new Error('A specialist cannot contain itself.')
        if (stages.length && !sameCompositionBook(state.draft.book, source.book)) throw new Error('All stages must use the same exact MoonBook and version. Your existing stages are unchanged.')
        const stage = { source: clone(source), handoff: '' }
        const composition = { contract: compositionContract, stages: [...stages, stage] }
        const selections = compositionSelections(composition)
        if (selections.knowledge_paths.length > 20 || selections.capabilities.length > 16) throw new Error('Together these stages exceed 20 knowledge files or 16 capabilities. Revise the source specialists first.')
        state.stageReplacement = null; state.draft.composition = composition; state.draft.book = clone(source.book)
        Object.assign(state.draft, selections); state.status = 'Added a saved revision snapshot. Enter its required output or handoff.'
        notify(); return true
      } catch (error) { return fail(error) }
    },
    previewStageReplacement(index, sourceId) {
      if (!state.open || !state.editing || state.loading || state.preparing || state.importLoading) return false
      state.stageReplacement = null
      try {
        const candidate = replacementDraft(index, sourceId)
        state.stageReplacement = { index, sourceId, before: JSON.stringify(state.draft), candidate }
        state.status = 'Compare the stage briefs and their selected references. Apply keeps this stage’s position and handoff; Create and Save remain separate.'
        notify(); return true
      } catch (error) { return fail(error) }
    },
    cancelStageReplacement() {
      if (!state.open || state.preparing) return false
      state.stageReplacement = null; state.status = 'Replacement cancelled. Your composition is unchanged.'; notify(); return true
    },
    applyStageReplacement() {
      const pending = state.stageReplacement
      if (!state.open || !state.editing || !pending || state.loading || state.preparing || state.importLoading) return false
      try {
        if (JSON.stringify(state.draft) !== pending.before) throw new Error('Your draft changed after the comparison. Review the replacement again; your edits are kept.')
        const candidate = replacementDraft(pending.index, pending.sourceId)
        if (JSON.stringify(candidate) !== JSON.stringify(pending.candidate)) throw new Error('The saved source changed after the comparison. Review the replacement again.')
        state.draft = candidate; state.stageReplacement = null
        state.status = 'Stage replaced in this draft, with its handoff and position kept. Review the handoff for the new stage, then Create and Save the revised creator.'
        notify(); return true
      } catch (error) { state.stageReplacement = null; return fail(error) }
    },
    editHandoff(index, value) {
      const stage = Number.isInteger(index) && state.editing && state.draft?.composition?.stages[index]
      if (stage && !state.preparing) { stage.handoff = text(value); state.status = '' }
    },
    moveStage(index, direction) {
      const stages = state.editing && state.draft?.composition?.stages
      if (!stages || state.preparing || !Number.isInteger(index) || ![-1, 1].includes(direction) || !stages[index] || !stages[index + direction]) return false
      state.stageReplacement = null
      ;[stages[index], stages[index + direction]] = [stages[index + direction], stages[index]]
      Object.assign(state.draft, compositionSelections(state.draft.composition)); state.status = 'Stage order updated.'; notify(); return true
    },
    removeStage(index) {
      const stages = state.editing && state.draft?.composition?.stages
      if (!stages || state.preparing || !Number.isInteger(index) || !stages[index]) return false
      state.stageReplacement = null
      stages.splice(index, 1); Object.assign(state.draft, compositionSelections(state.draft.composition))
      if (!stages.length) state.draft.book = null
      state.status = 'Stage removed from this draft. Saved source specialists are unchanged.'; notify(); return true
    },
    edit(field, value) {
      if (!state.editing || !['name', 'purpose', 'example'].includes(field)) return
      state.draft[field] = text(value); state.status = ''
    },
    editTaskTemplate(value) {
      if (!state.editing || state.preparing) return false
      if (text(value).trim()) state.draft.task_form = { contract: 'moondesk.specialist-task-form.v1', template: text(value) }
      else delete state.draft.task_form
      state.status = ''
    },
    async addTaskFile(file) {
      if (!state.open || state.editing || !state.created || state.preparing || state.refinement) return false
      const current = ++taskFileGeneration, creator = state.created
      state.taskFileLoading = true; state.status = 'Reading task-only local text…'; notify()
      try {
        const snapshot = await readTaskFile(file)
        if (current !== taskFileGeneration || !state.open || state.created !== creator) return false
        const files = [...state.taskFiles, snapshot]
        withTaskFiles(specialistBrief(creator), files)
        state.taskFiles = files; invalidateFilePreviews()
        state.status = 'Task file added. Review the exact brief; preview filled tasks or inspect CSV rows again. Nothing has been uploaded, saved or sent.'
        return true
      } catch (error) { if (current === taskFileGeneration && state.open) return fail(error); return false }
      finally { if (current === taskFileGeneration) { state.taskFileLoading = false; notify() } }
    },
    removeTaskFile(index) {
      if (!state.open || state.preparing || !Number.isInteger(index) || !state.taskFiles[index]) return false
      taskFileGeneration++; state.taskFileLoading = false
      state.taskFiles.splice(index, 1); invalidateFilePreviews()
      state.status = 'Task file removed. Review the refreshed brief before preparing.'; notify(); return true
    },
    clearTaskFiles() {
      if (!state.open || state.preparing) return false
      resetFiles(); state.status = 'Task files cleared. The creator and Book are unchanged.'; notify(); return true
    },
    editTaskInput(key, value) {
      if (state.editing || state.preparing || !state.created?.task_form || !taskInputKeys(state.created.task_form.template).includes(key)) return false
      state.taskValues[key] = text(value); state.taskPreview = ''; state.status = 'Inputs changed. Preview the filled task before preparing it.'
      // Do not rerender while typing; preparation always rechecks the preview.
      return true
    },
    previewTask() {
      try {
        if (state.editing || state.preparing || state.taskFileLoading || !state.created) return false
        const task = fillTaskForm(state.created.task_form, state.taskValues)
        const brief = taskBrief(state.created, task)
        if (brief.length > 48000) throw new Error('The filled brief exceeds the 48,000-character chat limit.')
        state.taskPreview = brief; state.status = 'Review the exact filled brief below. Preparing it will not change the saved creator.'; notify(); return true
      } catch (error) { state.taskPreview = ''; return fail(error) }
    },
    prepareTask() { return api.tryExample(true) },
    importTaskJsonl(file) { return api.importTaskCsv(file, 'jsonl') },
    async importTaskCsv(file, format = 'csv') {
      if (!state.open || state.editing || state.preparing || state.refinement) return false
      const current = ++csvGeneration
      try {
        const label = format === 'jsonl' ? 'JSONL' : 'CSV'
        const creator = state.created
        if (!creator?.task_form || !state.records.some(record => JSON.stringify(record) === JSON.stringify(creator))) throw new Error('Choose an unchanged saved creator with a task form, or save this revision first.')
        if (!file || typeof file.arrayBuffer !== 'function' || !Number.isFinite(file.size) || file.size < 0 || file.size > taskCsvLimits.bytes) throw new Error(`Choose UTF-8 ${label} no larger than 512 KiB.`)
        const snapshot = clone(creator)
        state.csvLoading = true; state.status = `Reading local ${label}…`; notify()
        const bytes = await file.arrayBuffer()
        if (current !== csvGeneration || !state.open || state.preparing || JSON.stringify(state.created) !== JSON.stringify(snapshot)) return false
        if (bytes.byteLength > taskCsvLimits.bytes) throw new Error(`Choose UTF-8 ${label} no larger than 512 KiB.`)
        let source
        try { source = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(bytes) } catch { throw new Error(`${label} must be valid UTF-8 text. Export it as UTF-8 and retry.`) }
        const csv = format === 'jsonl' ? parseTaskJsonl(source) : parseTaskCsv(source)
        state.csv = { ...csv, source: format === 'jsonl' ? csv.source : source, creator: snapshot, name: (text(file.name) + (format === 'jsonl' ? '.csv' : '')).slice(0, 200), mapping: {}, inspected: [], selected: null, corrections: {}, editor: null }
        state.status = (format === 'jsonl' ? 'JSONL string records converted to an editable CSV table. Table row 2 is JSONL line 1. Checkpoints preserve decoded fields, not original JSON spelling. ' : '') + 'Map each template input explicitly, then inspect the filled tasks. No rows have been sent.'
        return true
      } catch (error) { if (current === csvGeneration && state.open) return fail(error); return false }
      finally { if (current === csvGeneration) { state.csvLoading = false; notify() } }
    },
    exportTaskCheckpoint(deliver) {
      try {
        if (!state.open || state.editing || !state.csv || state.preparing || state.csvLoading || state.taskFileLoading) return false
        const packet = exportTaskBatch(state.csv, validPreset)
        if (deliver) deliver(packet)
        state.status = deliver ? 'Local task checkpoint download requested. Check your browser downloads. It includes original CSV cells, mappings, applied corrections and the creator definition. Task-only files, unsaved row edits and run results are excluded.' : 'Task checkpoint prepared. It contains task data; review private information before sharing it.'
        notify(); return packet
      } catch (error) { return fail(error) }
    },
    async importTaskCheckpoint(file) {
      if (!state.open || state.loading || state.editing || state.preparing || state.refinement) return false
      const current = ++csvGeneration
      try {
        const snapshot = clone(savedTaskCreator())
        if (state.taskFiles.length || state.taskFileLoading) throw new Error('Clear task-only files before restoring a checkpoint, then add the files you intend to use again. Your current batch and files are kept.')
        if (!file || typeof file.arrayBuffer !== 'function' || !Number.isFinite(file.size) || file.size < 0 || file.size > taskBatchByteLimit) throw new Error('Choose a UTF-8 task checkpoint no larger than 4 MiB.')
        state.csvLoading = true; state.status = 'Reading local task checkpoint…'; notify()
        const bytes = await file.arrayBuffer()
        if (current !== csvGeneration || !state.open || state.preparing || JSON.stringify(state.created) !== JSON.stringify(snapshot)) return false
        if (bytes.byteLength > taskBatchByteLimit) throw new Error('Choose a UTF-8 task checkpoint no larger than 4 MiB.')
        savedTaskCreator()
        if (state.taskFiles.length || state.taskFileLoading) throw new Error('Task-only files changed while reading. Clear them before restoring the checkpoint; your current work is kept.')
        let content
        try { content = new TextDecoder('utf-8', { fatal: true }).decode(bytes) } catch { throw new Error('The task checkpoint must contain valid UTF-8 text.') }
        const csv = parseTaskBatch(content, snapshot, validPreset)
        // Applied corrections must still fit a complete brief. Other original
        // invalid rows remain repairable, and no preview or selection is trusted.
        if (Object.keys(csv.corrections).length) {
          const rows = inspectCsvRows(csv)
          for (const index of Object.keys(csv.corrections)) if (rows[index].errors.length) throw new Error(rows[index].errors.join(' '))
        }
        state.csv = csv
        state.status = `Restored ${csv.rows.length} task rows with ${Object.keys(csv.corrections).length} corrected row(s). Inspect CSV tasks, select a row and review its fresh brief. Add task-only files again if needed. Nothing has been sent or marked complete.`
        return true
      } catch (error) { if (current === csvGeneration && state.open) return fail(error); return false }
      finally { if (current === csvGeneration) { state.csvLoading = false; notify() } }
    },
    mapTaskCsv(key, column) {
      const csv = state.csv
      if (!state.open || !csv || state.preparing || state.csvLoading || !taskInputKeys(csv.creator.task_form.template).includes(key)) return false
      if (csv.editor || Object.keys(csv.corrections).length) return fail(new Error('Cancel the row edit and reset row corrections before changing column mapping. Your corrections are kept.'))
      if (column === null) delete csv.mapping[key]
      else if (Number.isInteger(column) && column >= 0 && column < csv.headers.length) csv.mapping[key] = column
      else return false
      csv.inspected = []; csv.selected = null
      state.status = 'Mapping changed. Inspect rows again before selecting a task.'; notify(); return true
    },
    inspectTaskCsv() {
      try {
        const csv = state.csv
        if (!state.open || !csv || csv.editor || state.preparing || state.csvLoading || state.taskFileLoading) return false
        csv.selected = null; csv.inspected = []
        csv.inspected = inspectCsvRows(csv)
        const ready = csv.inspected.filter(row => !row.errors.length).length
        state.status = `${ready} of ${csv.rows.length} rows ready. Inspect a filled task and select one to review its exact brief.`
        notify(); return true
      } catch (error) { return fail(error) }
    },
    exploreTaskCsv(options) {
      const csv = state.csv
      if (!state.open || state.editing || !csv || csv.editor || csv.resultEditor || state.preparing || state.csvLoading || state.taskFileLoading) return false
      try {
        const checked = validateTaskExploration(csv.creator.task_form, options)
        csv.exploration = checked; csv.selected = null
        const result = exploreTaskRows(csv)
        state.status = result.inspected ? `Showing ${result.entries.length} of ${result.total} tasks. Source row numbers are unchanged. Select a visible row to review its exact brief.` : 'Task exploration set. Inspect CSV tasks to show current rows.'
        notify(); return true
      } catch (error) { return fail(error) }
    },
    beginTaskCsvRowEdit(index) {
      const csv = state.csv, row = csv?.inspected[index]
      if (!state.open || !Number.isInteger(index) || !row || csv.editor || state.preparing || state.csvLoading || state.taskFileLoading) return false
      if (csv.rows[index].cells.length !== csv.headers.length) return fail(new Error('This row has a different number of cells from the header. Correct the CSV structure and reimport it; no cells will be silently discarded.'))
      csv.editor = { index, values: Object.fromEntries(taskInputKeys(csv.creator.task_form.template).map(key => [key, text(row.values[key])])) }
      csv.selected = null
      state.status = `Edit task inputs for CSV row ${row.number}. Apply validates a fresh brief; the imported file and saved creator stay unchanged.`
      notify(); return true
    },
    editTaskCsvRowInput(key, value) {
      const editor = state.csv?.editor
      if (!state.open || !editor || state.preparing || state.csvLoading || typeof value !== 'string' || value.length > 4000 || !Object.hasOwn(editor.values, key)) return false
      editor.values[key] = value; state.status = 'Row edit is pending. Apply or cancel it before selecting a task.'
      return true
    },
    cancelTaskCsvRowEdit() {
      const csv = state.csv
      if (!state.open || !csv?.editor || state.preparing || state.csvLoading) return false
      csv.editor = null; csv.selected = null; state.status = 'Pending row edit cancelled. Previously applied corrections are kept. Select a row again to prepare it.'
      notify(); return true
    },
    applyTaskCsvRowEdit() {
      const csv = state.csv, editor = csv?.editor
      if (!state.open || !editor || state.preparing || state.csvLoading || state.taskFileLoading) return false
      try {
        const corrections = { ...csv.corrections, [editor.index]: clone(editor.values) }
        const rows = inspectCsvRows(csv, corrections), row = rows[editor.index]
        if (row.errors.length) throw new Error(row.errors.join(' '))
        if (!row.corrected.length) delete corrections[editor.index]
        csv.corrections = corrections; csv.inspected = rows; csv.editor = null; csv.selected = null
        state.status = `CSV row ${row.number} validated with ${row.corrected.length} corrected input(s). Select that row to review the refreshed exact brief before preparing.`
        notify(); return true
      } catch (error) { return fail(error) }
    },
    resetTaskCsvRow(index) {
      const csv = state.csv
      if (!state.open || !csv || csv.editor || !Number.isInteger(index) || !Object.hasOwn(csv.corrections, index) || state.preparing || state.csvLoading || state.taskFileLoading) return false
      delete csv.corrections[index]; csv.inspected = []; csv.selected = null
      state.status = `CSV row ${csv.rows[index].number} restored to its imported inputs. Inspect rows again; the original errors may return.`
      notify(); return true
    },
    resetTaskCsvCorrections() {
      const csv = state.csv
      if (!state.open || !csv || csv.editor || state.preparing || state.csvLoading || state.taskFileLoading) return false
      csv.corrections = {}; csv.inspected = []; csv.selected = null
      state.status = 'All row corrections reset. Imported CSV data is unchanged. Inspect rows again or change the mapping.'
      notify(); return true
    },
    selectTaskCsvRow(index) {
      const csv = state.csv, row = csv?.inspected[index]
      if (!state.open || !Number.isInteger(index) || !row || csv.editor || row.errors.length || state.preparing || state.csvLoading) return false
      if (!exploreTaskRows(csv).entries.some(entry => entry.index === index)) return false
      csv.selected = index; state.status = `CSV row ${row.number} selected. Review its exact brief before preparing it in chat.`; notify(); return true
    },
    prepareTaskCsvRow() {
      try {
        const csv = state.csv, row = csv?.inspected[csv.selected]
        if (!state.open || !csv || !row || csv.editor || row.errors.length || state.editing || state.preparing || state.csvLoading) return false
        if (!exploreTaskRows(csv).entries.some(entry => entry.index === csv.selected)) throw new Error('Select a visible task in the current exploration before preparing.')
        const fresh = inspectTaskCsv(csv.creator.task_form, csv, csv.mapping, csv.corrections)[csv.selected]
        if (fresh.errors.length || taskBrief(csv.creator, fresh.task) !== row.brief || JSON.stringify(state.created) !== JSON.stringify(csv.creator)) throw new Error('The selected CSV task changed. Inspect and select it again before preparing.')
        return prepareBrief(csv.creator, row.brief)
      } catch (error) { return fail(error) }
    },
    clearTaskCsv() {
      if (!state.open || state.preparing || state.refinement) return false
      resetCsv(); state.status = 'CSV tasks cleared from this page session. Saved creators are unchanged.'; notify(); return true
    },
    chooseBook(workspaceId) {
      if (!state.editing || state.draft?.composition) return
      const agent = state.agents.find(item => item.workspace_id === workspaceId)
      state.draft.book = agent ? { workspace_id: agent.workspace_id, book_id: agent.book_id,
        name: agent.name, version: agent.version } : null
      state.draft.capabilities = []; state.draft.knowledge_paths = []; state.hits = []
      state.status = ''; searchGeneration++; state.searching = false; notify()
    },
    toggleCapability(value, selected) {
      if (!state.editing || state.draft?.composition || !selectedAgent()?.capabilities.includes(value)) return
      state.draft.capabilities = selected ? unique([...state.draft.capabilities, value]) : state.draft.capabilities.filter(item => item !== value)
    },
    toggleKnowledge(path, selected) {
      if (!state.editing || state.draft?.composition || !safePath(path)) return
      if (selected && !state.hits.some(hit => hit.path === path)) return
      if (selected && !state.draft.knowledge_paths.includes(path) && state.draft.knowledge_paths.length >= 20) return fail(new Error('Select at most 20 knowledge files.'))
      state.draft.knowledge_paths = selected ? unique([...state.draft.knowledge_paths, path]) : state.draft.knowledge_paths.filter(item => item !== path)
      notify()
    },
    async search(query) {
      const book = state.draft?.book
      if (state.draft?.composition) return false
      if (!state.editing || !book || !text(query).trim()) return fail(new Error('Choose a Book and enter a knowledge search.'))
      const current = ++searchGeneration, workspaceId = book.workspace_id
      state.searching = true; state.hits = []; notify()
      try {
        const params = new URLSearchParams({ query: text(query).trim(), contract: 'pages-search.v1', workspace: workspaceId, mode: 'files' })
        const response = await request('/api/search?' + params)
        if (!response.ok) throw new Error('Knowledge search is unavailable. Your selections are preserved.')
        const payload = await response.json()
        if (current !== searchGeneration || !state.open || state.draft?.book?.workspace_id !== workspaceId) return
        if (payload.contract !== 'pages-search.v1' || payload.ok !== true || payload.workspace_id !== workspaceId ||
            !Array.isArray(payload.hits) || payload.hits.some(hit => hit.workspace_id !== workspaceId)) {
          throw new Error('Knowledge search returned an unavailable or mismatched Book scope.')
        }
        const seen = new Set()
        state.hits = payload.hits.filter(hit => {
          if (!safePath(hit.path) || seen.has(hit.path)) return false
          seen.add(hit.path); return true
        }).slice(0, 80)
        state.status = state.hits.length ? 'Choose the knowledge files to attach to each example.' : 'No wiki or raw knowledge files matched.'
      } catch (error) { if (current === searchGeneration && state.open) fail(error) }
      finally { if (current === searchGeneration) { state.searching = false; notify() } }
    },
    create() {
      try {
        if (state.preparing || state.importLoading || !state.editing) return false
        const previous = state.created
        const record = { ...clone(state.draft), contract, id: previous?.id || id(), revision: previous ? previous.revision + 1 : 1 }
        if (!previous && (state.records.some(item => item.id === record.id) || record.imported_from?.source_id === record.id)) throw new Error('A new specialist needs a distinct identity. Create it again to request a new ID.')
        if (record.variant && record.name.trim() === record.variant.source_name.trim()) throw new Error('Give the variant a different name from its saved source.')
        if (record.task_form) taskInputKeys(record.task_form.template)
        if (!validPreset(record)) throw new Error(record.composition
          ? 'Enter a name, purpose and example; choose 2–4 compatible stages and give every stage an output or handoff (at most 2,000 characters). Purpose and example must each be under 8,000 characters.'
          : 'Enter a name, purpose, example, and select a MoonBook. Keep purpose and example under 8,000 characters each.')
        if (specialistBrief(record).length > 48000) throw new Error('The specialist brief exceeds the 48,000-character chat limit. Shorten the overall task or use shorter source specialists.')
        validateBook(record)
        if (state.refinement) state.refinement.preview = refinedTaskBrief(state.refinement, record, specialistBrief)
        else resetTask()
        state.created = record; state.editing = false; state.prepared = ''
        state.status = state.refinement ? 'Corrected variant created locally. Review the same captured task below, prepare it in chat, and use ordinary Send. Save specialist keeps the correction for future work; no improvement has been verified.' : 'Specialist created locally. Review the exact brief, try it in chat, or save it.'; notify(); return true
      } catch (error) { return fail(error) }
    },
    revise() {
      if (!state.created || state.preparing) return
      if (state.refinement) state.refinement.preview = ''
      else resetTask()
      state.draft = clone(state.created); state.editing = true; state.prepared = ''; state.status = 'Revise the fields, then create the next revision.'; notify()
    },
    save() {
      try {
        if (!state.created || state.editing || state.preparing || state.importLoading) return false
        if (state.storage_error || !storage) throw new Error(state.storage_error || 'Browser storage is unavailable.')
        validateBook(state.created)
        if (storage.getItem(storageKey) !== storeSnapshot) throw new Error('Saved specialists changed in another window. Close and reopen the builder before saving; your current draft is kept.')
        const existing = state.records.find(item => item.id === state.created.id)
        if (existing && JSON.stringify(existing) !== baseRecord && JSON.stringify(existing) !== JSON.stringify(state.created)) throw new Error('A newer revision of this specialist was saved elsewhere. Reopen that saved revision before editing it.')
        const records = [clone(state.created), ...state.records.filter(item => item.id !== state.created.id)]
        if (records.length > maxRecords) throw new Error('This browser already has 64 specialists.')
        const raw = JSON.stringify({ contract: 'moondesk.specialist-library.v1', records })
        if (raw.length > 2000000) throw new Error('Saved specialists exceed the local size limit.')
        storage.setItem(storageKey, raw)
        if (storage.getItem(storageKey) !== raw) throw new Error('The local save could not be verified.')
        storeSnapshot = raw; state.records = records; baseRecord = JSON.stringify(state.created); state.status = 'Saved in this browser. Reopen it from Saved specialists on this Desk origin.'; notify(); return true
      } catch (error) { return fail(error) }
    },
    reopen(id) {
      if (state.preparing || state.refinement) return
      const record = state.records.find(item => item.id === id)
      if (!record) return
      resetTask(); baseRecord = JSON.stringify(record); state.created = clone(record); state.draft = clone(record); state.editing = false; state.prepared = ''; state.hits = []
      state.status = 'Reopened saved revision ' + record.revision + '. Knowledge references are resolved when the chat runs.'; notify()
    },
    async tryExample(useTask = false) {
      if (!state.created || state.editing || state.preparing || state.refinement) return false
      let preparedPrompt
      try {
        preparedPrompt = useTask ? taskBrief(state.created, fillTaskForm(state.created.task_form, state.taskValues)) : taskBrief(state.created)
        if (useTask && (!state.taskPreview || state.taskPreview !== preparedPrompt)) throw new Error('Preview the current filled task before preparing it.')
      } catch (error) { return fail(error) }
      return prepareBrief(state.created, preparedPrompt)
    },
    receive(action, payload) {
      let reply
      try { reply = JSON.parse(payload) } catch { return }
      if (!state.pending || reply.request_id !== state.pending) return
      state.preparing = false; state.pending = ''
      if (action === 'specialist-prepared') {
        if (state.taskFiles.length) resetFiles()
        state.prepared = 'Example prepared in chat. Click Send there to run it. No trial result has been recorded.'
        state.status = state.prepared; state.open = false; notify()
      } else { fail(new Error(reply.message || 'The example could not be prepared.')) }
    },
  }
  return api
}

let mounted
export function openSpecialistBuilder(options = {}) {
  if (mounted && mounted.scope !== options.scope) { mounted.controller.close(); mounted = null }
  if (!mounted) mounted = mountSpecialistBuilder(options)
  void mounted.controller.open()
}
export function receiveSpecialistSignal(action, value) { mounted?.controller.receive(action, value) }

export function mountSpecialistBuilder({ document: doc = globalThis.document, download = packet => downloadCreator(packet, { document: doc }), ...options } = {}) {
  let panel, overlay, returnFocus, app, wasInert, taskPreviewNode, renderEpoch = 0
  const el = (tag, value = '', className = '') => { const node = doc.createElement(tag); node.textContent = value; node.className = className; return node }
  const button = (label, action, disabled = false) => { const epoch = renderEpoch; const node = el('button', label, 'secondary-button'); node.type = 'button'; node.disabled = disabled; node.addEventListener('click', event => { if (epoch === renderEpoch) action(event) }); return node }
  const status = el('p', '', 'status-line'); status.setAttribute('role', 'status'); status.setAttribute('aria-live', 'polite')
  const controller = createSpecialistController({ ...options, changed: render })
  const field = (labelText, name, value, multiline = false, update = value => controller.edit(name, value)) => {
    const epoch = renderEpoch
    const label = el('label', labelText, 'specialist-field'), input = el(multiline ? 'textarea' : 'input')
    input.name = name; input.value = value; input.maxLength = name === 'name' ? 100 : name.startsWith('handoff-') ? 2000 : maxText
    input.addEventListener('input', () => { if (epoch === renderEpoch) update(input.value) }); label.append(input); return label
  }
  const checkbox = (labelText, checked, action) => {
    const epoch = renderEpoch
    const label = el('label', '', 'specialist-choice'), input = el('input'); input.type = 'checkbox'; input.checked = checked
    input.addEventListener('change', () => { if (epoch === renderEpoch) action(input.checked) }); label.append(input, el('span', labelText)); return label
  }
  function render(state) {
    renderEpoch++
    const epoch = renderEpoch
    if (!state.open) { if (panel) { overlay.remove(); panel = null; if (app) app.inert = wasInert; if (returnFocus?.isConnected) returnFocus.focus() } return }
    if (!panel) {
      returnFocus = doc.activeElement
      panel = el('section', '', 'specialist-builder'); panel.setAttribute('role', 'dialog'); panel.setAttribute('aria-modal', 'true')
      panel.setAttribute('aria-label', 'Build your specialist'); panel.dataset.testid = 'specialist-builder'
      panel.addEventListener('keydown', event => {
        if (event.key === 'Escape') { event.preventDefault(); controller.close() }
        if (event.key === 'Tab') {
          const focusable = [...panel.querySelectorAll('button, input, textarea, select, summary')].filter(item => !item.disabled)
          const first = focusable[0], last = focusable.at(-1)
          if (event.shiftKey && doc.activeElement === first) { event.preventDefault(); last?.focus() }
          else if (!event.shiftKey && doc.activeElement === last) { event.preventDefault(); first?.focus() }
        }
      })
      overlay = el('div', '', 'specialist-overlay'); overlay.append(panel); doc.body.append(overlay)
      app = doc.getElementById?.('app'); if (app) { wasInert = app.inert; app.inert = true }
    }
    const focusedName = panel.contains(doc.activeElement) ? doc.activeElement.name : ''
    panel.replaceChildren()
    const head = el('header', '', 'specialist-header')
    head.append(el('h2', 'Build your specialist'), button('Close', () => controller.close()))
    panel.append(head, el('p', 'A reusable task brief tied to one installed MoonBook. Saved only in this browser; it does not install a pack or change accepted Book behavior.'))
    const saved = el('section')
    saved.append(el('h3', 'Saved specialists'), button('New specialist', () => controller.newDraft(), state.preparing || !!state.refinement),
      button('Compose specialists', () => controller.newComposition(), state.preparing || !!state.refinement))
    for (const record of state.records) {
      const row = el('div', '', 'specialist-actions')
      row.append(button(`${record.name} · revision ${record.revision}`, () => controller.reopen(record.id), state.preparing || !!state.refinement),
        button(`Create variant of ${record.name}`, () => controller.forkSaved(record.id), state.preparing || !!state.refinement),
        button(`Export ${record.name}`, () => controller.exportSaved(record.id, download), state.preparing))
      saved.append(row)
    }
    panel.append(saved)
    const portableArea = el('section', '', 'specialist-portable')
    portableArea.append(el('h3', 'Move a saved creator by file'),
      el('p', 'Export one saved definition as local JSON, then explicitly import that file here or in another Desk library. Includes brief, task template and composition snapshots; excludes knowledge file bytes, task inputs, credential fields and permissions. Authored text may contain private information; review before sharing. No automatic sync or origin storage transfer. Review file text before trying it.'))
    const importLabel = el('label', state.importLoading ? 'Checking creator file…' : 'Import local creator JSON', 'specialist-field'), importFile = el('input')
    importFile.type = 'file'; importFile.name = 'creator-import-file'; importFile.accept = '.json,application/json'; importFile.disabled = state.loading || state.preparing || !!state.refinement
    importFile.addEventListener('change', () => { if (epoch === renderEpoch && importFile.files?.[0]) void controller.importCreatorFile(importFile.files[0]) })
    importLabel.append(importFile); portableArea.append(importLabel)
    if (state.portableImport || state.importLoading) portableArea.append(button('Cancel creator import', () => controller.cancelCreatorImport(), state.preparing))
    const pendingImport = state.portableImport
    if (pendingImport) {
      const imported = pendingImport.creator
      portableArea.append(el('p', `${pendingImport.name || 'Creator file'} · ${imported.name} · source revision ${imported.revision}. Source IDs and names are unverified file metadata. Import creates a fresh local identity at revision 1.`),
        el('p', `Required Book: ${imported.book.book_id} · version ${imported.book.version}. The original workspace is not adopted.`))
      const review = el('details'); review.append(el('summary', 'Review imported definition'), el('pre', JSON.stringify(imported, null, 2))); portableArea.append(review)
      const label = el('label', 'Bind to installed MoonBook', 'specialist-field'), select = el('select'); select.name = 'creator-import-book'
      const empty = el('option', 'Choose exact installed Book and version'); empty.value = ''; select.append(empty)
      const matches = matchingCreatorBooks(imported, state.agents)
      for (const agent of matches) { const option = el('option', `${agent.name} [${agent.book_id}] · ${agent.version} · workspace ${agent.workspace_id}`); option.value = agent.workspace_id; select.append(option) }
      select.value = pendingImport.workspace; select.disabled = state.importLoading || state.preparing
      select.addEventListener('change', () => { if (epoch === renderEpoch) controller.chooseImportBook(select.value) }); label.append(select); portableArea.append(label)
      if (!matches.length) portableArea.append(el('p', 'No exact ready Book matches. Install or repair the Book through the existing pack workflow, then reopen the builder or reselect this file.'))
      portableArea.append(el('p', 'Use imported definition replaces the current draft after rechecking the Book. Cancel keeps it unchanged. Save is an explicit later step.'),
        button('Use imported definition', () => void controller.useImportedCreator(), state.loading || state.importLoading || state.preparing || !pendingImport.workspace))
    }
    panel.append(portableArea)
    if (state.storage_error) panel.append(el('p', state.storage_error, 'specialist-warning'))
    const current = state.editing ? state.draft : state.created
    if (current?.imported_from) panel.append(el('p', `Imported from ${current.imported_from.source_name} · original revision ${current.imported_from.source_revision} · source ID ${current.imported_from.source_id}. Unverified file provenance; this creator has an independent local identity and uses the selected installed Book.`, 'specialist-import-source'))
    if (current?.variant) {
      const lineage = current.variant, savedSource = !current.imported_from && state.records.find(record => record.id === lineage.source_id)
      panel.append(el('p', `Variant of ${lineage.source_name} · saved revision ${lineage.source_revision} · source ID ${lineage.source_id}. The copied brief, task form, stages and reference selections are independent. Knowledge files remain live.`, 'specialist-variant-lineage'))
      if (savedSource && savedSource.revision !== lineage.source_revision) panel.append(el('p', `The saved source is now revision ${savedSource.revision}. This variant keeps its copied revision ${lineage.source_revision}; it is not automatically refreshed.`))
      else if (current.imported_from) panel.append(el('p', 'This variant lineage came from an imported file. It is not linked to a local saved creator.'))
      else if (!savedSource) panel.append(el('p', 'The saved source is no longer in this library. Its lineage is retained in this variant.'))
    }
    if (state.refinement) {
      const { source, observation, files, number } = state.refinement
      const context = el('section', '', 'specialist-task-refinement')
      context.append(el('h3', `Improve creator from observation ${number}`),
        el('p', `${source.name} [${source.id}] · captured revision ${source.revision} · CSV row ${observation.row_number}`),
        el('p', 'Write the concrete correction in Purpose below. It becomes an ordinary editable creator field in a new independent variant. The original creator and observation stay intact. Retrying alone does not establish improvement or accept Book knowledge.'),
        el('h4', 'Exact captured task and inputs'), el('pre', observation.task), el('pre', JSON.stringify(observation.inputs, null, 2)),
        el('h4', 'Operator-observed response'), el('pre', observation.output), el('p', 'Operator notes'), el('pre', observation.notes))
      const original = el('details'); original.append(el('summary', 'Review exact original creator and captured brief'),
        el('pre', JSON.stringify(source, null, 2)), el('pre', observation.brief)); context.append(original)
      context.append(el('p', `${files.length} captured task-only file snapshot(s). Retry keeps this task text and these exact file contents, even if current CSV inputs or the reusable template changed. Book knowledge references remain live.`))
      for (const file of files) context.append(el('h4', `${file.name} · ${file.bytes} UTF-8 bytes`), el('pre', file.content))
      const isSaved = !state.editing && state.records.some(record => JSON.stringify(record) === JSON.stringify(state.created))
      context.append(button('Download original observations JSON', () => controller.exportTaskResults('json', download), state.preparing || state.csvLoading || state.taskFileLoading))
      context.append(button(isSaved ? 'Return to original observations' : 'Discard unsaved correction and return to observations', () => controller.returnToTaskObservations(), state.preparing))
      context.append(el('p', 'Close keeps this correction and its captured context in the current page session. Save specialist persists only the ordinary creator definition. Export the original observations before reload; refinement context and task files are not saved with the creator.'))
      panel.append(context)
    }
    if (state.editing) {
      panel.append(el('h3', '1 · Define the work'), field('Name', 'name', state.draft.name),
        field(state.refinement ? 'Purpose / concrete correction' : 'Purpose', 'purpose', state.draft.purpose, true), field('Representative example', 'example', state.draft.example, true))
      if (state.draft.composition) {
        const stages = state.draft.composition.stages
        panel.append(el('h3', '2 · Compose ordered specialist stages'), el('p', 'Choose 2–4 saved single-stage specialists from the same Book and version. Their saved briefs are copied as revision snapshots. The configured assistant applies these stages within one conversation.'))
        if (state.draft.book) panel.append(el('p', `${state.draft.book.name} [${state.draft.book.book_id}] · ${state.draft.book.version}`))
        const label = el('label', 'Saved source specialist', 'specialist-field'), select = el('select'); select.name = 'stage-source'
        const empty = el('option', 'Choose a saved specialist'); empty.value = ''; select.append(empty)
        for (const source of state.records.filter(item => !item.composition)) {
          const option = el('option', `${source.name} · revision ${source.revision} · ${source.book.name} ${source.book.version}`)
          option.value = source.id; option.disabled = stages.some(stage => stage.source.id === source.id) || (stages.length > 0 && !sameCompositionBook(source.book, state.draft.book)); select.append(option)
        }
        select.disabled = state.loading || stages.length >= maxCompositionStages; label.append(select)
        panel.append(label, button('Add stage', () => controller.addStage(select.value), select.disabled))
        if (!state.records.some(item => !item.composition)) panel.append(el('p', 'Create and save two single-stage specialists first, then return to compose them.'))
        stages.forEach((stage, index) => {
          const card = el('section', '', 'specialist-stage')
          card.append(el('h4', `${index + 1} · ${stage.source.name} · source revision ${stage.source.revision}`),
            el('p', stage.source.purpose), el('p', `Knowledge: ${stage.source.knowledge_paths.join(', ') || 'No additional files'}`),
            field(`Stage ${index + 1} required output / handoff`, `handoff-${index}`, stage.handoff, true, value => controller.editHandoff(index, value)),
            button(`Move stage ${index + 1} up`, () => controller.moveStage(index, -1), index === 0),
            button(`Move stage ${index + 1} down`, () => controller.moveStage(index, 1), index === stages.length - 1),
            button(`Remove stage ${index + 1}`, () => controller.removeStage(index)))
          const replacementLabel = el('label', `Replacement for stage ${index + 1}`, 'specialist-field'), replacementSelect = el('select')
          replacementSelect.name = `stage-replacement-${index}`
          const placeholder = el('option', 'Choose a saved replacement'); placeholder.value = ''; replacementSelect.append(placeholder)
          for (const source of state.records.filter(item => !item.composition)) {
            const option = el('option', `${source.name} · revision ${source.revision}`); option.value = source.id
            option.disabled = !sameCompositionBook(source.book, state.draft.book) ||
              stages.some((other, position) => position !== index && other.source.id === source.id) ||
              JSON.stringify(source) === JSON.stringify(stage.source)
            replacementSelect.append(option)
          }
          const savedSource = state.records.find(source => source.id === stage.source.id && !source.composition)
          if (savedSource && JSON.stringify(savedSource) !== JSON.stringify(stage.source)) {
            card.append(el('p', `This library also has ${savedSource.name} · revision ${savedSource.revision}. The stage keeps its current snapshot until you review and apply a replacement.`))
          }
          replacementSelect.disabled = state.loading || state.importLoading; replacementLabel.append(replacementSelect)
          card.append(replacementLabel, button(`Review replacement for stage ${index + 1}`, () => controller.previewStageReplacement(index, replacementSelect.value), replacementSelect.disabled))
          panel.append(card)
        })
        if (state.stageReplacement) {
          const pending = state.stageReplacement, previous = state.draft.composition.stages[pending.index]
          const replacement = pending.candidate.composition.stages[pending.index]
          const comparison = el('section', '', 'specialist-stage-replacement')
          comparison.append(el('h3', `Compare replacement for stage ${pending.index + 1}`))
          for (const [label, stage] of [['Current stage snapshot', previous], ['Proposed saved snapshot', replacement]]) {
            const source = stage.source
            comparison.append(el('h4', label), el('pre', [
              `${source.name} [${source.id}] · revision ${source.revision}`,
              `MoonBook: ${source.book.name} [${source.book.book_id}] · ${source.book.version} · workspace ${source.book.workspace_id}`,
              `Purpose:\n${source.purpose}`, `Representative example (context only):\n${source.example}`,
              `Preferred capabilities: ${source.capabilities.join(', ') || 'Ordinary Book chat'}`,
              `Knowledge references:\n${source.knowledge_paths.join('\n') || '(None selected)'}`,
            ].join('\n\n')))
          }
          comparison.append(el('p', 'Position and required output / handoff are kept. Check whether this handoff still fits the replacement. Knowledge paths remain live references; source definitions and saved creators are unchanged until you explicitly save the revised creator.'),
            el('pre', replacement.handoff),
            button('Apply stage replacement', () => controller.applyStageReplacement(), state.loading || state.importLoading),
            button('Cancel stage replacement', () => controller.cancelStageReplacement()))
          panel.append(comparison)
        }
        panel.append(el('p', `${state.draft.knowledge_paths.length}/20 combined knowledge references · ${state.draft.capabilities.length}/16 preferred capabilities. References remain live; source brief revisions stay fixed until a stage is replaced.`))
      } else {
      panel.append(el('h3', '2 · Choose Book knowledge and capabilities'))
      const label = el('label', 'MoonBook', 'specialist-field'), select = el('select'); select.name = 'book'
      const empty = el('option', state.loading ? 'Loading MoonBooks…' : 'Choose an installed MoonBook'); empty.value = ''; select.append(empty)
      for (const agent of state.agents) { const option = el('option', `${agent.name} · ${agent.version} · ${agent.status}`); option.value = agent.workspace_id; option.disabled = agent.status !== 'ready'; select.append(option) }
      select.value = state.draft.book?.workspace_id || ''; select.disabled = state.loading
      select.addEventListener('change', () => { if (epoch === renderEpoch) controller.chooseBook(select.value) }); label.append(select); panel.append(label)
      if (state.draft.book) {
        panel.append(el('p', `${state.draft.book.name} [${state.draft.book.book_id}] · ${state.draft.book.version}`))
        const capabilities = el('fieldset'); capabilities.append(el('legend', 'Preferred capabilities (no additional permissions)'))
        for (const capability of controller.selectedAgent()?.capabilities || []) capabilities.append(checkbox(capability, state.draft.capabilities.includes(capability), checked => controller.toggleCapability(capability, checked)))
        panel.append(capabilities, el('p', 'Choose wiki or raw knowledge references. Other Book context and existing runtime permissions still apply.'))
        const form = el('form'), searchLabel = el('label', 'Find knowledge', 'specialist-field'), query = el('input'); query.name = 'knowledge-query'; query.maxLength = 256
        searchLabel.append(query); const search = el('button', state.searching ? 'Searching…' : 'Search knowledge'); search.type = 'submit'; search.disabled = state.searching
        form.append(searchLabel, search); form.addEventListener('submit', event => { event.preventDefault(); if (epoch === renderEpoch) void controller.search(query.value) }); panel.append(form)
        const choices = unique([...state.draft.knowledge_paths, ...state.hits.map(hit => hit.path)])
        for (const path of choices) panel.append(checkbox(path, state.draft.knowledge_paths.includes(path), checked => controller.toggleKnowledge(path, checked)))
      }
      }
      panel.append(el('h3', 'Reusable task form (optional)'),
        el('p', 'Keep the representative example above. Add a reusable template such as “Compare {{topic}} for {{audience}}”. Each field is required when using the creator for new work; up to 8 fields. Inputs are kept only until you reload or switch creators.'),
        field('Task template', 'task-template', state.draft.task_form?.template || '', true, value => controller.editTaskTemplate(value)))
      panel.append(button(state.created ? 'Create revised specialist' : 'Create specialist', () => controller.create(), state.loading || state.importLoading))
    } else if (state.created) {
      panel.append(el('h3', `${state.created.name} · revision ${state.created.revision}`), el('p', state.refinement ? '3 · Retry the captured task, revise, then save' : '3 · Try the representative example, revise, then save'))
      if (state.created.composition) panel.append(el('p', `Composed from ${state.created.composition.stages.length} saved specialist revisions, in order: ${state.created.composition.stages.map(stage => `${stage.source.name} r${stage.source.revision}`).join(' → ')}`))
      const details = el('details'), summary = el('summary', state.refinement ? 'Review the exact corrected brief for the same captured task' : 'Review the exact brief')
      details.open = !!state.refinement
      details.append(summary, el('pre', state.refinement ? state.refinement.preview : controller.taskBrief(state.created))); panel.append(details)
      panel.append(el('p', 'Try in chat prepares a fresh conversation with the selected knowledge files. Review it and click Send to use your configured assistant. Preparation alone is not a completed trial.'))
      const actions = el('div', '', 'specialist-actions')
      actions.append(button(state.preparing ? 'Preparing…' : state.refinement ? 'Prepare same captured task in chat' : 'Try in chat', () => void (state.refinement ? controller.prepareRefinedTask() : controller.tryExample()), state.preparing || state.importLoading || state.taskFileLoading),
        button('Revise', () => controller.revise(), state.preparing), button('Save specialist', () => controller.save(), state.preparing || state.importLoading || !!state.storage_error))
      panel.append(actions)
      if (!state.refinement) {
      const filesArea = el('section', '', 'specialist-task-files')
      filesArea.append(el('h3', 'Files for this task only'), el('p', 'Add up to four local UTF-8 text files, at most 32 KiB each and 64 KiB together. Their text is included only in the exact brief prepared next. Review private data before ordinary Send. Files are not saved in the creator, exported with it or added to MoonBook.'))
      const fileLabel = el('label', state.taskFileLoading ? 'Reading task file…' : 'Add task-only text file', 'specialist-field'), taskFile = el('input')
      taskFile.type = 'file'; taskFile.name = 'task-text-file'; taskFile.accept = '.txt,.md,.csv,.json,text/plain,text/markdown,text/csv,application/json'; taskFile.disabled = state.preparing
      taskFile.addEventListener('change', () => { if (epoch === renderEpoch && taskFile.files?.[0]) void controller.addTaskFile(taskFile.files[0]) })
      fileLabel.append(taskFile); filesArea.append(fileLabel)
      state.taskFiles.forEach((file, index) => {
        const detail = el('details'); detail.append(el('summary', `${file.name} · ${file.bytes} UTF-8 bytes`), el('pre', file.content))
        filesArea.append(detail, button(`Remove task file ${file.name}`, () => controller.removeTaskFile(index), state.preparing))
      })
      if (state.taskFiles.length || state.taskFileLoading) filesArea.append(button('Clear task files', () => controller.clearTaskFiles(), state.preparing))
      filesArea.append(el('p', 'Close keeps completed reads in this page session; pending reads are cancelled. Files clear after successful chat preparation, switching/revising creators or reload. Add them again explicitly for another task.'))
      panel.append(filesArea)
      if (state.created.task_form) {
        panel.append(el('h3', 'Use creator for a new task'), el('p', 'Fill every input, then preview the full brief. This does not save inputs or change the creator revision. Ordinary Send in chat is still required.'))
        for (const key of taskInputKeys(state.created.task_form.template)) {
          const input = field(key.replaceAll('_', ' '), `task-input-${key}`, state.taskValues[key] || '', true, value => { if (controller.editTaskInput(key, value)) { taskPreviewNode?.remove(); taskPreviewNode = null; status.textContent = controller.state.status } })
          input.querySelector('textarea').disabled = state.preparing
          input.querySelector('textarea').maxLength = 4000
          panel.append(input)
        }
        panel.append(button('Preview filled task', () => controller.previewTask(), state.preparing || state.taskFileLoading))
        taskPreviewNode = null
        if (state.taskPreview) { taskPreviewNode = el('pre', state.taskPreview, 'specialist-task-preview'); panel.append(taskPreviewNode) }
        panel.append(button('Prepare filled task in chat', () => void controller.prepareTask(), state.preparing || state.taskFileLoading))
        const csvArea = el('section', '', 'specialist-csv-tasks')
        csvArea.append(el('h3', 'Use saved creator with spreadsheet rows'),
          el('p', 'Export a UTF-8 comma-separated CSV with a header and up to 100 task rows, 32 columns and 512 KiB. Map fields explicitly, inspect rows, then prepare one exact brief at a time. Cells stay literal text; formulas are not evaluated.'))
        const savedCreator = state.records.some(record => JSON.stringify(record) === JSON.stringify(state.created))
        if (!savedCreator) csvArea.append(el('p', 'Save this creator revision before importing a CSV.'))
        const csvLabel = el('label', state.csvLoading ? 'Reading local CSV…' : 'Import local CSV', 'specialist-field'), csvFile = el('input')
        csvFile.type = 'file'; csvFile.name = 'task-csv-file'; csvFile.accept = '.csv,text/csv'
        csvFile.disabled = state.preparing || !savedCreator
        csvFile.addEventListener('change', () => { if (epoch === renderEpoch && csvFile.files?.[0]) void controller.importTaskCsv(csvFile.files[0]) })
        csvLabel.append(csvFile); csvArea.append(csvLabel)
        const jsonlLabel = el('label', 'Import local JSON Lines task records', 'specialist-field'), jsonlFile = el('input')
        jsonlFile.type = 'file'; jsonlFile.name = 'task-jsonl-file'; jsonlFile.accept = '.jsonl,.ndjson,application/x-ndjson'
        jsonlFile.disabled = state.preparing || !savedCreator
        jsonlFile.addEventListener('change', () => { if (epoch === renderEpoch && jsonlFile.files?.[0]) void controller.importTaskJsonl(jsonlFile.files[0]) })
        jsonlLabel.append(jsonlFile); csvArea.append(jsonlLabel)
        csvArea.append(el('p', 'JSONL accepts up to 100 flat objects with the same 1–32 distinct fields and string values only, within 512 KiB. Numbers, booleans, null, arrays, nested objects, duplicate keys and blank lines require an explicit source correction. Field order may vary. Decoded strings become an ordinary editable CSV table; CSV row 2 corresponds to JSONL line 1. Checkpoints retain that table, not the original JSON file.'))
        csvArea.append(el('p', 'Save a local task checkpoint before reloading to keep original CSV cells, mappings and applied corrections. The file contains task data and the creator definition: review private information before sharing. It excludes task-only files and run results. Restore requires this exact saved creator, then fresh inspection and selection.'))
        const checkpointLabel = el('label', 'Restore local task checkpoint (replaces this batch after validation)', 'specialist-field'), checkpointFile = el('input')
        checkpointFile.type = 'file'; checkpointFile.name = 'task-checkpoint-file'; checkpointFile.accept = '.creator-tasks.json,application/json'
        checkpointFile.disabled = state.preparing || state.loading || !savedCreator || !!state.taskFiles.length || state.taskFileLoading
        checkpointFile.addEventListener('change', () => { if (epoch === renderEpoch && checkpointFile.files?.[0]) void controller.importTaskCheckpoint(checkpointFile.files[0]) })
        checkpointLabel.append(checkpointFile); csvArea.append(checkpointLabel)
        if (state.taskFiles.length || state.taskFileLoading) csvArea.append(el('p', 'Clear task-only files before restoring, then add the intended files again.'))
        if (state.csv || state.csvLoading) csvArea.append(button('Clear CSV tasks', () => controller.clearTaskCsv(), state.preparing))
        const csv = state.csv
        if (csv) {
          csvArea.append(button('Save task checkpoint to file', () => controller.exportTaskCheckpoint(download), !!csv.editor || state.preparing || state.csvLoading || state.taskFileLoading))
          csvArea.append(el('p', `${csv.name || 'Local CSV'} · ${csv.rows.length} task rows · ${csv.creator.name} revision ${csv.creator.revision}. This batch keeps its imported creator and stage snapshots. Reference file contents remain live.`))
          const savedSource = state.records.find(record => record.id === csv.creator.id)
          if (!savedSource || JSON.stringify(savedSource) !== JSON.stringify(csv.creator)) csvArea.append(el('p', 'The saved creator has changed or is no longer available. This batch still uses the imported revision; reopen the saved creator to start a new batch.'))
          for (const key of taskInputKeys(csv.creator.task_form.template)) {
            const label = el('label', `Map ${key} to CSV column`, 'specialist-field'), select = el('select'); select.name = `csv-map-${key}`
            const empty = el('option', 'Choose a column'); empty.value = ''; select.append(empty)
            csv.headers.forEach((header, index) => { const option = el('option', `${index + 1} · ${header}`); option.value = String(index); select.append(option) })
            select.value = Object.hasOwn(csv.mapping, key) ? String(csv.mapping[key]) : ''
            select.disabled = state.preparing || state.csvLoading || !!csv.editor || !!Object.keys(csv.corrections).length
            select.addEventListener('change', () => { if (epoch === renderEpoch) controller.mapTaskCsv(key, select.value === '' ? null : Number(select.value)) })
            label.append(select); csvArea.append(label)
          }
          if (Object.keys(csv.corrections).length) csvArea.append(el('p', 'Row corrections are attached to this mapping. Reset corrections before changing columns.'),
            button('Reset all row corrections', () => controller.resetTaskCsvCorrections(), !!csv.editor || state.preparing || state.csvLoading || state.taskFileLoading))
          csvArea.append(button('Inspect CSV tasks', () => controller.inspectTaskCsv(), !!csv.editor || state.preparing || state.csvLoading || state.taskFileLoading))
          const exploration = exploreTaskRows(csv), view = exploration.options
          const explorationBusy = !!csv.editor || !!csv.resultEditor || state.preparing || state.csvLoading || state.taskFileLoading
          const explorationArea = el('section', '', 'specialist-task-exploration')
          explorationArea.append(el('h4', 'Explore task rows'), el('p', 'Search the current mapped input values as literal, case-insensitive text. Apply search, status and ordering together. This changes only the view. Unmapped cells, creator instructions, attached files and responses are not searched.'))
          const searchLabel = el('label', 'Literal task input search', 'specialist-field'), search = el('input')
          search.name = 'task-exploration-query'; search.type = 'search'; search.value = view.query; search.maxLength = 200; search.disabled = explorationBusy
          searchLabel.append(search); explorationArea.append(searchLabel)
          const explorationSelect = (labelText, name, choices, value) => {
            const label = el('label', labelText, 'specialist-field'), select = el('select'); select.name = name; select.disabled = explorationBusy
            for (const [key, title] of choices) { const option = el('option', title); option.value = key; select.append(option) }
            select.value = value; label.append(select); explorationArea.append(label); return select
          }
          const inputChoices = taskInputKeys(csv.creator.task_form.template).map(key => [key, key])
          const searchField = explorationSelect('Search input', 'task-exploration-field', [['', 'All mapped inputs'], ...inputChoices], view.field)
          const filter = explorationSelect('Task status', 'task-exploration-status', taskExplorationStatuses, view.status)
          const order = explorationSelect('Order task rows by', 'task-exploration-sort', [['', 'Source row number'], ...inputChoices], view.sort)
          const direction = explorationSelect('Order direction', 'task-exploration-direction', [['asc', 'Ascending'], ['desc', 'Descending']], view.direction)
          const applyExploration = () => controller.exploreTaskCsv({ query: search.value, field: searchField.value, status: filter.value, sort: order.value, direction: direction.value })
          search.addEventListener('keydown', event => { if (epoch === renderEpoch && event.key === 'Enter' && !explorationBusy) { event.preventDefault(); applyExploration() } })
          explorationArea.append(button('Apply task exploration', applyExploration, explorationBusy), button('Reset task exploration', () => controller.exploreTaskCsv(defaultTaskExploration), explorationBusy))
          if (exploration.inspected) {
            explorationArea.append(el('p', `Showing ${exploration.entries.length} of ${exploration.total} tasks · ${exploration.counts.ready} ready · ${exploration.counts['needs-correction']} need correction · ${exploration.counts.corrected} corrected · ${exploration.counts.observed} with matching observations · ${exploration.counts.unobserved} ready without matching observations · ${exploration.counts.historical} with only historical observations. Counts describe the whole inspected batch.`))
            if (!exploration.entries.length) explorationArea.append(el('p', 'No tasks match this exploration. Change the search/status or reset the view; no rows were removed.'))
          } else explorationArea.append(el('p', 'Inspect CSV tasks to populate this view. Earlier observation match status is not inferred from an uninspected batch.'))
          explorationArea.append(el('p', 'Observations are operator-entered responses, never verified completion. Field order is lexical, case-insensitive and independent of browser locale; numbers are text. Equal values keep source order. Applied exploration stays through Close in this page only; checkpoints and result exports always include their full original scope.'))
          csvArea.append(explorationArea)
          exploration.entries.forEach(({ row, index, matching, historical }) => {
            const details = el('details'), summary = el('summary', `CSV row ${row.number} · ${row.errors.length ? 'Needs correction' : row.corrected.length ? 'Corrected task ready to select' : 'Ready to select'}`)
            details.append(summary)
            details.append(el('p', `${matching} matching observation(s) · ${historical} historical observation(s).`))
            if (row.errors.length) row.errors.forEach(error => details.append(el('p', error)))
            else details.append(el('pre', row.task))
            for (const key of row.corrected) details.append(el('p', `Corrected ${key} · imported value:`), el('pre', text(row.originalValues[key])), el('p', 'Task value:'), el('pre', row.values[key]))
            const rowBusy = !!csv.editor || state.preparing || state.csvLoading || state.taskFileLoading
            csvArea.append(details, button(`Select CSV row ${row.number}`, () => controller.selectTaskCsvRow(index), !!row.errors.length || rowBusy),
              button(`Edit task inputs for CSV row ${row.number}`, () => controller.beginTaskCsvRowEdit(index), rowBusy || csv.rows[index].cells.length !== csv.headers.length))
            if (row.corrected.length) csvArea.append(button(`Reset CSV row ${row.number} corrections`, () => controller.resetTaskCsvRow(index), rowBusy))
            if (csv.rows[index].cells.length !== csv.headers.length) csvArea.append(el('p', `CSV row ${row.number} has a structural cell-count error. Correct the file and reimport; task input editing cannot discard extra cells or guess missing columns.`))
          })
          const editor = csv.editor
          if (editor) {
            const original = csv.rows[editor.index]
            csvArea.append(el('h4', `Edit task inputs for CSV row ${original.number}`), el('p', 'These corrections apply only to this imported task. Blank or oversized inputs must be fixed before applying. The CSV file, saved creator, other rows and manual task form are unchanged.'))
            for (const key of taskInputKeys(csv.creator.task_form.template)) {
              csvArea.append(el('p', `${key} · imported from column ${csv.mapping[key] + 1} (${csv.headers[csv.mapping[key]]}):`), el('pre', text(original.cells[csv.mapping[key]])))
              const input = field(`Corrected ${key.replaceAll('_', ' ')}`, `csv-row-input-${key}`, editor.values[key], true, value => { if (controller.editTaskCsvRowInput(key, value)) status.textContent = controller.state.status })
              input.querySelector('textarea').maxLength = 4000
              input.querySelector('textarea').disabled = state.preparing || state.csvLoading
              csvArea.append(input)
            }
            csvArea.append(button('Apply row corrections', () => controller.applyTaskCsvRowEdit(), state.preparing || state.csvLoading || state.taskFileLoading),
              button('Cancel row edit', () => controller.cancelTaskCsvRowEdit(), state.preparing || state.csvLoading))
          }
          const selected = csv.inspected[csv.selected]
          if (selected) {
            csvArea.append(el('h4', `Exact brief for CSV row ${selected.number}`), el('pre', selected.brief, 'specialist-csv-preview'),
              button('Prepare selected CSV task in chat', () => void controller.prepareTaskCsvRow(), state.preparing || state.csvLoading || state.taskFileLoading),
              button('Record an observed response for selected task', () => controller.beginTaskObservation(csv.selected), !!csv.resultEditor || !!csv.editor || state.preparing || state.csvLoading || state.taskFileLoading))
          }
          csvArea.append(el('h4', 'Collect creator task outputs'), el('p', 'Run tasks separately, then select a task and paste the actual response you observed. Each saved observation fixes its exact inputs and complete brief. Later input/file changes mark old observations as historical; they never move to a different task or imply successful completion. Up to 100 observations; multiple responses for one task stay separate.'))
          if (csv.resultEditor) {
            const observation = csv.resultEditor
            csvArea.append(el('h4', `Observed response for CSV row ${observation.binding.row_number}`), el('pre', observation.binding.task))
            for (const [key, label] of [['output', 'Operator-observed response'], ['notes', 'Notes / what to do next']]) {
              const input = field(label, `task-result-${key}`, observation[key], true, value => { if (controller.editTaskObservation(key, value)) status.textContent = controller.state.status })
              input.querySelector('textarea').maxLength = taskResultLimits[key]
              input.querySelector('textarea').disabled = state.preparing || state.csvLoading
              csvArea.append(input)
            }
            csvArea.append(button('Save operator observation', () => controller.saveTaskObservation(), state.preparing || state.csvLoading || state.taskFileLoading), button('Cancel unfinished observation', () => controller.cancelTaskObservation(), state.preparing || state.csvLoading))
          }
          const matches = controller.taskObservationStatuses()
          ;(csv.observations || []).forEach((observation, index) => {
            const details = el('details')
            details.append(el('summary', `Observation ${index + 1} · CSV row ${observation.row_number} · ${matches[index] ? 'Matches current task inputs' : 'Historical: task inputs or brief changed'}`),
              el('p', 'Exact captured task'), el('pre', observation.task), el('p', 'Captured inputs'), el('pre', JSON.stringify(observation.inputs, null, 2)),
              el('p', 'Operator-entered response'), el('pre', observation.output), el('p', 'Operator notes'), el('pre', observation.notes))
            csvArea.append(details, button(`Improve creator from observation ${index + 1}`, () => controller.improveTaskCreator(index), !!csv.resultEditor || !!csv.editor || state.preparing || state.csvLoading || state.taskFileLoading))
          })
          if (csv.observations?.length) {
            for (const [format, label] of [['json', 'Download exact task-results JSON'], ['csv', 'Download spreadsheet-safe task-results CSV'], ['markdown', 'Download task-results Markdown']]) csvArea.append(button(label, () => controller.exportTaskResults(format, download), !!csv.resultEditor || state.preparing || state.csvLoading || state.taskFileLoading))
          }
          csvArea.append(el('p', 'Download results before clearing tasks, importing another batch, revising/switching creator or reloading. Task checkpoints exclude these observations. Result JSON is an exact archive, not a resumable checkpoint. Results include captured complete briefs and selected task-file contents, so review private information before sharing. In spreadsheet-safe CSV, text cells are JSON strings: use JSON.parse to recover exact values.'))
          csvArea.append(el('p', 'CSV data, applied corrections and pending row edits stay in this page session until cleared, reloaded, revised or another creator is selected. Close and return to continue. Editing or resetting a row clears the selected brief; apply, select and review again. Preparation uses the existing unsent-work guards; ordinary Send in chat is required for each task. No batch execution or completion tracking.'))
        }
        panel.append(csvArea)
      }
      }
    }
    status.textContent = state.status; panel.append(status)
    if (focusedName) panel.querySelector(`[name="${focusedName}"]`)?.focus()
    else panel.querySelector('button')?.focus()
  }
  return { controller, scope: options.scope, get panel() { return panel } }
}
