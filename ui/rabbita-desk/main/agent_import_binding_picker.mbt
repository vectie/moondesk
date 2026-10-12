///|
#cfg(target="js")
extern "js" fn browser_pick_agent_binding() -> @js.Promise =
  #| async () => {
  #|   const input = document.createElement('input');
  #|   input.type = 'file'; input.accept = '.json,application/json'; input.hidden = true;
  #|   document.body.appendChild(input);
  #|   let focusListener;
  #|   try {
  #|     const files = await new Promise(resolve => {
  #|       let settled = false;
  #|       const finish = value => { if (!settled) { settled = true; resolve(value); } };
  #|       input.onchange = () => finish(Array.from(input.files || []));
  #|       input.oncancel = () => finish([]);
  #|       focusListener = () => setTimeout(() => finish(Array.from(input.files || [])), 300);
  #|       window.addEventListener('focus', focusListener, { once: true });
  #|       input.click();
  #|     });
  #|     const file = files[0];
  #|     if (!file) return JSON.stringify({ ok: true, files: [] });
  #|     if (!file.name.endsWith('.json')) throw new Error('Choose the Town binding JSON file received with your package.');
  #|     if (file.size <= 0 || file.size > 128 * 1024) throw new Error('The binding file must be between 1 byte and 128 KiB.');
  #|     const content = await file.text();
  #|     return JSON.stringify({ ok: true, files: [{
  #|       id: `agent-binding:${file.name}:${file.size}:${file.lastModified}`,
  #|       name: file.name, relative_path: '', media_type: 'application/json',
  #|       content, source: 'agent-binding-picker'
  #|     }] });
  #|   } catch (error) {
  #|     return JSON.stringify({ ok: false, files: [], error: String(error?.message || error) });
  #|   } finally {
  #|     if (focusListener) window.removeEventListener('focus', focusListener);
  #|     input.remove();
  #|   }
  #| }
