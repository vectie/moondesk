import { prepareDerivedColumn, applyDerivedColumn } from './source-table-derive.js'
const states = new WeakMap()
const field = (panel,name) => panel.querySelector(`[data-table-derive-${name}]`)
const button = (panel,name) => panel.querySelector(`[data-action="source-table-derive-${name}"]`)
const identity = parts => JSON.stringify([parts.surface.dataset.workspaceId || '',parts.surface.dataset.sourcePath || ''])
const separator = parts => /\.tsv$/i.test(parts.surface.dataset.sourcePath || '') ? '\t' : ','
const supported = parts => /\.(csv|tsv)$/i.test(parts.surface.dataset.sourcePath || '')
function clear(panel,state,message) { state.plan=null; button(panel,'apply').disabled=true; field(panel,'preview').textContent=''; field(panel,'status').textContent=message }
export function syncTableDerive(parts) {
  let panel=parts.surface.querySelector('[data-table-derive]')
  if (!supported(parts)) { if(panel) { panel.hidden=true; states.delete(panel) } return }
  if (!panel) {
    panel=document.createElement('section'); panel.setAttribute('data-table-derive','')
    const heading=document.createElement('h3');heading.textContent='Derive a column by splitting text';panel.append(heading)
    const help=document.createElement('p');help.textContent='Append a new column to this CSV/TSV draft. Enter the exact source header, literal delimiter and one-based part. Missing parts become blank. Trim is optional. Preview does not edit; Apply changes only the unsaved draft. Save remains your choice. Output quotes every cell and uses LF; original cell values stay unchanged. Limits: 512 KiB input/output, 100 data rows, 31 input columns, nonblank distinct headers.';panel.append(help)
    for(const [name,label] of [['column','Exact source header'],['delimiter','Literal split delimiter'],['part','Part (one-based)'],['name','New column name'],['trim','Trim selected part']]) {
      const wrapper=document.createElement('label'),input=document.createElement('input');wrapper.textContent=label+' ';input.setAttribute(`data-table-derive-${name}`,'');input.setAttribute('aria-label',label);input.type=name==='trim'?'checkbox':'text';if(name==='part')input.value='1';wrapper.append(input);panel.append(wrapper)
    }
    for(const [name,label] of [['review','Preview derived column'],['apply','Apply to unsaved draft'],['cancel','Cancel preview'],['undo','Undo derived column']]) { const control=document.createElement('button');control.type='button';control.dataset.action=`source-table-derive-${name}`;control.textContent=label;panel.append(control) }
    for(const name of ['status','preview']) {const item=document.createElement(name==='status'?'p':'pre');item.setAttribute(`data-table-derive-${name}`,'');if(name==='status')item.setAttribute('role','status');panel.append(item)}
    parts.surface.append(panel)
  }
  panel.hidden=false
  let state=states.get(panel)
  if(!state || state.identity!==identity(parts)) {
    state={identity:identity(parts),text:parts.editor.value,disabled:parts.editor.disabled,plan:null,undo:null};states.set(panel,state)
    for(const name of ['column','delimiter','name'])field(panel,name).value=''
    field(panel,'part').value='1';field(panel,'trim').checked=false
    clear(panel,state,'Choose a column and preview before applying.')
  }
  if(state.text!==parts.editor.value || state.disabled!==parts.editor.disabled) {
    clear(panel,state,'Draft or editor availability changed. Preview again.');state.undo=null;state.text=parts.editor.value;state.disabled=parts.editor.disabled
  }
  for(const name of ['column','delimiter','part','name','trim'])field(panel,name).disabled=parts.editor.disabled
  button(panel,'review').disabled=parts.editor.disabled;button(panel,'apply').disabled=parts.editor.disabled || !state.plan
  button(panel,'undo').disabled=parts.editor.disabled || !state.undo
}
export function changeTableDerive(parts) {
  const panel=parts?.surface.querySelector('[data-table-derive]'),state=states.get(panel)
  if(state)clear(panel,state,'Settings changed. Preview again.')
}
export function actTableDerive(parts,action) {
  if(!parts || !supported(parts))return
  syncTableDerive(parts)
  const panel=parts.surface.querySelector('[data-table-derive]'),state=states.get(panel),kind=action.dataset.action.slice('source-table-derive-'.length)
  if(parts.editor.disabled)return
  if(kind==='cancel'){clear(panel,state,'Preview cancelled. Draft unchanged.');return}
  const args=()=>[parts.editor.value,separator(parts),field(panel,'column').value,field(panel,'delimiter').value,field(panel,'part').value,field(panel,'name').value,!!field(panel,'trim').checked]
  function replace(output) {
    const before=parts.editor.value,selection=[parts.editor.selectionStart,parts.editor.selectionEnd,parts.editor.selectionDirection]
    try {parts.editor.setRangeText(output,0,before.length,'select');if(parts.editor.value!==output)throw new Error('Editor did not retain the prepared table.')}
    catch(error){parts.editor.value=before;parts.editor.setSelectionRange(...selection);throw error}
    state.text=output;parts.editor.dispatchEvent(new Event('input',{bubbles:true}));parts.editor.focus()
  }
  try {
    if(kind==='review') {
      state.plan=prepareDerivedColumn(...args());field(panel,'preview').textContent=JSON.stringify(state.plan.preview,null,2)
      field(panel,'status').textContent=`${state.plan.count} records. First 10 shown; Apply uses all records. Existing cell values preserved; quoting and line endings normalized.`;button(panel,'apply').disabled=false
    } else if(kind==='apply') {
      const output=applyDerivedColumn(state.plan,...args()),before=parts.editor.value
      replace(output);state.undo={before,after:output};clear(panel,state,'Derived column applied to the unsaved draft. Save explicitly to persist.');button(panel,'undo').disabled=false
    } else if(kind==='undo') {
      if(!state.undo || parts.editor.value!==state.undo.after)throw new Error('Draft changed; scoped undo is unavailable.')
      const before=state.undo.before;replace(before);state.undo=null;clear(panel,state,'Derived column undone. Original draft restored.');button(panel,'undo').disabled=true
    }
  } catch(error){clear(panel,state,String(error.message || error))}
}
