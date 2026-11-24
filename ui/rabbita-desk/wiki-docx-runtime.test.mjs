import test from 'node:test'
import assert from 'node:assert/strict'
import { JSDOM } from 'jsdom'
import { docxParagraphText, installWikiDocxRuntime, matchDocxParagraphs, docxHeadingTitles, docxProseText, docxRenderNode, docxDisplayXML } from './wiki-docx-runtime.js'

test('Wiki reads and edits the document without run selectors, preserving focused DOM and save shortcut', async () => {
  const dom = new JSDOM('<div id="app"><section class="wiki-document-viewer"><button data-testid="wiki-docx-save">Save</button><div data-testid="wiki-docx-document" data-editing="false"><pre data-docx-model hidden></pre><input data-docx-input hidden></div></section></div>', {url:'http://localhost:4201'})
  const previous = new Map()
  for (const name of ['window','document','HTMLElement','Element','MutationObserver','Event','DOMParser','XMLSerializer']) {
    previous.set(name,Object.getOwnPropertyDescriptor(globalThis,name))
    Object.defineProperty(globalThis,name,{configurable:true,value:dom.window[name]})
  }
  try {
    const host=document.querySelector('[data-testid="wiki-docx-document"]')
    const data=host.querySelector('pre')
    const paragraphs = [
      {index:0,runs:[{text:'第一章',bold:true}]},
      {index:1,runs:[{text:'Hello ',bold:true},{text:'world😀',italic:true}]},
      {index:2,runs:[{text:'第二章',bold:true}]},
    ]
    assert.equal(docxParagraphText(paragraphs[1]),'Hello world😀')
    data.textContent=JSON.stringify(paragraphs)
    installWikiDocxRuntime()
    const root=host.shadowRoot
    assert.equal(root.querySelector('article').textContent,'第一章Hello world😀第二章')
    assert.equal(root.querySelectorAll('[contenteditable]').length,0)
    assert.equal(root.querySelector('select'),null)
    const sample=document.createElement('div')
    sample.innerHTML='<p>Unmatched header</p><p>第一章</p><p>Hello world😀</p><p>第二章</p>'
    assert.deepEqual([...matchDocxParagraphs([...sample.children],paragraphs).keys()],[0,1,2])
    const render=input=>{const node=document.createElement(input.tagName); node.append(...input.children); return node}
    const field=docxRenderNode({tagName:'sup',children:['12']},render)
    assert.equal(field.getAttribute('contenteditable'),'false')
    const authored=docxRenderNode({tagName:'sup',children:[document.createTextNode('12')]},render)
    assert.equal(authored.hasAttribute('data-word-field'),false)
    sample.innerHTML='<p>Source <sup><sup data-word-field contenteditable="false">12</sup></sup> text<br>Second line</p>'
    const matched=matchDocxParagraphs([...sample.children],[{index:5,runs:[{text:'Source  text\nSecond line'}]}])
    assert.equal(matched.size,1)
    assert.equal(sample.querySelector('sup > sup').getAttribute('contenteditable'),'false')
    assert.equal(docxProseText(sample.firstChild),'Source  text\nSecond line')
    const ns='http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    const styles=`<w:styles xmlns:w="${ns}"><w:style w:styleId="Heading1"><w:pPr><w:outlineLvl w:val="0"/></w:pPr></w:style></w:styles>`
    const xml=`<w:document xmlns:w="${ns}"><w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>第一章</w:t></w:r></w:p><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Bold table cell is not a section</w:t></w:r></w:p></w:document>`
    assert.deepEqual(docxHeadingTitles(xml,styles),[{text:'第一章',level:1}])
    const fields=`<w:document xmlns:w="${ns}"><w:p><w:r><w:fldChar w:fldCharType="end"/><w:t>12</w:t></w:r><w:r><w:instrText>NOTEREF abc</w:instrText></w:r></w:p></w:document>`
    const display=docxDisplayXML(fields)
    assert.ok(display.includes('<w:t>12</w:t>'))
    assert.ok(!display.includes('fldChar'))
    assert.ok(!display.includes('NOTEREF'))
    assert.ok(fields.includes('NOTEREF'))
    host.dataset.editing='true'
    await new Promise(r=>setTimeout(r,0))
    assert.equal(root.querySelectorAll('[contenteditable="plaintext-only"]').length,3)
    const paragraph=root.querySelector('[data-paragraph="1"]')
    paragraph.focus()
    paragraph.textContent='Hello reader😀'
    let payload
    const notifications=[]
    host.querySelector('input').addEventListener('input',()=>{payload=JSON.parse(host.querySelector('input').value);notifications.push(payload)})
    paragraph.dispatchEvent(new dom.window.Event('input',{bubbles:true}))
    assert.deepEqual(payload,{action:'dirty',dirty:true})
    for (let i=0;i<30;i++) {
      paragraph.textContent='Hello reader😀'+'.'.repeat(i+1)
      paragraph.dispatchEvent(new dom.window.Event('input',{bubbles:true}))
    }
    assert.equal(notifications.length,1,'typing must not serialize the full dissertation through the model on every character')
    paragraph.textContent='Hello reader😀'
    paragraph.dispatchEvent(new dom.window.Event('input',{bubbles:true}))
    const node=paragraph.firstChild
    paragraphs[1].runs=[{text:'Hello reader😀',bold:true}]
    data.textContent=JSON.stringify(paragraphs)
    await new Promise(r=>setTimeout(r,0))
    assert.equal(paragraph.firstChild,node)
    assert.equal(root.activeElement,paragraph)
    paragraph.dispatchEvent(new dom.window.KeyboardEvent('keydown',{key:'s',metaKey:true,bubbles:true,cancelable:true}))
    assert.deepEqual(payload,{action:'save',paragraphs:[{paragraph:1,text:'Hello reader😀'}]})
    document.querySelector('button').click()
    assert.equal(payload.action,'save')
    host.dataset.editing='false'
    await new Promise(r=>setTimeout(r,0))
    assert.equal(root.querySelectorAll('[contenteditable]').length,0)
    assert.equal(root.querySelectorAll('button').length,0)
  } finally {
    dom.window.close()
    for (const [name,value] of previous) {
      if(value) Object.defineProperty(globalThis,name,value)
      else delete globalThis[name]
    }
  }
})
