import { exportCreator, parseCreator, portableContract } from './specialist-portable.js'
import { parseTaskCsv, inspectTaskCsv } from './specialist-task-csv.js'
import { taskInputKeys } from './specialist-task-form.js'

// An explicit local checkpoint of task inputs, never a runtime or run receipt.
export const taskBatchContract = 'moondesk.specialist-task-batch.v1'
export const taskBatchByteLimit = 4 * 1024 * 1024
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value)
const exactKeys = (value, keys) => object(value) && Object.keys(value).length === keys.length && keys.every(key => Object.hasOwn(value, key))
const clone = value => JSON.parse(JSON.stringify(value))
const invalid = () => { throw new Error('Invalid task checkpoint. Use a supported creator-tasks file; existing work is unchanged.') }

export function parseTaskBatch(content, expectedCreator, validPreset) {
  if (typeof content !== 'string' || content.length > taskBatchByteLimit || new TextEncoder().encode(content).byteLength > taskBatchByteLimit) throw new Error('Choose a UTF-8 task checkpoint no larger than 4 MiB.')
  let data
  try { data = JSON.parse(content) } catch { throw new Error('The task checkpoint is not valid JSON. Existing work is unchanged.') }
  if (!exactKeys(data, ['contract', 'creator', 'csv', 'mapping', 'corrections']) || data.contract !== taskBatchContract ||
      !exactKeys(data.csv, ['name', 'source']) || typeof data.csv.name !== 'string' || data.csv.name.length > 200 || data.csv.name.includes('\0')) invalid()
  const creator = parseCreator(JSON.stringify({ contract: portableContract, creator: data.creator }), validPreset)
  if (!creator.task_form || exportCreator(creator, validPreset).content !== exportCreator(expectedCreator, validPreset).content) throw new Error('This checkpoint needs the exact saved creator definition, including its revision, Book and stage snapshots. Reopen that unchanged creator; no definition is imported or revised here.')
  const csv = parseTaskCsv(data.csv.source), keys = taskInputKeys(creator.task_form.template)
  if (!object(data.mapping) || Object.keys(data.mapping).some(key => !keys.includes(key) || !Number.isInteger(data.mapping[key]) || data.mapping[key] < 0 || data.mapping[key] >= csv.headers.length) || !object(data.corrections)) invalid()
  for (const index of Object.keys(data.corrections)) {
    if (!/^(0|[1-9][0-9]*)$/.test(index) || Number(index) >= csv.rows.length ||
        !exactKeys(data.corrections[index], keys) || csv.rows[Number(index)].cells.length !== csv.headers.length) invalid()
  }
  if (Object.keys(data.corrections).length) {
    const rows = inspectTaskCsv(creator.task_form, csv, data.mapping, data.corrections)
    for (const index of Object.keys(data.corrections)) if (rows[index].errors.length || !rows[index].corrected.length) invalid()
  }
  return { ...csv, source: data.csv.source, name: data.csv.name, creator: clone(expectedCreator),
    mapping: clone(data.mapping), corrections: clone(data.corrections), inspected: [], selected: null, editor: null }
}

export function exportTaskBatch(csv, validPreset) {
  if (!csv || csv.editor) throw new Error('Apply or cancel the pending row edit before saving a task checkpoint.')
  const definition = exportCreator(csv.creator, validPreset)
  const data = { contract: taskBatchContract, creator: JSON.parse(definition.content).creator,
    csv: { name: csv.name, source: csv.source }, mapping: csv.mapping, corrections: csv.corrections }
  const content = JSON.stringify(data, null, 2) + '\n'
  const checked = parseTaskBatch(content, csv.creator, validPreset)
  if (JSON.stringify(checked.headers) !== JSON.stringify(csv.headers) || JSON.stringify(checked.rows) !== JSON.stringify(csv.rows)) throw new Error('Imported CSV cells changed unexpectedly. Reimport the original CSV before saving a checkpoint.')
  return { filename: definition.filename.replace(/\.creator\.json$/, '.creator-tasks.json'), content }
}
