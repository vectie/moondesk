import { withTaskFiles } from './specialist-task-files.js'

const clone = value => JSON.parse(JSON.stringify(value))

// This context belongs to the open observation batch, never to the reusable
// creator schema. The source, task, response and file bytes are fixed together.
export function beginTaskRefinement(csv, index, briefFor) {
  const observation = Number.isInteger(index) && csv?.observations?.[index]
  if (!observation || !csv.creator) throw new Error('Choose a saved operator observation to improve its creator.')
  const files = csv.observationFiles?.[index] || []
  if (withTaskFiles(briefFor(csv.creator, observation.task), files) !== observation.brief) {
    throw new Error('The captured task-file snapshots are unavailable or do not match this observation. Record a new observation with the intended files before retrying; the original observation is kept.')
  }
  const source = clone(csv.creator), draft = clone(source)
  delete draft.id; delete draft.revision; delete draft.contract; delete draft.imported_from
  draft.name = source.name.slice(0, 90) + ' refined'
  draft.variant = { contract: 'moondesk.specialist-variant.v1', source_id: source.id,
    source_revision: source.revision, source_name: source.name }
  return { draft, context: { source, observation: clone(observation), files: clone(files), number: index + 1, preview: '' } }
}

export function refinedTaskBrief(context, creator, briefFor) {
  if (!context || creator.id === context.source.id || creator.purpose.trim() === context.source.purpose.trim()) {
    throw new Error('Write a concrete correction in Purpose before creating this independent variant.')
  }
  // Deliberately use the captured filled task, even if the reusable template or
  // current CSV inputs have since changed. Files are the observed snapshot too.
  const brief = withTaskFiles(briefFor(creator, context.observation.task), context.files)
  if (brief.length > 48000) throw new Error('The corrected brief exceeds the 48,000-character chat limit. Shorten Purpose before retrying; the captured task is kept.')
  return brief
}
