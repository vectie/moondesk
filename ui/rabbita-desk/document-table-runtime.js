const hosts = new WeakMap()

function cellCoordinates(reference) {
  const match = String(reference || '').match(/(?:^|!)(\$?[A-Z]+)\$?(\d+)$/i)
  if (!match) return null
  const letters = match[1].replace(/\$/g, '').toUpperCase()
  let column = 0
  for (const letter of letters) column = column * 26 + letter.charCodeAt(0) - 64
  return { column, row: Number(match[2]), letters }
}

function sheetProjection(items, section) {
  const cells = items.map((item, index) => ({ ...item, index, coordinates: cellCoordinates(item.reference) })).filter(item => item.section === section && item.coordinates)
  const rows = [...new Set(cells.map(item => item.coordinates.row))].sort((a, b) => a - b)
  const columns = [...new Set(cells.map(item => item.coordinates.column))].sort((a, b) => a - b)
  return { cells, rows, columns }
}

function sheetCsv(projection, formulas = false) {
  const escape = value => `"${String(value || '').replace(/"/g, '""')}"`
  const cells = new Map(projection.cells.map(item => [`${item.coordinates.row}:${item.coordinates.column}`, item]))
  return projection.rows.map(row => projection.columns.map(column => {
    const cell = cells.get(`${row}:${column}`)
    return escape(formulas && cell?.formula ? cell.formula : cell?.text)
  }).join(',')).join('\r\n')
}

function enhanceSpreadsheetPreview(state) {
  if (state.office?.kind !== 'xlsx') return
  const host = document.querySelector('[data-testid="office-xlsx-preview"]')
  if (!host) return
  const items = state.office.draft_items || []
  const signature = JSON.stringify([state.office.path, state.office.selected, items])
  const previous = hosts.get(host)
  if (previous?.signature === signature && host.querySelector('.document-sheet-grid')) return
  const sections = [...new Set(items.map(item => item.section))]
  let selectedSection = items[state.office.selected]?.section || sections[0] || ''
  let formulas = previous?.formulas || false
  hosts.set(host, { signature, formulas })
  const root = document.createElement('div'); root.className = 'document-sheet-grid'
  host.querySelector('.document-sheet-grid')?.remove()
  host.append(root)
  const cards = host.querySelector('.office-preview-sheet-items')
  if (cards) cards.hidden = true
  const draw = () => {
    root.replaceChildren()
    const toolbar = document.createElement('div'); toolbar.className = 'document-format-toolbar'
    for (const section of sections) {
      const tab = document.createElement('button'); tab.type = 'button'; tab.className = 'secondary-button'; tab.textContent = section || 'Sheet'; tab.setAttribute('aria-pressed', String(section === selectedSection))
      tab.onclick = () => { selectedSection = section; draw() }; toolbar.append(tab)
    }
    const formula = document.createElement('button'); formula.type = 'button'; formula.className = 'secondary-button'; formula.textContent = formulas ? 'Show values' : 'Show formulas'; formula.setAttribute('aria-pressed', String(formulas)); formula.onclick = () => { formulas = !formulas; hosts.get(host).formulas = formulas; draw() }; toolbar.append(formula)
    const projection = sheetProjection(items, selectedSection)
    const download = document.createElement('button'); download.type = 'button'; download.className = 'secondary-button'; download.textContent = 'Export visible grid as CSV'
    download.onclick = () => {
      const url = URL.createObjectURL(new Blob([sheetCsv(projection, formulas)], { type: 'text/csv;charset=utf-8' }))
      const link = document.createElement('a'); link.href = url; link.download = `${selectedSection || 'sheet'}.csv`; document.body.append(link); link.click(); setTimeout(() => { link.remove(); URL.revokeObjectURL(url) }, 1000)
    }
    toolbar.append(download); root.append(toolbar)
    const scroll = document.createElement('div'); scroll.className = 'document-sheet-scroll'
    const table = document.createElement('table'); table.setAttribute('aria-label', `${selectedSection} spreadsheet`)
    const caption = document.createElement('caption'); caption.textContent = `${projection.rows.length} populated rows · ${projection.columns.length} populated columns. Select a cell to edit it beside the preview.`; table.append(caption)
    const head = document.createElement('thead'); const heading = document.createElement('tr'); heading.append(document.createElement('th'))
    for (const column of projection.columns) { const th = document.createElement('th'); th.scope = 'col'; th.textContent = projection.cells.find(item => item.coordinates.column === column).coordinates.letters; heading.append(th) }
    head.append(heading); table.append(head)
    const body = document.createElement('tbody'); const cells = new Map(projection.cells.map(item => [`${item.coordinates.row}:${item.coordinates.column}`, item]))
    for (const row of projection.rows) {
      const tr = document.createElement('tr'); const th = document.createElement('th'); th.scope = 'row'; th.textContent = String(row); tr.append(th)
      for (const column of projection.columns) {
        const td = document.createElement('td'); const cell = cells.get(`${row}:${column}`)
        if (cell) {
          const button = document.createElement('button'); button.type = 'button'; button.textContent = formulas && cell.formula ? cell.formula : cell.text || ' '; button.title = cell.formula || cell.reference
          button.setAttribute('aria-label', `${cell.reference}: ${button.textContent}`); button.setAttribute('aria-pressed', String(cell.index === state.office.selected))
          button.dataset.documentAnchor = String(cell.index); button.dataset.anchorKind = 'cell'; button.dataset.anchorSection = cell.section; button.dataset.anchorReference = cell.reference
          button.onclick = () => {
            const controls = document.querySelectorAll('.wiki-office-navigation .wiki-office-nav-item')
            const control = controls[cell.index] || document.querySelector(`[data-testid="office-nav-${cell.index}"]`)
            control?.click()
          }
          td.append(button)
        }
        tr.append(td)
      }
      body.append(tr)
    }
    table.append(body); scroll.append(table); root.append(scroll)
  }
  draw()
}

export { cellCoordinates, sheetProjection, sheetCsv, enhanceSpreadsheetPreview }
