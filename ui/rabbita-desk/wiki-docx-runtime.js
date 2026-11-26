import { uiText } from './ui-locale.js'

import { installDocxOpsToolbar, renderCommentBadges, syncDocxMetadata } from './wiki-docx-ops.js'

const mounted = new WeakMap()
let installed = false
const style = `
:host { display:block; color:var(--ink,#1f2937); font-family:var(--font-ui,system-ui); }
.sections { position:sticky; top:0; z-index:1; display:flex; gap:8px; align-items:center; padding:8px 16px; background:var(--bg-raised,#fff); border-bottom:1px solid var(--line,#e5e7eb); font-size:13px; }
select { min-width:0; flex:1; height:32px; background:inherit; color:inherit; border:1px solid var(--line,#e5e7eb); border-radius:6px; font:inherit; }
article { max-width:760px; margin:0 auto; padding:24px 32px 64px; font-size:16px; line-height:1.75; overflow-wrap:anywhere; }
p { margin:0 0 14px; white-space:pre-wrap; min-height:1.75em; scroll-margin-top:64px; }
.word-layout section.docx { box-sizing:border-box; width:auto!important; max-width:760px; min-height:0!important; padding:24px 32px!important; margin:0 auto!important; box-shadow:none!important; }
.word-layout article { max-width:none; padding:0; font:inherit; }
.word-layout img, .word-layout svg { max-width:100%; height:auto; }
.word-layout { overflow-x:auto; position:relative; z-index:0; }
p[contenteditable] { cursor:text; outline:none; border-radius:2px; }
p[contenteditable]:focus { box-shadow:inset 2px 0 var(--accent,#2563eb); }
select:focus-visible { outline:2px solid var(--accent,#2563eb); outline-offset:2px; }
.bold { font-weight:700; } .italic { font-style:italic; } .underline { text-decoration:underline; }
@media(max-width:600px) { article { padding:16px 16px 48px; } select { height:44px; } }
`

export function docxParagraphText(paragraph) {
  return paragraph.runs.map(run => run.text).join('')
}

const wordNamespace = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
const normalizedText = text => String(text || '').replace(/\s/g,'')

export function docxProseText(element) {
  let text=''
  for (const node of element.childNodes) {
    if (node.nodeType===3) { text+=node.textContent; continue }
    if (node.nodeType!==1 || node.hasAttribute('data-word-field')) continue
    if (node.localName==='br') { text+='\n'; continue }
    if (node.localName==='div' && text && !text.endsWith('\n')) text+='\n'
    text+=docxProseText(node)
    if (node.localName==='div' && node.nextSibling && !text.endsWith('\n')) text+='\n'
  }
  return text
}

// docx-preview's renderer hook distinguishes generated footnote/endnote
// counters (string children) from authored superscript text (Text nodes).
// Keep references visible, but never write display counters into Word prose.
export function docxRenderNode(input, render) {
  const node=render(input)
  if (input?.tagName==='sup' && input.children?.length===1 &&
    typeof input.children[0]==='string' && /^\d+$/.test(input.children[0])) {
    node.dataset.wordField='true'
    node.setAttribute('contenteditable','false')
    node.title=uiText('Word reference (read-only)')
  }
  return node
}

// Match complete visible paragraph text before assigning a native edit target.
// Empty blocks, drawings, headers and unsupported fields never borrow another
// paragraph's target merely because their numerical positions look similar.
export function matchDocxParagraphs(elements, paragraphs) {
  const byText=new Map()
  for (const paragraph of paragraphs) {
    const key=normalizedText(docxParagraphText(paragraph))
    if (!key) continue
    if (!byText.has(key)) byText.set(key,[])
    byText.get(key).push(paragraph.index)
  }
  const result=new Map()
  let last=-1
  for (const element of elements) {
    const matches=byText.get(normalizedText(docxProseText(element))) || []
    while (matches.length && matches[0]<=last) matches.shift()
    if (!matches.length) continue
    const index=matches.shift()
    result.set(index,element); last=index
  }
  return result
}

