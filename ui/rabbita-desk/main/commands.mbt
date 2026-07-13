///|
fn sync_activity_cmd(activity : Activity) -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => browser_set_activity(activity_slug(activity)),
    kind=AfterRender,
  )
}

///|
#cfg(target="js")
extern "js" fn browser_reload_preview() =
  #| () => {
  #|   const frame = document.querySelector('[data-testid="browser-preview-frame"]');
  #|   if (!(frame instanceof HTMLIFrameElement)) return;
  #|   const url = new URL(frame.src, globalThis.location?.href);
  #|   url.searchParams.set('_preview_reload', String(Date.now()));
  #|   frame.src = url.toString();
  #|   const status = document.querySelector('[data-testid="browser-preview-status"]');
  #|   if (status) status.textContent = 'Reloading isolated preview';
  #|   const host = document.querySelector('[data-testid="browser-preview-host"]');
  #|   if (host instanceof HTMLElement) host.dataset.evidenceState = 'not-persisted';
  #| }

///|
fn reload_browser_preview_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => browser_reload_preview(), kind=AfterRender)
}

///|
#cfg(target="js")
extern "js" fn browser_set_preview_viewport(viewport : String) =
  #| (viewport) => {
  #|   const host = document.querySelector('[data-testid="browser-preview-host"]');
  #|   if (!(host instanceof HTMLElement)) return;
  #|   const allowed = new Set(['desktop', 'tablet', 'mobile']);
  #|   host.dataset.viewport = allowed.has(viewport) ? viewport : 'desktop';
  #|   for (const button of host.querySelectorAll('[data-browser-viewport]')) {
  #|     button.setAttribute('aria-pressed', String(button.getAttribute('data-browser-viewport') === host.dataset.viewport));
  #|   }
  #| }

///|
fn set_browser_preview_viewport_cmd(viewport : String) -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => browser_set_preview_viewport(viewport), kind=AfterRender)
}

///|
#cfg(target="js")
extern "js" fn browser_capture_preview_evidence() =
  #| () => {
  #|   const frame = document.querySelector('[data-testid="browser-preview-frame"]');
  #|   const status = document.querySelector('[data-testid="browser-preview-status"]');
  #|   if (!(frame instanceof HTMLIFrameElement) || !frame.contentWindow) {
  #|     if (status) status.textContent = 'Preview is not ready';
  #|     return;
  #|   }
  #|   frame.contentWindow.postMessage({ protocol: 'moondesk-preview-v1', type: 'snapshot-request' }, '*');
  #|   const host = document.querySelector('[data-testid="browser-preview-host"]');
  #|   if (host instanceof HTMLElement) {
  #|     host.dataset.evidenceState = 'prepared';
  #|     host.dataset.evidenceRequestId = globalThis.crypto?.randomUUID?.()
  #|       || `browser-evidence-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  #|   }
  #|   if (status) status.textContent = 'Preparing observations · not persisted';
  #| }

///|
fn capture_browser_preview_evidence_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => browser_capture_preview_evidence(), kind=AfterRender)
}

///|
#cfg(target="js")
extern "js" fn browser_request_host_control(control : String) =
  #| (control) => {
  #|   const allowed = new Set(['pause', 'stop', 'takeover']);
  #|   if (!allowed.has(control)) return;
  #|   const banner = document.querySelector('[data-testid="browser-operation-banner"]');
  #|   if (!(banner instanceof HTMLElement) || banner.dataset.hostAttached !== 'true') {
  #|     const status = document.querySelector('[data-testid="browser-operation-status"]');
  #|     if (status) status.textContent = 'No browser host is attached';
  #|     return;
  #|   }
  #|   globalThis.dispatchEvent(new CustomEvent('moondesk-browser-control', {
  #|     detail: { protocol: 'moondesk-browser-host-v1', control },
  #|   }));
  #|   const status = document.querySelector('[data-testid="browser-operation-status"]');
  #|   if (status) status.textContent = `${control} requested`;
  #| }

///|
fn request_browser_host_control_cmd(control : String) -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => browser_request_host_control(control), kind=AfterRender)
}

