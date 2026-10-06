///|
/// A file picker reads local bytes only. No network call or workspace path is
/// involved until the user explicitly prepares the local package.
#cfg(target="js")
extern "js" fn browser_pick_accepted_human_result() -> @js.Promise =
  #| async () => {
  #|   const input = document.createElement('input');
  #|   input.type = 'file'; input.accept = '.json,application/json'; input.hidden = true;
  #|   document.body.appendChild(input);
  #|   let focusListener, timer;
  #|   try {
  #|     const files = await new Promise((resolve, reject) => {
  #|       let settled = false;
  #|       const finish = value => { if (!settled) { settled = true; resolve(value); } };
  #|       input.onchange = () => finish(Array.from(input.files || []));
  #|       input.oncancel = () => finish([]);
  #|       focusListener = () => setTimeout(() => finish(Array.from(input.files || [])), 300);
  #|       window.addEventListener('focus', focusListener, { once: true });
  #|       timer = setTimeout(() => { if (!settled) { settled = true; reject(new Error('File selection timed out. Choose the file again.')); } }, 30000);
  #|       input.click();
  #|     });
  #|     const file = files[0];
  #|     if (!file) return JSON.stringify({ ok: true, cancelled: true });
  #|     if (files.length !== 1 || file.size < 1 || file.size > 512 * 1024) throw new Error('Choose one JSON file between 1 byte and 512 KiB.');
  #|     clearTimeout(timer);
  #|     const bytes = new Uint8Array(await Promise.race([file.arrayBuffer(), new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('File reading timed out. Choose the file again.')), 30000); })]));
  #|     if (bytes.length !== file.size || bytes.length > 512 * 1024) throw new Error('The source file changed while reading.');
  #|     let binary = '';
  #|     for (let i = 0; i < bytes.length; i += 8192) binary += String.fromCharCode(...bytes.subarray(i, i + 8192));
  #|     return JSON.stringify({ ok: true, filename: file.name, raw_base64: btoa(binary) });
  #|   } catch (error) {
  #|     return JSON.stringify({ ok: false, error: String(error?.message || error) });
  #|   } finally {
  #|     clearTimeout(timer);
  #|     if (focusListener) window.removeEventListener('focus', focusListener);
  #|     input.remove();
  #|   }
  #| }