export function docxHeadingTitles(xml, stylesXML) {
  const parse=text=>new DOMParser().parseFromString(text,'application/xml')
  const attrs=(element,name)=>element?.getAttributeNS(wordNamespace,name)
  const children=(element,name)=>[...(element?.getElementsByTagNameNS(wordNamespace,name) || [])]
  const styles=new Map()
  for (const style of children(parse(stylesXML),'style')) {
    const outline=children(style,'outlineLvl')[0]
    if (outline) styles.set(attrs(style,'styleId'), Number(attrs(outline,'val'))+1)
  }
  const headings=[]
  for (const paragraph of children(parse(xml),'p')) {
    const properties=[...paragraph.children].find(child=>child.localName==='pPr')
    const direct=children(properties,'outlineLvl')[0]
    const style=children(properties,'pStyle')[0]
    const level=direct ? Number(attrs(direct,'val'))+1 : styles.get(attrs(style,'val'))
    const text=children(paragraph,'t').map(node=>node.textContent).join('')
    if (level>0 && level<10 && text.trim()) headings.push({text,level})
  }
  return headings
}

export function docxDisplayXML(xml) {
  const document=new DOMParser().parseFromString(xml,'application/xml')
  // The renderer otherwise drops an entire run when it contains a field
  // delimiter, including its cached visible result. Materialize those cached
  // values for DISPLAY ONLY. Native saves still patch the original package;
  // field instructions and bookmarks are never rewritten by this projection.
  for (const name of ['fldChar','instrText']) {
    for (const node of [...document.getElementsByTagNameNS(wordNamespace,name)]) node.remove()
  }
  for (const node of [...document.getElementsByTagNameNS(wordNamespace,'fldSimple')]) node.replaceWith(...node.childNodes)
  return new XMLSerializer().serializeToString(document)
}

function disposeView(view) {
  view.root.removeEventListener('keydown',view.onKey)
  view.root.removeEventListener('click',view.onClick)
  for (const url of view.urls || []) URL.revokeObjectURL(url)
  view.root.replaceChildren()
}

function sendDocumentInput(host,payload) {
  const input=host.querySelector('[data-docx-input]')
  if (!input) return
  input.value=JSON.stringify(payload)
  input.dispatchEvent(new Event('input',{bubbles:true}))
}

function saveDocument(host,view) {
  if (!view || host.dataset.saving==='true') return
  sendDocumentInput(host,{action:'save',paragraphs:[...view.drafts].map(([paragraph,text])=>({paragraph,text}))})
}

async function loadWordView(host, view) {
  view.loading=true
  view.article.setAttribute('aria-busy','true')
  const loading=document.createElement('p'); loading.textContent=uiText('Opening document…'); view.article.append(loading)
  try {
    const [{renderAsync,defaultOptions},{default:JSZip},response]=await Promise.all([
      import('docx-preview'), import('jszip'), fetch(host.dataset.sourceUrl,{credentials:'same-origin',cache:'no-store'}),
    ])
    if (!response.ok) throw new Error(uiText('Document could not be opened'))
    const bytes=await response.arrayBuffer()
    const body=document.createElement('div'); body.className='word-layout'
    const styles=document.createElement('div')
    const archive=await JSZip.loadAsync(bytes)
    const [xml,styleXML]=await Promise.all([archive.file('word/document.xml').async('string'),archive.file('word/styles.xml')?.async('string') || ''])
    archive.file('word/document.xml',docxDisplayXML(xml))
    const displayBytes=await archive.generateAsync({type:'uint8array'})
    await renderAsync(displayBytes,body,styles,{inWrapper:false,ignoreWidth:true,ignoreHeight:true,ignoreFonts:true,breakPages:false,renderHeaders:false,renderFooters:false,renderAltChunks:false,h:input=>docxRenderNode(input,defaultOptions.h)})
    if (!host.isConnected || mounted.get(host)!==view) return
    const paragraphs=JSON.parse(host.querySelector('[data-docx-model]').textContent)
    view.nodes=matchDocxParagraphs([...body.querySelectorAll('article p')],paragraphs)
    view.headings=docxHeadingTitles(xml,styleXML)
    view.urls=[...body.querySelectorAll('[src]')].map(node=>node.getAttribute('src')).filter(url=>url?.startsWith('blob:'))
    for (const [index,element] of view.nodes) element.dataset.paragraph=String(index)
    for (const [index,element] of view.nodes) view.originalTexts.set(index,docxProseText(element))
    for (const paragraph of paragraphs) view.signatures.set(paragraph.index,JSON.stringify(paragraph.runs))
    for (const link of body.querySelectorAll('a[href]')) {
      const href=link.getAttribute('href')
      if (!href.startsWith('#') && !/^(https?:|mailto:)/i.test(href)) link.removeAttribute('href')
      else if (!href.startsWith('#')) { link.target='_blank'; link.rel='noopener noreferrer' }
    }
    view.article.style.padding='0'
    view.article.replaceChildren(body)
    view.root.insertBefore(styles,view.article)
    view.rich=true
  } catch (error) {
    // Keep a readable, editable text view if layout rendering fails. The error
    // is explicit; never present a partial layout as a successful Word render.
    loading.textContent=uiText('Word layout could not be loaded. Showing document text.')
    view.rich=false
  } finally {
    if (mounted.get(host)===view && host.isConnected) {
      view.loading=false; view.model=null
      view.article.removeAttribute('aria-busy')
      enhance(host)
      renderCommentBadges(view)
    }
  }
}

