// Presentation only. Task, queue, goal and fork state belongs to MoonClaw.
import { iconMarkup, statusIconName, setIconButton } from './ui-icons.js'

export function installMoonCodeTaskControls() {
  const mounted = new WeakMap()
  function mount(root) {
    const id = root.dataset.sessionId
    if (!id || mounted.get(root) === id) return
    mounted.set(root, id)
    let state = null
    let loading = false
    const drafts = new Map()
    const sections = new Map()
    let imageInputs = []
    const imageCache = new Map()
    let inspectionFailed = false
    const status = document.createElement('p')
    status.className = 'mooncode-task-feedback'
    status.setAttribute('role', 'status')
    const content = document.createElement('div')
    root.replaceChildren(status, content)
    const element = (tag, text, className) => {
      const el = document.createElement(tag)
      if (text != null) el.textContent = text
      if (className) el.className = className
      return el
    }
    const button = (text, action) => {
      const el = element('button', text)
      el.type = 'button'
      el.addEventListener('click', action)
      return el
    }
    const iconButton = (icon, label, action) => setIconButton(button(label, action), icon, label)
    const stateLabel = (value, label = value, tag = 'p') => {
      const row = element(tag, null, 'mooncode-task-status')
      const icon = statusIconName(value)
      if (icon) row.innerHTML = iconMarkup(icon)
      row.append(document.createTextNode(`${icon ? ' ' : ''}${label || 'Status unavailable'}`))
      return row
    }
    const field = (label, value = '', rows = 3, key = label) => {
      const wrap = element('label', label, 'mooncode-task-field')
      const input = document.createElement('textarea')
      input.value = drafts.has(key) ? drafts.get(key) : value
      input.rows = rows
      input.addEventListener('input', () => drafts.set(key, input.value))
      wrap.append(input)
      return [wrap, input]
    }
    const section = (title, open = false) => {
      const details = document.createElement('details')
      const key = title.split(' · ')[0]
      details.open = sections.has(key) ? sections.get(key) : open
      details.addEventListener('toggle', () => sections.set(key, details.open))
      details.append(element('summary', title))
      content.append(details)
      return details
    }
    const openSession = (sessionId, draft = '', images = []) => window.dispatchEvent(new CustomEvent('moondesk:open-code-session', { detail: { sessionId, draft, images } }))
    function loadImage(path) {
      if (!imageCache.has(path)) imageCache.set(path, fetch(`/api/mooncode/sessions/${encodeURIComponent(id)}/task-controls`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'load_image', path }),
      }).then(async response => {
        const image = await response.json()
        if (!response.ok) throw new Error(image.message || 'Could not load this image')
        return image
      }).catch(error => { imageCache.delete(path); throw error }))
      return imageCache.get(path)
    }
    async function request(payload, success = '', silent = false) {
      if (loading) return
      loading = true
      root.setAttribute('aria-busy', 'true')
      if (!silent) status.textContent = payload.action === 'inspect' ? 'Loading task…' : 'Saving…'
      try {
        const response = await fetch(`/api/mooncode/sessions/${encodeURIComponent(id)}/task-controls`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
        })
        const data = await response.json()
        if (!response.ok) throw new Error(data.message || data.error?.message || 'Could not update this task')
        if (!root.isConnected || root.dataset.sessionId !== id) return
        inspectionFailed = false
        state = data
        if (data.forked_from) {
          status.textContent = 'New conversation ready.'
          openSession(data.session_id, data.draft || '', data.draft_images || [])
        } else {
          render()
          if (!silent) status.textContent = success
        }
      } catch (error) {
        inspectionFailed = payload.action === 'inspect'
        status.textContent = error.message
        status.setAttribute('role', 'alert')
      } finally {
        loading = false
        root.removeAttribute('aria-busy')
      }
    }
    function render() {
      content.replaceChildren()
      status.setAttribute('role', 'status')
      const toolbar = element('div', null, 'mooncode-task-actions')
      toolbar.append(button('Refresh', () => request({ action: 'inspect' })))
      content.append(toolbar)

      for (const question of state.questions || []) {
        const card = element('section', null, 'mooncode-task-question')
        card.append(element('h4', question.question))
        const answer = text => request({ action: 'answer_question', question_id: question.question_id, answer: text }, 'Answer sent. Work will continue.')
        const choices = element('div', null, 'mooncode-task-actions')
        for (const option of question.options || []) choices.append(button(option, () => answer(option)))
        const [label, input] = field('Your answer', '', 2, question.question_id)
        card.append(choices, label, button('Send answer', () => answer(input.value)))
        content.append(card)
      }

      const queue = section(`Up next${state.queue.length ? ` · ${state.queue.length}` : ''}`, state.queue.length > 0)
      if (!state.queue.length) queue.append(element('p', 'No queued messages.'))
      state.queue.forEach((item, index) => {
        const card = element('div', null, 'mooncode-task-queue-item')
        const [label, input] = field(`Message ${index + 1}`, item.message, 3, item.id)
        card.append(label)
        if (item.image_count) card.append(element('small', `${item.image_count} image attachment(s) retained`))
        const actions = element('div', null, 'mooncode-task-actions')
        actions.append(button('Save edit', () => request({ action: 'edit', target_command_id: item.id, message: input.value }, 'Queued message updated.')))
        const move = direction => {
          const order = state.queue.map(row => row.id)
          ;[order[index], order[index + direction]] = [order[index + direction], order[index]]
          request({ action: 'reorder', order }, 'Queue reordered.')
        }
        const up = button('Move up', () => move(-1)); up.disabled = index === 0
        const down = button('Move down', () => move(1)); down.disabled = index === state.queue.length - 1
        const next = button('Send next', () => request({ action: 'reorder', order: [item.id, ...state.queue.filter(row => row.id !== item.id).map(row => row.id)] }, 'This message will run next.')); next.disabled = index === 0
        const guide = button('Guide now', () => request({ action: 'guide_now', target_command_id: item.id, message: input.value }, 'Guidance accepted for the running task; it will apply at its next safe point.'))
        guide.disabled = Boolean(item.image_count) || !state.context?.active_command_id
        guide.title = item.image_count ? 'Use Send next to keep image attachments in their own turn.' : 'Turn this queued message into guidance for the running task.'
        actions.append(next, guide, up, down, button('Remove', () => request({ action: 'remove', target_command_id: item.id }, 'Message removed from the queue.')))
        card.append(actions)
        queue.append(card)
      })

      const task = section('Goal and plan', Boolean(state.goal || state.plan))
      const goal = state.goal?.genesis
      if (goal) {
        task.append(element('p', goal.objective, 'mooncode-task-objective'))
        const criteria = element('ul')
        for (const criterion of goal.criteria || []) criteria.append(element('li', criterion.criterion))
        task.append(criteria, element('small', `Goal: ${state.goal.status?.terminal ? state.goal.status.outcome : state.goal.status?.phase || 'active'}`))
      } else {
        const [objectiveLabel, objective] = field('What should this task achieve?', '', 2)
        const [criteriaLabel, criteria] = field('Done when · one outcome per line', '', 3)
        task.append(objectiveLabel, criteriaLabel, button('Set goal', () => {
          const outcomes = criteria.value.split('\n').map(line => line.trim()).filter(Boolean)
          if (!objective.value.trim() || !outcomes.length) { status.textContent = 'Add an objective and at least one outcome.'; return }
          request({ action: 'set_goal', objective: objective.value.trim(), criteria: outcomes.map((criterion, index) => ({ id: `outcome-${index + 1}`, criterion })) }, 'Goal saved. It will guide the next agent turn.')
        }))
      }
      const [planLabel, plan] = field('Working plan', state.plan, 5)
      task.append(planLabel, button('Save plan', () => request({ action: 'set_plan', plan: plan.value }, 'Plan saved for the next agent turn.')), button('Implement this plan', async () => {
        await request({ action: 'set_plan', plan: plan.value }, 'Plan saved.')
        window.dispatchEvent(new CustomEvent('moondesk:add-context', { detail: { kind: 'plan', label: 'Working plan', text: `Implement this plan:\n${plan.value}`, action: 'change' } }))
      }))

      const branches = section('Try another approach')
      branches.append(element('p', 'Branch from completed turns. This task keeps running.'))
      const [titleLabel, title] = field('New chat title', 'Another approach', 1)
      branches.append(titleLabel, button('Fork conversation', () => request({ action: 'fork', title: title.value.trim() || 'Another approach' })), button('Ask a side question', () => request({ action: 'fork', title: 'Side question' })))

      const images = section('Create and edit images')
      images.append(element('p', 'Requires a provider with Responses image generation. Images save to artifacts/images in this book.'))
      const imageModelLabel = element('label', 'Image-capable model', 'mooncode-task-field')
      const imageModel = document.createElement('select')
      const availableModels = document.querySelector('[data-testid="mooncode-composer-controls"]')?.dataset.models?.split('\n').filter(Boolean) || []
      for (const name of new Set([state.context.model, ...availableModels].filter(Boolean))) {
        const option = element('option', name); option.value = name; imageModel.append(option)
      }
      imageModel.value = drafts.get('Image-capable model') || state.context.model || ''
      imageModel.addEventListener('change', () => drafts.set('Image-capable model', imageModel.value))
      imageModelLabel.append(imageModel)
      const [imagePromptLabel, imagePrompt] = field('Describe the image or the changes you want', '', 4)
      const uploadLabel = element('label', 'Reference images', 'mooncode-task-field')
      const upload = document.createElement('input')
      upload.type = 'file'; upload.accept = 'image/png,image/jpeg,image/webp'; upload.multiple = true
      const readImage = file => new Promise((resolve, reject) => {
        const reader = new FileReader()
        reader.onerror = () => reject(new Error('Could not read this image'))
        reader.onload = () => resolve({ type: 'image', media_type: file.type, name: file.name || 'reference.png', data_base64: String(reader.result).split(',')[1] })
        reader.readAsDataURL(file)
      })
      upload.addEventListener('change', async () => {
        try {
          imageInputs = await Promise.all([...upload.files].map(readImage))
          status.textContent = `${imageInputs.length} reference image(s) ready.`
        } catch (error) { status.textContent = error.message }
      })
      uploadLabel.append(upload)
      images.append(imageModelLabel, imagePromptLabel, uploadLabel)
      if (imageInputs.length) images.append(element('small', `${imageInputs.length} reference image(s): ${imageInputs.map(image => image.name).join(', ')}`), button('Clear reference images', () => { imageInputs = []; render() }))
      images.append(button(imageInputs.length ? 'Generate edited image' : 'Generate image', () => request({ action: 'generate_image', prompt: imagePrompt.value, model: imageModel.value, images: imageInputs }, 'Image generation started. You can keep working while it finishes.')))
      for (const job of state.image_jobs || []) {
        const card = element('div', null, 'mooncode-task-image-job')
        card.append(element('strong', job.prompt), stateLabel(job.status, job.status === 'running' ? 'Creating image…' : job.status))
        if (job.message) card.append(element('p', job.message))
        for (const path of job.paths || []) {
          const preview = document.createElement('img')
          preview.alt = job.prompt; preview.loading = 'lazy'
          const download = element('a', 'Download PNG')
          download.download = path.split('/').pop()
          loadImage(path).then(image => { const url = `data:${image.media_type};base64,${image.data_base64}`; preview.src = url; download.href = url }).catch(error => { preview.alt = error.message })
          card.append(preview, download, button('Edit this image', async () => {
            try {
              const image = await loadImage(path)
              imageInputs = [{ type: 'image', name: path.split('/').pop(), media_type: image.media_type, data_base64: image.data_base64 }]
              drafts.set('Describe the image or the changes you want', '')
              render()
              status.textContent = 'Image selected. Describe what you want to change.'
            } catch (error) { status.textContent = error.message }
          }), button('Use in task', () => window.dispatchEvent(new CustomEvent('moondesk:add-context', { detail: { kind: 'image', label: path, path, text: `Use the generated image at ${path}.`, action: 'change' } }))))
        }
        images.append(card)
      }

      const team = section(`Agent team${state.workers.length ? ` · ${state.workers.length}` : ''}`, state.workers.length > 0)
      if (!state.workers.length) team.append(element('p', 'No delegated agents yet.'))
      for (const worker of state.workers) {
        const card = element('div', null, 'mooncode-task-queue-item')
        card.append(element('strong', worker.worker_id), stateLabel(worker.status))
        if (worker.result?.answer) card.append(element('p', worker.result.answer))
        card.append(iconButton('chat', `Open ${worker.worker_id} chat`, () => openSession(worker.child_session_id)))
        if (!worker.terminal) {
          const [guidanceLabel, guidance] = field(`Guide ${worker.worker_id}`, '', 2)
          card.append(guidanceLabel, button('Send guidance', () => request({ action: 'guide_worker', worker_id: worker.worker_id, message: guidance.value }, 'Guidance sent.')), iconButton('stop', `Stop ${worker.worker_id}`, () => request({ action: 'stop_worker', worker_id: worker.worker_id }, 'Stop requested.')))
        }
        team.append(card)
      }

      const context = section('Context and recap')
      context.append(element('p', `Book: ${state.context.book_root}`), element('p', `Model: ${state.context.model || 'Choose a model in the composer'}`))
      context.append(element('p', `${state.context.message_count} messages in this chat`))
      const turns = state.context.conversation || []
      const measured = turns.map(turn => turn.usage).filter(usage => usage?.measured)
      if (measured.length) context.append(element('p', `Recorded usage: ${measured.reduce((sum, usage) => sum + usage.input_tokens, 0).toLocaleString()} input · ${measured.reduce((sum, usage) => sum + usage.output_tokens, 0).toLocaleString()} output tokens`))
      for (const turn of turns) {
        const row = element('div', null, 'mooncode-task-recap')
        const user = turn.user?.content || turn.user?.message || turn.user?.text || ''
        const answer = turn.assistant?.content || turn.assistant?.message || turn.assistant?.text || ''
        row.append(element('strong', typeof user === 'string' ? user : 'Attached context'), element('p', typeof answer === 'string' ? answer : ''), stateLabel(turn.status, turn.status, 'small'))
        row.append(button('Edit and retry from here', () => request({ action: 'fork', before_command_id: turn.command_id, title: 'Revised approach' })))
        context.append(row)
      }
      const [recapLabel, recap] = field('Working recap', state.recap || '', 5)
      context.append(element('p', 'Future turns use this recap in place of earlier context. Your full history stays available.'), recapLabel, button('Use recap for future turns', () => request({ action: 'save_recap', message: recap.value }, 'Recap saved. Future turns keep the recap and newer messages.')))
      const memory = section('Personal preferences')
      memory.append(element('p', 'Applies to coding chats across all books.'))
      const [memoryLabel, memoryInput] = field('What should the agent remember about how you work?', state.personal_memory || '', 5)
      memory.append(memoryLabel, button('Save preferences', () => request({ action: 'save_memory', memory: memoryInput.value }, 'Personal preferences saved.')), button('Clear preferences', () => { drafts.delete('What should the agent remember about how you work?'); request({ action: 'save_memory', memory: '' }, 'Personal preferences cleared.') }))
    }
    request({ action: 'inspect' })
    const refresh = setInterval(() => {
      if (!root.isConnected || root.dataset.sessionId !== id) { clearInterval(refresh); return }
      if (!inspectionFailed && !root.contains(document.activeElement) && !document.hidden) request({ action: 'inspect' }, '', true)
    }, 5000)
  }
  const scan = () => document.querySelectorAll('[data-mooncode-task-controls]').forEach(mount)
  const observer = new MutationObserver(scan)
  observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-session-id'] })
  scan()
  return () => observer.disconnect()
}