///|
#cfg(target="js")
extern "js" fn browser_install_preview_observer() =
  #| () => {
  #|   const attachNativeCapability = () => {
  #|     const nativeCapabilities = globalThis.__lepusaCapabilities;
  #|     const operationBanner = document.querySelector('[data-testid="browser-operation-banner"]');
  #|     if (!(operationBanner instanceof HTMLElement) ||
  #|         nativeCapabilities?.protocol !== 'lepusa-native-capabilities-v1' ||
  #|         nativeCapabilities.frameTargetedBridgeReplies !== true ||
  #|         nativeCapabilities.browserHostRouteAvailable !== true) return;
  #|     operationBanner.dataset.nativeFrameTransport = 'true';
  #|     operationBanner.dataset.browserHostRoute = 'available';
  #|     const operationStatus = document.querySelector('[data-testid="browser-operation-status"]');
  #|     if (operationStatus && operationBanner.dataset.hostAttached !== 'true') {
  #|       operationStatus.textContent = 'Native visible-frame transport available · no agent worker attached';
  #|     }
  #|   };
  #|   attachNativeCapability();
  #|   if (window.__moondeskPreviewObserverInstalled) return;
  #|   window.__moondeskPreviewObserverInstalled = true;
  #|   globalThis.addEventListener('moondesk-browser-host-command', (event) => {
  #|     const detail = event instanceof CustomEvent ? event.detail : null;
  #|     const frame = document.querySelector('[data-testid="browser-preview-frame"]');
  #|     const banner = document.querySelector('[data-testid="browser-operation-banner"]');
  #|     if (!detail || detail.protocol !== 'moondesk-browser-host-v1' ||
  #|         !(frame instanceof HTMLIFrameElement) || !frame.contentWindow ||
  #|         !(banner instanceof HTMLElement) || banner.dataset.browserHostRoute !== 'available') {
  #|       return;
  #|     }
  #|     frame.contentWindow.postMessage({
  #|       protocol: 'moondesk-preview-v1', type: 'host-command', command: detail.command,
  #|     }, '*');
  #|   });
  #|   const acceptedSources = () => new Set(
  #|     Array.from(document.querySelectorAll('[data-testid="browser-preview-frame"]'))
  #|       .map((frame) => frame instanceof HTMLIFrameElement ? frame.contentWindow : null)
  #|       .filter(Boolean)
  #|   );
  #|   window.addEventListener('message', (event) => {
  #|     if (!acceptedSources().has(event.source)) return;
  #|     const data = event.data;
  #|     if (!data || data.protocol !== 'moondesk-preview-v1') return;
  #|     const status = document.querySelector('[data-testid="browser-preview-status"]');
  #|     const consoleOut = document.querySelector('[data-testid="browser-console-output"]');
  #|     const runtimeOut = document.querySelector('[data-testid="browser-runtime-output"]');
  #|     const networkOut = document.querySelector('[data-testid="browser-network-output"]');
  #|     const accessibilityOut = document.querySelector('[data-testid="browser-accessibility-output"]');
  #|     if (data.type === 'ready') {
  #|       if (status) status.textContent = 'Ready · isolated local preview';
  #|     } else if (data.type === 'console' && consoleOut) {
  #|       consoleOut.textContent = `${data.level || 'log'}: ${data.message || ''}`;
  #|     } else if (data.type === 'runtime' && runtimeOut) {
  #|       runtimeOut.textContent = data.message || 'Runtime error';
  #|     } else if (data.type === 'snapshot') {
  #|       const host = document.querySelector('[data-testid="browser-preview-host"]');
  #|       if (host instanceof HTMLElement) host.dataset.evidenceState = 'prepared';
  #|       if (status) status.textContent = 'Evidence request prepared · waiting for host receipt and persistence';
  #|       if (networkOut) networkOut.textContent = (data.resources || []).join('\n') || 'No loaded subresources';
  #|       if (accessibilityOut) accessibilityOut.textContent = data.accessibility || 'No accessibility summary';
  #|       if (runtimeOut && !runtimeOut.textContent) runtimeOut.textContent = 'No runtime errors observed';
  #|       if (consoleOut && !consoleOut.textContent) consoleOut.textContent = 'No console output observed';
  #|       const workspaceId = host instanceof HTMLElement ? host.dataset.workspaceId || '' : '';
  #|       const sourcePath = host instanceof HTMLElement ? host.dataset.sourcePath || '' : '';
  #|       const requestId = host instanceof HTMLElement ? host.dataset.evidenceRequestId || '' : '';
  #|       if (workspaceId && sourcePath && requestId) {
  #|         fetch(`/api/workspaces/${encodeURIComponent(workspaceId)}/browser-evidence`, {
  #|           method: 'POST',
  #|           headers: { 'Content-Type': 'application/json' },
  #|           body: JSON.stringify({
  #|             protocol: 'moondesk-preview-evidence-v1',
  #|             request_id: requestId,
  #|             source_path: sourcePath,
  #|             accessibility: String(data.accessibility || ''),
  #|             resources: Array.isArray(data.resources) ? data.resources.map(String) : [],
  #|             console: consoleOut?.textContent || '',
  #|             runtime: runtimeOut?.textContent || '',
  #|           }),
  #|         }).then(async (response) => {
  #|           const receipt = await response.json().catch(() => ({}));
  #|           if (!response.ok || receipt.status !== 'persisted') {
  #|             throw new Error(receipt.message || `HTTP ${response.status}`);
  #|           }
  #|           globalThis.dispatchEvent(new CustomEvent('moondesk-browser-evidence-status', {
  #|             detail: {
  #|               protocol: 'moondesk-browser-host-v1', state: 'persisted',
  #|               hostReceiptId: receipt.host_receipt_id,
  #|               evidenceRef: receipt.evidence_ref,
  #|             },
  #|           }));
  #|         }).catch((error) => {
  #|           globalThis.dispatchEvent(new CustomEvent('moondesk-browser-evidence-status', {
  #|             detail: {
  #|               protocol: 'moondesk-browser-host-v1', state: 'failed',
  #|               reason: String(error?.message || error || 'persistence failed'),
  #|             },
  #|           }));
  #|         });
  #|       }
  #|     } else if (data.type === 'host-result') {
  #|       globalThis.dispatchEvent(new CustomEvent('moondesk-browser-host-result', {
  #|         detail: {
  #|           protocol: 'moondesk-browser-host-v1',
  #|           ok: data.ok === true,
  #|           receipt: data.receipt || null,
  #|           error: String(data.error || ''),
  #|         },
  #|       }));
  #|       const operationStatus = document.querySelector('[data-testid="browser-operation-status"]');
  #|       if (operationStatus) operationStatus.textContent = data.ok
  #|         ? 'Native browser action completed in visible frame'
  #|         : `Native browser action failed · ${String(data.error || 'unknown error')}`;
  #|       const host = document.querySelector('[data-testid="browser-preview-host"]');
  #|       const nativeResult = data.receipt?.result;
  #|       if (data.ok === true && host instanceof HTMLElement && nativeResult?.screenshot_png_base64) {
  #|         fetch(`/api/workspaces/${encodeURIComponent(host.dataset.workspaceId || '')}/browser-evidence`, {
  #|           method: 'POST',
  #|           headers: { 'Content-Type': 'application/json' },
  #|           body: JSON.stringify({
  #|             protocol: 'moondesk-preview-evidence-v1',
  #|             request_id: `native-${String(nativeResult.request_id || Date.now())}`,
  #|             source_path: host.dataset.sourcePath || '',
  #|             native_host_receipt: data.receipt,
  #|             native_screenshot_png_base64: nativeResult.screenshot_png_base64,
  #|             accessibility: 'Native browser action completed in exact visible frame',
  #|             resources: [],
  #|           }),
  #|         }).then(async (response) => {
  #|           const receipt = await response.json().catch(() => ({}));
  #|           if (!response.ok || receipt.status !== 'persisted' || !receipt.screenshot_ref) {
  #|             throw new Error(receipt.message || `HTTP ${response.status}`);
  #|           }
  #|           globalThis.dispatchEvent(new CustomEvent('moondesk-browser-evidence-status', {
  #|             detail: {
  #|               protocol: 'moondesk-browser-host-v1', state: 'persisted',
  #|               hostReceiptId: receipt.host_receipt_id,
  #|               evidenceRef: receipt.evidence_ref,
  #|             },
  #|           }));
  #|         }).catch((error) => {
  #|           globalThis.dispatchEvent(new CustomEvent('moondesk-browser-evidence-status', {
  #|             detail: {
  #|               protocol: 'moondesk-browser-host-v1', state: 'failed',
  #|               reason: String(error?.message || error || 'native evidence persistence failed'),
  #|             },
  #|           }));
  #|         });
  #|       }
  #|     }
  #|   });
  #|   globalThis.addEventListener('moondesk-browser-evidence-status', (event) => {
  #|     const detail = event instanceof CustomEvent ? event.detail : null;
  #|     if (!detail || detail.protocol !== 'moondesk-browser-host-v1') return;
  #|     const host = document.querySelector('[data-testid="browser-preview-host"]');
  #|     const status = document.querySelector('[data-testid="browser-preview-status"]');
  #|     if (!(host instanceof HTMLElement)) return;
  #|     const persisted = detail.state === 'persisted'
  #|       && typeof detail.hostReceiptId === 'string' && detail.hostReceiptId.length > 0
  #|       && typeof detail.evidenceRef === 'string' && detail.evidenceRef.length > 0;
  #|     if (persisted) {
  #|       host.dataset.evidenceState = 'persisted';
  #|       host.dataset.hostReceiptId = detail.hostReceiptId;
  #|       host.dataset.evidenceRef = detail.evidenceRef;
  #|       if (status) status.textContent = 'Evidence persisted · awaiting Bookkeeper review';
  #|     } else {
  #|       host.dataset.evidenceState = detail.state === 'failed' ? 'failed' : 'prepared';
  #|       delete host.dataset.hostReceiptId;
  #|       delete host.dataset.evidenceRef;
  #|       if (status) status.textContent = detail.state === 'failed'
  #|         ? `Evidence not persisted${detail.reason ? ` · ${detail.reason}` : ''}`
  #|         : 'Evidence request prepared · not persisted';
  #|     }
  #|   });
  #|   globalThis.addEventListener('moondesk-browser-host-status', (event) => {
  #|     const detail = event instanceof CustomEvent ? event.detail : null;
  #|     if (!detail || detail.protocol !== 'moondesk-browser-host-v1') return;
  #|     const banner = document.querySelector('[data-testid="browser-operation-banner"]');
  #|     const status = document.querySelector('[data-testid="browser-operation-status"]');
  #|     if (!(banner instanceof HTMLElement)) return;
  #|     banner.dataset.hostAttached = 'true';
  #|     banner.dataset.operationState = String(detail.state || 'unknown');
  #|     if (detail.state === 'restarted' || detail.state === 'disconnected') {
  #|       const previewHost = document.querySelector('[data-testid="browser-preview-host"]');
  #|       const previewStatus = document.querySelector('[data-testid="browser-preview-status"]');
  #|       if (previewHost instanceof HTMLElement) {
  #|         previewHost.dataset.evidenceState = 'not-persisted';
  #|         delete previewHost.dataset.hostReceiptId;
  #|         delete previewHost.dataset.evidenceRef;
  #|       }
  #|       if (previewStatus) previewStatus.textContent = 'Host restarted · evidence is not persisted';
  #|     }
  #|     if (status) status.textContent = String(detail.label || detail.state || 'Browser host attached');
  #|     for (const button of banner.querySelectorAll('button[data-browser-control]')) {
  #|       if (button instanceof HTMLButtonElement) button.disabled = false;
  #|     }
  #|   });
  #| }