function drawRuns(element, runs) {
  element.replaceChildren(...runs.map(run => {
    const span = document.createElement('span')
    span.textContent = run.text
    span.className = [run.bold && 'bold', run.italic && 'italic', run.underline && 'underline'].filter(Boolean).join(' ')
    return span
  }))
  if (!element.textContent) element.append(document.createElement('br'))
}

function enhance(host) {
  const model = host.querySelector('[data-docx-model]')?.textContent || '[]'
  const editing = host.dataset.editing === 'true'
  const saving = host.dataset.saving === 'true'
  let view = mounted.get(host)
  let restoreScroll
  if (view && view.identity !== host.dataset.identity) {
    const prefix=value=>value?.slice(0,value.lastIndexOf(':'))
    const pendingReload=prefix(view.identity)===prefix(host.dataset.identity) && host.dataset.dirty==='true' && editing
    if (!pendingReload) { disposeView(view); view = null }
  }
  if (view?.loading) return
  if (view?.rich && view.editing && !editing) {
    restoreScroll=host.closest('.wiki-docx-surface')?.scrollTop || 0
    disposeView(view); view=null
  }
  if (view?.model === model && view.editing === editing && view.saving === saving) return
  const paragraphs = JSON.parse(model)
  if (!view) {
    const root = host.shadowRoot || host.attachShadow({mode:'open'})
    const css = document.createElement('style'); css.textContent = style
    const article = document.createElement('article')
    article.setAttribute('aria-label', uiText('Document text'))
    root.append(css, article)
    view = {root, article, nodes:new Map(), signatures:new Map(), identity:host.dataset.identity,restoreScroll,drafts:new Map(),originalTexts:new Map(),dirty:false}
    mounted.set(host, view)
    installDocxOpsToolbar(host, view, loadWordView)
    article.addEventListener('input', event => {
      const paragraph = event.target.closest('[data-paragraph]')
      if (!paragraph || host.dataset.saving === 'true') return
      const index=Number(paragraph.dataset.paragraph)
      const text=docxProseText(paragraph).replace(/\r\n?/g,'\n')
      if (text===view.originalTexts.get(index)) view.drafts.delete(index)
      else view.drafts.set(index,text)
      const dirty=view.drafts.size>0
      if (dirty!==view.dirty) { view.dirty=dirty; sendDocumentInput(host,{action:'dirty',dirty}) }
    })
    article.addEventListener('paste', event => {
      // Never import arbitrary HTML or images into text-only DOCX patches.
      if (!event.target.closest('[contenteditable]')) return
      event.preventDefault()
      document.execCommand('insertText', false, event.clipboardData.getData('text/plain'))
    })
    view.onKey = event => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 's') {
        event.preventDefault()
        saveDocument(host,view)
      }
    }
    root.addEventListener('keydown',view.onKey)
    view.onClick=event=>{
      const link=event.target.closest?.('a[href^="#"]')
      if (!link) return
      const target=root.getElementById(link.getAttribute('href').slice(1))
      if (target) { event.preventDefault(); target.scrollIntoView({block:'start'}) }
    }
    root.addEventListener('click',view.onClick)
    if (host.dataset.sourceUrl) { void loadWordView(host,view); return }
  }
  const entering = editing && !view.editing
  const leaving = !editing && view.editing
  for (const paragraph of paragraphs) {
    if (!view.originalTexts.has(paragraph.index)) view.originalTexts.set(paragraph.index,docxParagraphText(paragraph))
    let element = view.nodes.get(paragraph.index)
    if (!element) {
      if (view.rich) continue
      element = document.createElement('p')
      element.dataset.paragraph = String(paragraph.index)
      view.nodes.set(paragraph.index, element)
      view.article.append(element)
    }
    const text = docxParagraphText(paragraph)
    // Rabbita owns the hidden model; the runtime owns the document DOM. Do not
    // replace the focused paragraph on each model echo (caret/IME/undo survive).
    const signature = JSON.stringify(paragraph.runs)
    if (leaving || (!view.drafts.has(paragraph.index) && view.signatures.get(paragraph.index) !== signature &&
      (!editing || view.root.activeElement !== element || docxProseText(element) !== text))) drawRuns(element, paragraph.runs)
    view.signatures.set(paragraph.index, signature)
    if (editing && !saving && !element.querySelector('img,svg,math')) {
      element.removeAttribute('aria-level')
      element.setAttribute('contenteditable','plaintext-only')
      element.setAttribute('role','textbox')
      element.setAttribute('aria-multiline','true')
      element.setAttribute('aria-label', uiText('Document text'))
    } else {
      element.removeAttribute('contenteditable')
      element.removeAttribute('role')
      element.removeAttribute('aria-multiline')
      element.removeAttribute('aria-label')
      if (element.dataset.headingLevel) {
        element.setAttribute('role','heading')
        element.setAttribute('aria-level',element.dataset.headingLevel)
      }
    }
  }
  // Use Word's actual outline/style metadata, not bold table cells or guessed
  // paragraph numbers, for chapter navigation.
  if (leaving) { view.nav?.remove(); view.nav=null }
  if (!view.nav) {
    const byText=new Map(paragraphs.map(p=>[normalizedText(docxParagraphText(p)),p]))
    const titles = (view.headings || []).map(heading=>({heading,paragraph:byText.get(normalizedText(heading.text))})).filter(item=>item.paragraph && view.nodes.has(item.paragraph.index))
    if (titles.length > 1) {
      const nav = document.createElement('label'); nav.className='sections'; nav.append(uiText('Sections'))
      const select = document.createElement('select'); select.setAttribute('aria-label',uiText('Jump to section'))
      for (const {heading,paragraph} of titles) {
        const node=view.nodes.get(paragraph.index)
        node.dataset.headingLevel=String(heading.level)
        if (!editing) { node.setAttribute('role','heading'); node.setAttribute('aria-level',String(heading.level)) }
        const option=document.createElement('option'); option.value=String(paragraph.index); option.textContent=' '.repeat(Math.min(heading.level-1,4))+heading.text; select.append(option)
      }
      select.addEventListener('change',()=>{
        const paragraph=view.nodes.get(Number(select.value))
        paragraph?.scrollIntoView({block:'start',behavior:'auto'})
        if (host.dataset.editing==='true') paragraph?.focus({preventScroll:true})
      })
      nav.append(select); view.root.insertBefore(nav,view.article); view.nav=nav
    }
  }
  view.model=model; view.editing=editing; view.saving=saving
  if (entering) {
    const scroller=host.closest('.wiki-docx-surface')
    const top=(scroller?.getBoundingClientRect().top || 0)+64
    const editable=[...view.nodes.values()].filter(node=>node.hasAttribute('contenteditable'))
    const visible=editable.find(node=>node.getBoundingClientRect().bottom>top)
    ;(visible || editable[0])?.focus({preventScroll:true})
  }
  if (view.restoreScroll!==undefined) {
    const scroller=host.closest('.wiki-docx-surface')
    if (scroller) scroller.scrollTop=view.restoreScroll
    view.restoreScroll=undefined
  }
}

export function installWikiDocxRuntime() {
  if (installed) return
  installed=true
  document.addEventListener('click',event=>{
    const button=event.target.closest?.('[data-testid="wiki-docx-save"]')
    if (!button) return
    const host=button.closest('.wiki-document-viewer')?.querySelector('[data-testid="wiki-docx-document"]')
    if (host) { event.preventDefault(); event.stopImmediatePropagation(); saveDocument(host,mounted.get(host)) }
  },true)
  const refresh = () => {
    for (const host of document.querySelectorAll('[data-testid="wiki-docx-document"]')) enhance(host)
  }
  new MutationObserver(refresh).observe(document.getElementById('app') || document.body,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['data-editing','data-saving','data-identity','data-dirty']})
  window.addEventListener('beforeunload',event=>{
    if ([...document.querySelectorAll('[data-testid="wiki-docx-document"]')].some(host=>mounted.get(host)?.drafts.size>0 || host.dataset.dirty==='true')) { event.preventDefault(); event.returnValue='' }
  })
  refresh()
}
