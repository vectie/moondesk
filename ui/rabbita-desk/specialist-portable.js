// Local, explicit definition exchange only. Files carry untrusted task text and
// reference selections; installed passports and the ordinary chat guards win.
export const portableContract = 'moondesk.specialist-portable.v1'
export const portableByteLimit = 256 * 1024
const sourceContract = 'moondesk.specialist-import-source.v1'
const clone = value => JSON.parse(JSON.stringify(value))
const text = (value, max) => typeof value === 'string' && value.trim() && value.length <= max && !value.includes('\0')
const keys = (value, allowed) => value && typeof value === 'object' && !Array.isArray(value) &&
  Object.keys(value).every(key => allowed.includes(key))
const recordKeys = ['contract', 'id', 'revision', 'name', 'purpose', 'example', 'book', 'capabilities', 'knowledge_paths', 'task_form', 'composition', 'variant', 'imported_from']
const lineageKeys = ['contract', 'source_id', 'source_revision', 'source_name']
export function validImportSource(value) {
  return keys(value, lineageKeys) && value.contract === sourceContract && text(value.source_id, 128) &&
    Number.isSafeInteger(value.source_revision) && value.source_revision >= 1 && text(value.source_name, 100)
}
function strictRecord(record, validPreset, stage = false) {
  if (!keys(record, recordKeys) || !validPreset(record) ||
      !keys(record.book, ['workspace_id', 'book_id', 'version', 'name']) ||
      (record.task_form && !keys(record.task_form, ['contract', 'template'])) ||
      (record.variant && !keys(record.variant, lineageKeys)) ||
      (record.imported_from && !validImportSource(record.imported_from))) return false
  if (record.composition) {
    if (stage || !keys(record.composition, ['contract', 'stages'])) return false
    for (const item of record.composition.stages) {
      if (!keys(item, ['source', 'handoff']) || !strictRecord(item.source, validPreset, true)) return false
    }
  }
  return true
}
// Export is an allowlist projection, never serialization of browser/controller
// state. Even extra fields in legacy storage cannot leave through this path.
function definition(record) {
  const result = Object.fromEntries(['contract', 'id', 'revision', 'name', 'purpose', 'example', 'capabilities', 'knowledge_paths'].map(key => [key, clone(record[key])]))
  result.book = Object.fromEntries(['workspace_id', 'book_id', 'version', 'name'].map(key => [key, record.book[key]]))
  if (record.task_form) result.task_form = { contract: record.task_form.contract, template: record.task_form.template }
  for (const key of ['variant', 'imported_from']) if (record[key]) result[key] = Object.fromEntries(lineageKeys.map(field => [field, record[key][field]]))
  if (record.composition) result.composition = { contract: record.composition.contract,
    stages: record.composition.stages.map(stage => ({ source: definition(stage.source), handoff: stage.handoff })) }
  return result
}
export function exportCreator(record, validPreset) {
  if (!validPreset(record)) throw new Error('Choose a valid saved creator revision to export.')
  const creator = definition(record)
  if (!strictRecord(creator, validPreset)) throw new Error('The saved creator contains an invalid source snapshot. Revise it before exporting.')
  const content = JSON.stringify({ contract: portableContract, creator }, null, 2) + '\n'
  if (new TextEncoder().encode(content).byteLength > portableByteLimit) throw new Error('This definition exceeds the portable 256 KiB limit.')
  const stem = record.name.replace(/[^a-zA-Z0-9_-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 80) || 'creator'
  return { filename: `${stem}-r${record.revision}.creator.json`, content }
}
export function parseCreator(content, validPreset) {
  if (typeof content !== 'string' || new TextEncoder().encode(content).byteLength > portableByteLimit) throw new Error('Choose a creator JSON file no larger than 256 KiB.')
  let data
  try { data = JSON.parse(content) } catch { throw new Error('The creator file is not valid JSON. Existing work is unchanged.') }
  if (!keys(data, ['contract', 'creator']) || data.contract !== portableContract || !strictRecord(data.creator, validPreset)) {
    throw new Error('Unsupported or invalid creator definition. Only the portable v1 definition format is accepted; storage dumps, authority and runtime fields are not imported.')
  }
  return clone(data.creator)
}
export function matchingCreatorBooks(creator, agents) {
  return agents.filter(agent => agent.status === 'ready' && agent.book_id === creator.book.book_id && agent.version === creator.book.version &&
    creator.capabilities.every(value => agent.capabilities.includes(value)))
}
export function bindImportedCreator(creator, agent) {
  const result = clone(creator), book = { workspace_id: agent.workspace_id, book_id: agent.book_id, version: agent.version, name: agent.name }
  result.book = book
  if (result.composition) result.composition.stages.forEach(stage => { stage.source.book = clone(book) })
  result.imported_from = { contract: sourceContract, source_id: creator.id, source_revision: creator.revision, source_name: creator.name }
  delete result.contract; delete result.id; delete result.revision
  return result
}
export function downloadCreator(packet, { document = globalThis.document, URL = globalThis.URL, Blob = globalThis.Blob, later = globalThis.setTimeout } = {}) {
  if (!document?.body || typeof URL?.createObjectURL !== 'function' || typeof Blob !== 'function') throw new Error('Local downloads are unavailable in this host. Your saved creator is unchanged.')
  const mime = packet.mime || 'application/json;charset=utf-8'
  if (!['application/json;charset=utf-8', 'text/csv;charset=utf-8', 'text/markdown;charset=utf-8'].includes(mime)) throw new Error('Unsupported local download format. Your work is kept.')
  const url = URL.createObjectURL(new Blob([packet.content], { type: mime }))
  let link
  try { link = document.createElement('a'); link.href = url; link.download = packet.filename; document.body.append(link); link.click() }
  finally { try { link?.remove() } finally { later(() => URL.revokeObjectURL(url), 1000) } }
}