///|
fn install_browser_preview_observer_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => browser_install_preview_observer(), kind=AfterRender)
}

///|
fn sync_shell_cmd(mode : WorkspaceMode, activity : Activity) -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => {
      browser_set_activity(
        if mode == Desk {
          "desk"
        } else if mode == MoonCode {
          "code"
        } else if mode == MoonFlow {
          "flow"
        } else {
          activity_slug(activity)
        },
      )
    },
    kind=AfterRender,
  )
}

///|
fn sync_activity_batch(activity : Activity, cmd : @rabbita.Cmd) -> @rabbita.Cmd {
  @rabbita.batch([cmd, sync_activity_cmd(activity)])
}

///|
fn sync_workspace_context_cmd(
  workspace_id : String,
  path : String,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => browser_set_workspace_context(workspace_id, path),
    kind=AfterRender,
  )
}

///|
fn sync_workspace_context_batch(
  workspace_id : String,
  path : String,
  cmd : @rabbita.Cmd,
) -> @rabbita.Cmd {
  @rabbita.batch([cmd, sync_workspace_context_cmd(workspace_id, path)])
}

///|
fn sync_mooncode_context_cmd(
  workspace_id : String,
  session_id : String,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => browser_set_mooncode_context(workspace_id, session_id),
    kind=AfterRender,
  )
}