///|
/// This is a local preview integrity check, never an authenticity check. The
/// host independently validates the untouched source JSON bytes on Prepare.
#cfg(target="js")
extern "js" fn browser_validate_accepted_human_result(
  raw_base64 : String,
  filename : String,
) -> @js.Promise =
  #| async (rawBase64, filename) => {
  #|   try {
  #|     const exact = (value, keys) => value && typeof value === 'object' && !Array.isArray(value) && Object.keys(value).sort().join('|') === keys.slice().sort().join('|');
  #|     const decode64 = (value, limit) => {
  #|       if (typeof value !== 'string' || value.length > Math.ceil(limit / 3) * 4 || value.length % 4 !== 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(value)) throw new Error('Invalid or oversized canonical base64 content.');
  #|       const binary = atob(value);
  #|       if (binary.length > limit || btoa(binary) !== value) throw new Error('Invalid or oversized canonical base64 content.');
  #|       return Uint8Array.from(binary, c => c.charCodeAt(0));
  #|     };
  #|     const id = value => typeof value === 'string' && value.length >= 1 && value.length <= 128 && /^[A-Za-z0-9_.:-]+$/.test(value) && value !== '.' && value !== '..';
  #|     const sha = value => typeof value === 'string' && /^sha256:[0-9a-f]{64}$/.test(value);
  #|     const record = value => exact(value, ['record_id', 'record_version', 'record_digest']) && id(value.record_id) && typeof value.record_version === 'string' && /^[1-9][0-9]{0,9}$/.test(value.record_version) && Number(value.record_version) <= 2147483647 && sha(value.record_digest);
  #|     const evidence = value => typeof value === 'string' && value.trim().length > 0 && new TextEncoder().encode(value).length <= 4096 && !/[\x00-\x1f\x7f\\]/.test(value) && !value.startsWith('/') && !/^file:/i.test(value) && !/^[A-Za-z]:\//.test(value);
  #|     if (typeof filename !== 'string' || filename.length > 255 || filename.includes('\0')) throw new Error('Invalid source filename.');
  #|     const raw = decode64(rawBase64, 512 * 1024);
  #|     if (!raw.length) throw new Error('The source JSON file is empty.');
  #|     const text = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(raw);
  #|     // Exact schema has 27 object fields. Extra structural colons reveal
  #|     // duplicate keys even though JSON.parse keeps only the final value.
  #|     let colonCount = 0, inString = false, escaped = false;
  #|     for (const char of text) {
  #|       if (inString) {
  #|         if (escaped) escaped = false;
  #|         else if (char === '\\') escaped = true;
  #|         else if (char === '"') inString = false;
  #|       } else if (char === '"') inString = true;
  #|       else if (char === ':') colonCount++;
  #|     }
  #|     if (colonCount !== 27) throw new Error('The source must contain exactly the defined fields without duplicate keys.');
  #|     const source = JSON.parse(text);
  #|     if (!exact(source, ['contract_version', 'source_product', 'provenance_scope', 'authenticity', 'authorizing', 'task', 'report', 'revision', 'content']) || source.contract_version !== 'moonproj.accepted-human-result.v1' || source.source_product !== 'moonproj' || source.provenance_scope !== 'captured_accepted_human_revision' || source.authenticity !== 'unsigned_source_observation' || source.authorizing !== false) throw new Error('Unsupported accepted human result source contract.');
  #|     if (!record(source.task) || !record(source.report)) throw new Error('Invalid captured task or report identity.');
  #|     const revision = source.revision;
  #|     if (!exact(revision, ['revision_id', 'original_run_id', 'session_id', 'original_command_id', 'output_command_id', 'output_evidence_id', 'revision_snapshot_digest']) || typeof revision.revision_id !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(revision.revision_id) || !['original_run_id', 'session_id', 'original_command_id', 'output_command_id'].every(key => id(revision[key])) || !evidence(revision.output_evidence_id) || !sha(revision.revision_snapshot_digest)) throw new Error('Invalid captured revision identity.');
  #|     const content = source.content;
  #|     if (!exact(content, ['encoding', 'media_type', 'size_bytes', 'sha256', 'data']) || content.encoding !== 'base64' || content.media_type !== 'text/plain;charset=utf-8' || !Number.isInteger(content.size_bytes) || content.size_bytes < 0 || content.size_bytes > 256 * 1024 || !sha(content.sha256)) throw new Error('Invalid captured text metadata.');
  #|     const bytes = decode64(content.data, 256 * 1024);
  #|     if (bytes.length !== content.size_bytes || bytes.includes(0)) throw new Error('Captured text size does not match or contains NUL bytes.');
  #|     const contentText = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(bytes);
  #|     if (!globalThis.crypto?.subtle) throw new Error('WebCrypto SHA-256 is required to check this source locally.');
  #|     const digestBytes = new Uint8Array(await globalThis.crypto.subtle.digest('SHA-256', bytes));
  #|     const digest = 'sha256:' + Array.from(digestBytes, b => b.toString(16).padStart(2, '0')).join('');
  #|     if (digest !== content.sha256) throw new Error('Captured text SHA-256 does not match its bytes.');
  #|     const rawDigestBytes = new Uint8Array(await globalThis.crypto.subtle.digest('SHA-256', raw));
  #|     const rawDigest = 'sha256:' + Array.from(rawDigestBytes, b => b.toString(16).padStart(2, '0')).join('');
  #|     return JSON.stringify({ ok: true, source: { filename, raw_base64: rawBase64, raw_size_bytes: raw.length, raw_sha256: rawDigest, task: source.task, report: source.report, revision, content_text: contentText, content_size_bytes: bytes.length, content_sha256: digest } });
  #|   } catch (error) {
  #|     return JSON.stringify({ ok: false, error: String(error?.message || error) });
  #|   }
  #| }

///|
async fn validate_portable_book_human_result(
  raw_base64 : String,
  filename : String,
) -> Result[PortableBookHumanResult, String] noraise {
  let text : String = browser_validate_accepted_human_result(
      raw_base64, filename,
    )
    .wait()
    .cast() catch {
      _ => return Err("Could not check the accepted human result locally.")
    }
  let json = @json.parse(text) catch {
    _ => return Err("Could not read the local source check result.")
  }
  match json {
    { "ok": True, "source": source, .. } => {
      let decoded : PortableBookHumanResult = @json.from_json(source) catch {
        _ => return Err("Could not read the checked source observation.")
      }
      Ok(decoded)
    }
    { "ok": False, "error": String(error), .. } => Err(error)
    _ => Err("Could not check the accepted human result locally.")
  }
}

///|
async fn pick_portable_book_human_result() -> Result[
  PortableBookHumanResult?,
  String,
] noraise {
  let text : String = browser_pick_accepted_human_result().wait().cast() catch {
      _ => return Err("Could not choose an accepted human result file.")
    }
  let json = @json.parse(text) catch {
    _ => return Err("Could not read the file picker response.")
  }
  match json {
    { "ok": True, "cancelled": True, .. } => Ok(None)
    { "ok": True, "filename": String(filename), "raw_base64": String(raw), .. } =>
      match validate_portable_book_human_result(raw, filename) {
        Ok(source) => Ok(Some(source))
        Err(error) => Err(error)
      }
    { "ok": False, "error": String(error), .. } => Err(error)
    _ => Err("Could not read the chosen source file.")
  }
}
