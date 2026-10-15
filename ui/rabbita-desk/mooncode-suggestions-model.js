export function conversationSuggestions({ answer = '', user = '', status = '', failedCommand = '', selectedPath = '' }) {
  const suggestions = []
  const add = (id, label, text, reason) => suggestions.push({ id, label, text, reason })
  if (failedCommand.trim()) {
    add('failed-command', 'Fix this command', `Investigate why this command failed and fix the cause:\n\n${failedCommand.trim().slice(0, 2000)}`, 'A command in this conversation failed')
  }
  if (['cancelled', 'interrupted', 'stopped'].includes(status)) {
    add('resume', 'Continue the task', `Continue the task from where it stopped.${user.trim() ? ` The request was:\n\n${user.trim().slice(0, 1600)}` : ''}`, 'The latest work was interrupted')
  }
  if (!answer.trim() && !user.trim()) return suggestions
  const question = answer.trim().match(/([^\n.!?。！？]{12,180}[?？])\s*$/)?.[1]?.trim()
  if (question) add('answer-question', 'Answer the question', `Regarding your question, “${question}”:\n`, 'The latest answer asks a question; complete this draft with your answer')
  if (selectedPath.trim()) {
    add('explain-file', 'Explain this file', `Explain ${selectedPath.trim()} in the context of our current task. Focus on the relevant code and how it works.`, `The selected file is ${selectedPath.trim()}`)
  }
  if (/\b(?:changed|implemented|updated|fixed|added|refactored)\b|修改|实现|修复|更新/i.test(answer)) {
    add('review-changes', 'Review the changes', 'Review the changes you just described. Explain the behavior users will see and identify any remaining functional issues.', 'The latest answer describes implementation changes')
  }
  if (/\b(?:next steps?|remaining|still need|to do|follow.up)\b|下一步|待完成|仍需/i.test(answer)) {
    add('next-step', 'Take the next step', 'Continue with the next unfinished product feature from your last answer. Keep the changes focused on the user workflow.', 'The latest answer identifies unfinished work')
  }
  if (answer.trim()) add('explain-result', 'Explain the result', 'Explain the result from your last answer with a concrete example of how I would use it.', 'Based on the latest answer in this conversation')
  return suggestions.slice(0, 3)
}

export function suggestionSignature(input) {
  const source = JSON.stringify(input)
  let hash = 2166136261
  for (let index = 0; index < source.length; index++) hash = Math.imul(hash ^ source.charCodeAt(index), 16777619)
  return (hash >>> 0).toString(36)
}