///|
#cfg(target="js")
extern "js" fn browser_clear_mooncode_composer() =
  #| () => {
  #|   const input = document.querySelector('[data-testid="mooncode-input"]');
  #|   if (input instanceof HTMLTextAreaElement) input.value = "";
  #| }

///|
fn clear_mooncode_composer_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => browser_clear_mooncode_composer(), kind=AfterRender)
}

///|
fn sync_shell_batch(
  mode : WorkspaceMode,
  activity : Activity,
  cmd : @rabbita.Cmd,
) -> @rabbita.Cmd {
  @rabbita.batch([cmd, sync_shell_cmd(mode, activity)])
}

///|
#cfg(target="js")
extern "js" fn send_browser_notification(title : String, body : String) =
  #| (title, body) => {
  #|   if (!("Notification" in window)) return;
  #|   const show = () => new Notification(title, { body });
  #|   if (Notification.permission === "granted") {
  #|     show();
  #|   } else if (Notification.permission !== "denied") {
  #|     Notification.requestPermission().then(permission => {
  #|       if (permission === "granted") show();
  #|     });
  #|   }
  #| }

///|
#cfg(target="js")
extern "js" fn browser_install_desk_location_enter() =
  #| () => {
  #|   if (window.__moondeskDeskLocationEnterInstalled) return;
  #|   window.__moondeskDeskLocationEnterInstalled = true;
  #|   document.addEventListener("keydown", (event) => {
  #|     if (event.key !== "Enter") return;
  #|     const target = event.target;
  #|     if (!(target instanceof HTMLElement)) return;
  #|     if (target.dataset?.testid !== "desk-location-input") return;
  #|     event.preventDefault();
  #|     event.stopPropagation();
  #|     document.querySelector('[data-testid="desk-location-go"]')?.click();
  #|   }, true);
  #| }

