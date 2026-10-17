// Composition authors one ordinary chat brief. MoonClaw remains the sole
// runtime; these ordered stages are instructions, not scheduled agent jobs.
export const compositionContract = 'moondesk.specialist-composition.v1'
export const maxCompositionStages = 4
const text = (value, max) => typeof value === 'string' && value.trim().length > 0 && value.length <= max && !value.includes('\0')
const path = value => typeof value === 'string' && value.length <= 1024 && /^(wiki|raw)\//.test(value) &&
  !/[\\\x00-\x1f\x7f]/.test(value) && value.split('/').every(part => part && part !== '.' && part !== '..')
const unique = values => [...new Set(values)]
export const sameCompositionBook = (left, right) => !!left && !!right &&
  left.workspace_id === right.workspace_id && left.book_id === right.book_id && left.version === right.version

export function compositionSelections(composition) {
  return {
    knowledge_paths: unique(composition.stages.flatMap(stage => stage.source.knowledge_paths)),
    capabilities: unique(composition.stages.flatMap(stage => stage.source.capabilities)),
  }
}

export function validComposition(composition, preset) {
  if (composition?.contract !== compositionContract || !Array.isArray(composition.stages) ||
      composition.stages.length < 2 || composition.stages.length > maxCompositionStages) return false
  const ids = new Set()
  for (const stage of composition.stages) {
    const source = stage?.source
    if (!source || source.contract !== 'moondesk.specialist-preset.v1' || !text(source.id, 128) || ids.has(source.id) || source.id === preset.id ||
        !Number.isSafeInteger(source.revision) || source.revision < 1 || !text(source.name, 100) ||
        !text(source.purpose, 8000) || !text(source.example, 8000) ||
        !sameCompositionBook(source.book, preset.book) || !text(source.book?.name, 256) ||
        !text(stage.handoff, 2000) ||
        !Array.isArray(source.knowledge_paths) || source.knowledge_paths.length > 20 || !source.knowledge_paths.every(path) ||
        !Array.isArray(source.capabilities) || source.capabilities.length > 16 || !source.capabilities.every(value => text(value, 128)) ||
        Object.hasOwn(source, 'composition')) return false
    ids.add(source.id)
  }
  const selections = compositionSelections(composition)
  return selections.knowledge_paths.length <= 20 && selections.capabilities.length <= 16 &&
    JSON.stringify(selections.knowledge_paths) === JSON.stringify(preset.knowledge_paths) &&
    JSON.stringify(selections.capabilities) === JSON.stringify(preset.capabilities)
}

export function compositionInstructions(composition) {
  return [
    'Ordered specialist stages',
    'Apply each stage to the representative task above, in this order, within this one conversation. Source examples describe each specialist; do not substitute those examples for the current task. Use each stage output as the next stage input. If evidence is missing or conflicting, preserve the uncertainty in the handoff. Finish with the final stage output.',
    ...composition.stages.map((stage, index) => [
      `Stage ${index + 1}: ${stage.source.name}`,
      `Source specialist: ${stage.source.id} · revision ${stage.source.revision} (saved brief snapshot)`,
      `Stage purpose:\n${stage.source.purpose}`,
      `Source representative example (context only):\n${stage.source.example}`,
      `Stage preferred capabilities: ${stage.source.capabilities.join(', ') || 'Ordinary Book chat'}`,
      `Stage knowledge references:\n${stage.source.knowledge_paths.map(value => '@' + value).join('\n') || '(None selected)'}`,
      `Required output / handoff:\n${stage.handoff}`,
    ].join('\n\n')),
    'These stages are one composed task brief for the configured assistant. They do not create separate agents, parallel runs, scheduling, or additional authority.',
  ].join('\n\n')
}
