export function projectCommandEvidence(root) {
  const output = root.querySelector('[data-testid="mooncode-developer-terminal-output"]')
  if (!(output instanceof HTMLElement)) return
  const rows = [...document.querySelectorAll('.mooncode-tool-card:not(.mooncode-approval)')]
    .flatMap(card => {
      const command = card.querySelector('.mooncode-tool-section.command pre')?.textContent?.trim() || ''
      const result = card.querySelector('.mooncode-tool-section.output pre')?.textContent?.trim() || ''
      return command || result ? [{
        command,
        result,
        state: card.dataset.state || 'recorded',
        exit: card.querySelector('.mooncode-tool-section.output .mooncode-tool-section-title')?.textContent?.match(/exit\s+(-?\d+)/)?.[1],
      }] : []
    })
  output.replaceChildren()
  if (!rows.length) {
    const empty = document.createElement('p')
    empty.className = 'mooncode-developer-terminal-empty'
    empty.textContent = 'No command evidence has been recorded in this chat.'
    output.append(empty)
    return
  }
  for (const row of rows) {
    const entry = document.createElement('div')
    entry.className = 'mooncode-developer-terminal-entry'
    if (row.command) {
      const command = document.createElement('div')
      command.className = 'mooncode-developer-terminal-command'
      const prompt = document.createElement('span')
      prompt.className = 'mooncode-developer-terminal-prompt'
      prompt.textContent = '$'
      const code = document.createElement('code')
      code.textContent = row.command
      command.append(prompt, code)
      entry.append(command)
    }
    if (row.result) {
      const result = document.createElement('pre')
      result.className = 'mooncode-developer-terminal-result'
      result.textContent = row.result
      entry.append(result)
    }
    const state = document.createElement('span')
    state.className = `mooncode-developer-terminal-exit ${row.state}`
    state.textContent = `${row.exit == null ? '' : `exit ${row.exit} · `}${row.state}`
    entry.append(state)
    output.append(entry)
  }
}