///|
fn install_desk_location_enter_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => browser_install_desk_location_enter(), kind=AfterRender)
}

///|
#cfg(target="js")
extern "js" fn browser_install_mooncode_enter_send() =
  #| () => {
  #|   if (window.__moondeskMoonCodeEnterSendInstalled) return;
  #|   window.__moondeskMoonCodeEnterSendInstalled = true;
  #|   document.addEventListener("keydown", (event) => {
  #|     if (event.key !== "Enter" || event.shiftKey) return;
  #|     const target = event.target;
  #|     if (!(target instanceof HTMLElement)) return;
  #|     if (target.dataset?.testid !== "mooncode-input") return;
  #|     event.preventDefault();
  #|     event.stopPropagation();
  #|     document.querySelector('[data-testid="mooncode-send"]')?.click();
  #|   }, true);
  #| }

///|
fn install_mooncode_enter_send_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => browser_install_mooncode_enter_send(), kind=AfterRender)
}

///|
#cfg(target="js")
extern "js" fn browser_install_mooncode_disclosures() =
  #| () => {
  #|   if (window.__moondeskMoonCodeDisclosuresInstalled) return;
  #|   window.__moondeskMoonCodeDisclosuresInstalled = true;
  #|   const sync = (summary) => {
  #|     if (!(summary instanceof HTMLElement)) return;
  #|     const details = summary.closest("details");
  #|     if (!(details instanceof HTMLDetailsElement)) return;
  #|     summary.setAttribute("aria-expanded", details.open ? "true" : "false");
  #|   };
  #|   const syncAll = () => {
  #|     document.querySelectorAll(".mooncode-activity-summary").forEach(sync);
  #|   };
  #|   document.addEventListener("keydown", (event) => {
  #|     if (event.key !== "Enter" && event.key !== " ") return;
  #|     const summary = event.target instanceof Element
  #|       ? event.target.closest(".mooncode-activity-summary")
  #|       : null;
  #|     if (!(summary instanceof HTMLElement)) return;
  #|     const details = summary.closest("details");
  #|     if (!(details instanceof HTMLDetailsElement)) return;
  #|     event.preventDefault();
  #|     details.open = !details.open;
  #|     sync(summary);
  #|   }, true);
  #|   document.addEventListener("click", (event) => {
  #|     const summary = event.target instanceof Element
  #|       ? event.target.closest(".mooncode-activity-summary")
  #|       : null;
  #|     if (summary) queueMicrotask(() => sync(summary));
  #|   }, true);
  #|   new MutationObserver(syncAll).observe(document.body, {
  #|     childList: true,
  #|     subtree: true,
  #|   });
  #|   syncAll();
  #| }

