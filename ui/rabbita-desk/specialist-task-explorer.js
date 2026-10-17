import { taskInputKeys } from './specialist-task-form.js'
import { sameObservedTask } from './specialist-task-results.js'

// This is a view over the inspected source rows, never a reordered task batch.
// Empty field keys mean all inputs / source order; template keys cannot be empty.
export const defaultTaskExploration = Object.freeze({ query: '', field: '', status: 'all', sort: '', direction: 'asc' })
export const taskExplorationStatuses = Object.freeze([
  ['all', 'All tasks'], ['ready', 'Ready to select'], ['needs-correction', 'Needs correction'],
  ['corrected', 'With corrected inputs'], ['observed', 'With matching observations'],
  ['unobserved', 'Ready without matching observations'], ['historical', 'Only historical observations'],
])

export function validateTaskExploration(form, options) {
  const keys = taskInputKeys(form.template)
  if (!options || typeof options !== 'object' || Array.isArray(options) ||
      Object.keys(options).length !== 5 || !Object.keys(defaultTaskExploration).every(key => Object.hasOwn(options, key)) ||
      typeof options.query !== 'string' || options.query.length > 200 || options.query.includes('\0') ||
      !['', ...keys].includes(options.field) || !['', ...keys].includes(options.sort) ||
      !taskExplorationStatuses.some(([value]) => value === options.status) || !['asc', 'desc'].includes(options.direction)) {
    throw new Error('Choose supported task fields, a task status and an order; keep literal search within 200 characters.')
  }
  return { ...options }
}

export function exploreTaskRows(csv, options = csv.exploration || defaultTaskExploration) {
  const view = validateTaskExploration(csv.creator.task_form, options)
  const keys = taskInputKeys(csv.creator.task_form.template)
  const inspected = csv.inspected.length === csv.rows.length
  const entries = (inspected ? csv.inspected : []).map((row, index) => {
    const observations = (csv.observations || []).filter(item => item.row_index === index)
    const matching = observations.filter(item => sameObservedTask(item, csv, row)).length
    return { index, row, matching, historical: observations.length - matching }
  })
  const counts = { all: entries.length, ready: 0, 'needs-correction': 0, corrected: 0, observed: 0, unobserved: 0, historical: 0 }
  const hasStatus = (entry, status) => {
    const ready = !entry.row.errors.length
    return status === 'all' || (status === 'ready' && ready) ||
      (status === 'needs-correction' && !ready) || (status === 'corrected' && entry.row.corrected.length > 0) ||
      (status === 'observed' && entry.matching > 0) || (status === 'unobserved' && ready && !entry.matching) ||
      (status === 'historical' && entry.historical > 0 && !entry.matching)
  }
  for (const entry of entries) for (const [status] of taskExplorationStatuses.slice(1)) if (hasStatus(entry, status)) counts[status]++
  const query = view.query.toLowerCase()
  const value = (row, key) => typeof row.values[key] === 'string' ? row.values[key] : ''
  const visible = entries.filter(entry => hasStatus(entry, view.status) &&
    (view.field ? [view.field] : keys).some(key => value(entry.row, key).toLowerCase().includes(query)))
  visible.sort((a, b) => {
    if (!view.sort) return view.direction === 'asc' ? a.index - b.index : b.index - a.index
    const left = value(a.row, view.sort).toLowerCase(), right = value(b.row, view.sort).toLowerCase()
    const ordered = left < right ? -1 : left > right ? 1 : 0
    // Equal values always retain source order, even for descending views.
    return (view.direction === 'asc' ? ordered : -ordered) || a.index - b.index
  })
  return { options: view, inspected, entries: visible, counts, total: csv.rows.length }
}
