// Task forms produce a new invocation, never a new creator revision or authority.
export function taskInputKeys(template) {
  if (typeof template !== 'string' || !template.trim() || template.length > 8000 || template.includes('\0')) throw new Error('A task template must contain 1–8 {{input_name}} fields and fit 8,000 characters.')
  const keys = [...new Set([...template.matchAll(/\{\{([a-z][a-z0-9_]{0,39})\}\}/g)].map(match => match[1]))]
  const rest = template.replace(/\{\{([a-z][a-z0-9_]{0,39})\}\}/g, '')
  if (!keys.length || keys.length > 8 || rest.includes('{{') || rest.includes('}}') || keys.some(key => ['constructor', 'prototype', '__proto__'].includes(key))) throw new Error('Use 1–8 distinct {{input_name}} fields: lowercase letters, numbers and underscores; start with a letter.')
  return keys
}
export function validTaskForm(form) {
  try { return form?.contract === 'moondesk.specialist-task-form.v1' && taskInputKeys(form.template).length > 0 } catch { return false }
}
export function taskInputErrors(form, values) {
  if (!validTaskForm(form)) throw new Error('This creator has no valid task form. Revise its template first.')
  const errors = []
  for (const key of taskInputKeys(form.template)) {
    const value = values && Object.hasOwn(values, key) ? values[key] : null
    if (typeof value !== 'string' || !value.trim() || value.length > 4000 || value.includes('\0')) errors.push(`Enter ${key} (1–4,000 characters).`)
  }
  return errors
}
export function fillTaskForm(form, values) {
  const errors = taskInputErrors(form, values)
  if (errors.length) throw new Error(errors[0])
  // Callback replacement is literal and single-pass: values cannot become new slots.
  const task = form.template.replace(/\{\{([a-z][a-z0-9_]{0,39})\}\}/g, (_, key) => values[key])
  if (task.length > 8000) throw new Error('The filled task exceeds 8,000 characters. Shorten the inputs or template.')
  return task
}