///|
fn install_mooncode_disclosures_cmd() -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => browser_install_mooncode_disclosures(), kind=AfterRender)
}

///|
#cfg(target="js")
extern "js" fn browser_copy_text_to_clipboard(text : String) =
  #| (text) => {
  #|   const fallback = () => {
  #|     const area = document.createElement("textarea");
  #|     area.value = text;
  #|     area.setAttribute("readonly", "");
  #|     area.style.position = "fixed";
  #|     area.style.left = "-9999px";
  #|     document.body.appendChild(area);
  #|     area.select();
  #|     try {
  #|       document.execCommand("copy");
  #|     } finally {
  #|       area.remove();
  #|     }
  #|   };
  #|   if (navigator.clipboard?.writeText) {
  #|     navigator.clipboard.writeText(text).catch(fallback);
  #|   } else {
  #|     fallback();
  #|   }
  #| }

///|
#cfg(not(target="js"))
fn browser_copy_text_to_clipboard(_text : String) -> Unit {
  ()
}

///|
fn copy_text_to_clipboard_cmd(text : String) -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => browser_copy_text_to_clipboard(text), kind=AfterRender)
}

///|
#cfg(target="js")
extern "js" fn browser_pick_import_files() -> @js.Promise =
  #| async () => {
  #|   const readFile = async (file, source) => {
  #|     const textLike =
  #|       file.type.startsWith("text/") ||
  #|       /\.(md|txt|json|mbt|js|ts|tsx|jsx|css|html|xml|yaml|yml|toml|csv)$/i.test(file.name);
  #|     const content = textLike
  #|       ? await file.text()
  #|       : await new Promise((resolve, reject) => {
  #|           const reader = new FileReader();
  #|           reader.onerror = () => reject(reader.error ?? new Error("Failed to read file"));
  #|           reader.onload = () => resolve(String(reader.result ?? ""));
  #|           reader.readAsDataURL(file);
  #|         });
  #|     return {
  #|       id: `${source}:${file.webkitRelativePath || file.name}:${file.size}:${file.lastModified}`,
  #|       name: file.name || "pasted-file",
  #|       relative_path: file.webkitRelativePath || "",
  #|       media_type: file.type || "application/octet-stream",
  #|       content,
  #|       source,
  #|     };
  #|   };
  #|   try {
  #|     const input = document.createElement("input");
  #|     input.type = "file";
  #|     input.multiple = true;
  #|     const files = await new Promise((resolve) => {
  #|       input.onchange = () => resolve(Array.from(input.files || []));
  #|       input.click();
  #|     });
  #|     const loaded = await Promise.all(files.map((file) => readFile(file, "picker")));
  #|     return JSON.stringify({ ok: true, files: loaded });
  #|   } catch (error) {
  #|     return JSON.stringify({ ok: false, files: [], error: String(error) });
  #|   }
  #| }

