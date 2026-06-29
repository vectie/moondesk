///|
fn sync_activity_cmd(activity : Activity) -> @rabbita.Cmd {
  @cmd.raw_effect(
    _ => browser_set_activity(activity_slug(activity)),
    kind=@cmd.after_render,
  )
}

///|
fn sync_activity_batch(activity : Activity, cmd : @rabbita.Cmd) -> @rabbita.Cmd {
  @rabbita.batch([cmd, sync_activity_cmd(activity)])
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
  #|       id: `${source}:${file.name}:${file.size}:${file.lastModified}`,
  #|       name: file.name || "pasted-file",
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
  #|     return JSON.stringify({ ok: true, files: loaded, error: null });
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
  #|       id: `${source}:${file.name}:${file.size}:${file.lastModified}`,
  #|       name: file.name || `${source}-image-${Date.now()}.png`,
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
  #|   return JSON.stringify({ ok: true, files, error: null });
  #| }

///|
fn notify_cmd(title : String, body : String) -> @rabbita.Cmd {
  @cmd.raw_effect(
    _ => send_browser_notification(title, body),
    kind=@cmd.after_render,
  )
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
fn take_dropped_imports_cmd(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @rabbita.perform(fn(result) { dispatch(LocalFilesPicked(result)) }, fn() noraise {
    parse_browser_import_batch(browser_take_dropped_import_files())
  })
}

///|
fn schedule_import_drop_poll(dispatch : Dispatch[Msg]) -> @rabbita.Cmd {
  @rabbita.delay(dispatch(PollDroppedImports), 1200)
}