///|
#cfg(target="js")
extern "js" fn browser_pick_import_folder() -> @js.Promise =
  #| async () => {
  #|   const readFile = async (file, source) => {
  #|     const textLike =
  #|       file.type.startsWith("text/") ||
  #|       /\.(md|txt|json|mbt|js|ts|tsx|jsx|css|html|xml|yaml|yml|toml|csv)$/i.test(file.name);
  #|     const content = textLike
  #|       ? await file.text()
  #|       : await new Promise((resolve, reject) => {
  #|           const reader = new FileReader();
  #|           reader.onerror = () => reject(reader.error ?? new Error("Failed to read file"));
  #|           reader.onload = () => resolve(String(reader.result ?? ""));
  #|           reader.readAsDataURL(file);
  #|         });
  #|     return {
  #|       id: `${source}:${file.webkitRelativePath || file.name}:${file.size}:${file.lastModified}`,
  #|       name: file.name || "pasted-file",
  #|       relative_path: file.webkitRelativePath || "",
  #|       media_type: file.type || "application/octet-stream",
  #|       content,
  #|       source,
  #|     };
  #|   };
  #|   try {
  #|     const input = document.createElement("input");
  #|     input.type = "file";
  #|     input.multiple = true;
  #|     input.webkitdirectory = true;
  #|     input.setAttribute("webkitdirectory", "");
  #|     const files = await new Promise((resolve) => {
  #|       input.onchange = () => resolve(Array.from(input.files || []));
  #|       input.click();
  #|     });
  #|     const loaded = await Promise.all(files.map((file) => readFile(file, "folder-picker")));
  #|     return JSON.stringify({ ok: true, files: loaded });
  #|   } catch (error) {
  #|     return JSON.stringify({ ok: false, files: [], error: String(error) });
  #|   }
  #| }

///|
#cfg(target="js")
extern "js" fn browser_pick_moonbook_archive() -> @js.Promise =
  #| async () => {
  #|   const readFile = async (file) => {
  #|     const content = await new Promise((resolve, reject) => {
  #|       const reader = new FileReader();
  #|       reader.onerror = () => reject(reader.error ?? new Error("Failed to read archive"));
  #|       reader.onload = () => resolve(String(reader.result ?? ""));
  #|       reader.readAsDataURL(file);
  #|     });
  #|     return {
  #|       id: `moonbook-archive:${file.name}:${file.size}:${file.lastModified}`,
  #|       name: file.name || "moonbook.zip",
  #|       relative_path: "",
  #|       media_type: file.type || "application/zip",
  #|       content,
  #|       source: "moonbook-archive-picker",
  #|     };
  #|   };
  #|   try {
  #|     const input = document.createElement("input");
  #|     input.type = "file";
  #|     input.accept = ".zip,application/zip,application/x-zip-compressed";
  #|     const files = await new Promise((resolve) => {
  #|       input.onchange = () => resolve(Array.from(input.files || []));
  #|       input.click();
  #|     });
  #|     const file = files[0];
  #|     const loaded = file ? [await readFile(file)] : [];
  #|     return JSON.stringify({ ok: true, files: loaded });
  #|   } catch (error) {
  #|     return JSON.stringify({ ok: false, files: [], error: String(error) });
  #|   }
  #| }

///|
#cfg(target="js")
extern "js" fn browser_take_dropped_import_files() -> String =
  #| () => {
  #|   const state =
  #|     (window.__moondeskImportState ||= { installed: false, queue: [] });
  #|   const readFile = async (file, source) => {
  #|     const textLike =
  #|       file.type.startsWith("text/") ||
  #|       /\.(md|txt|json|mbt|js|ts|tsx|jsx|css|html|xml|yaml|yml|toml|csv)$/i.test(file.name);
  #|     const content = textLike
  #|       ? await file.text()
  #|       : await new Promise((resolve, reject) => {
  #|           const reader = new FileReader();
  #|           reader.onerror = () => reject(reader.error ?? new Error("Failed to read local file"));
  #|           reader.onload = () => resolve(String(reader.result ?? ""));
  #|           reader.readAsDataURL(file);
  #|         });
  #|     return {
  #|       id: `${source}:${file.webkitRelativePath || file.name}:${file.size}:${file.lastModified}`,
  #|       name: file.name || `${source}-image-${Date.now()}.png`,
  #|       relative_path: file.webkitRelativePath || "",
  #|       media_type: file.type || "application/octet-stream",
  #|       content,
  #|       source,
  #|     };
  #|   };
  #|   if (!state.installed) {
  #|     const stop = (event) => {
  #|       event.preventDefault();
  #|       event.stopPropagation();
  #|     };
  #|     window.addEventListener("dragover", stop);
  #|     window.addEventListener("drop", (event) => {
  #|       stop(event);
  #|       const files = Array.from(event.dataTransfer?.files || []);
  #|       Promise.all(files.map((file) => readFile(file, "drop")))
  #|         .then((loaded) => state.queue.push(...loaded))
  #|         .catch((error) => state.queue.push({
  #|           id: `drop-error:${Date.now()}`,
  #|           name: "drop-error.txt",
  #|           media_type: "text/plain",
  #|           content: String(error),
  #|           source: "drop",
  #|         }));
  #|     });
  #|     window.addEventListener("paste", (event) => {
  #|       const files = Array.from(event.clipboardData?.files || []);
  #|       if (files.length === 0) return;
  #|       Promise.all(files.map((file) => readFile(file, "paste")))
  #|         .then((loaded) => state.queue.push(...loaded))
  #|         .catch((error) => state.queue.push({
  #|           id: `paste-error:${Date.now()}`,
  #|           name: "paste-error.txt",
  #|           media_type: "text/plain",
  #|           content: String(error),
  #|           source: "paste",
  #|         }));
  #|     });
  #|     state.installed = true;
  #|   }
  #|   const files = state.queue.splice(0, state.queue.length);
  #|   return JSON.stringify({ ok: true, files });
  #| }

///|
fn notify_cmd(title : String, body : String) -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => send_browser_notification(title, body), kind=AfterRender)
}

///|
fn parse_browser_import_batch(
  text : String,
) -> Result[Array[LocalImportFile], String] {
  if text.trim().to_owned() == "" {
    return Ok([])
  }
  let json = @json.parse(text) catch {
    error => return Err("Failed to parse local import wrapper: \{error}")
  }
  let payload : BrowserLocalImportBatch = @json.from_json(json) catch {
    error => return Err("Failed to parse local import batch: \{error}")
  }
  match payload.error {
    Some(error) => Err(error)
    None =>
      if payload.ok {
        Ok(payload.files)
      } else {
        Err("Local file import failed")
      }
  }
}

///|
fn pick_import_files_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @rabbita.perform(fn(result) { dispatch(LocalFilesPicked(result)) }, async fn() noraise {
    let text : String = browser_pick_import_files().wait().cast() catch {
        error => return Err("Failed to read local files: \{error}")
      }
    parse_browser_import_batch(text)
  })
}

///|
fn pick_import_folder_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @rabbita.perform(fn(result) { dispatch(LocalFilesPicked(result)) }, async fn() noraise {
    let text : String = browser_pick_import_folder().wait().cast() catch {
        error => return Err("Failed to read local folder: \{error}")
      }
    parse_browser_import_batch(text)
  })
}

///|
fn pick_moonbook_folder_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @rabbita.perform(fn(result) { dispatch(LocalMoonBookFolderPicked(result)) }, async fn() noraise {
    let text : String = browser_pick_import_folder().wait().cast() catch {
        error => return Err("Failed to read MoonBook folder: \{error}")
      }
    parse_browser_import_batch(text)
  })
}

///|
fn pick_moonbook_archive_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @rabbita.perform(
    fn(result) { dispatch(LocalMoonBookArchivePicked(result)) },
    async fn() noraise {
      let text : String = browser_pick_moonbook_archive().wait().cast() catch {
          error => return Err("Failed to read MoonBook archive: \{error}")
        }
      match parse_browser_import_batch(text) {
        Ok(files) =>
          if files.length() == 0 {
            Err("No archive selected")
          } else {
            Ok(files[0])
          }
        Err(error) => Err(error)
      }
    },
  )
}

///|
fn take_dropped_imports_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @rabbita.perform(fn(result) { dispatch(LocalFilesPicked(result)) }, fn() noraise {
    parse_browser_import_batch(browser_take_dropped_import_files())
  })
}

///|
fn schedule_import_drop_poll(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @rabbita.delay(dispatch(PollDroppedImports), 1200)
}
