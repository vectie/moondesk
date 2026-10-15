# Terminal, voice, screen context and suggested next steps

Implemented October 13, 2026 as part of the [product feature program](PRODUCT_FEATURE_PROGRAM_2026-10-13.md).

## Interactive terminal

Open **Code → Terminal → New terminal** in a selected Book. The default directory is the Book root. Enter a relative folder before opening another terminal to work in a subfolder or a worktree stored inside the Book.

Each tab is a real native pseudo-terminal running the user's interactive login shell. It supports interactive CLIs, REPLs, builds and development servers. The terminal is usable even when the coding agent is not installed.

- Rename tabs to distinguish a server, build and scratch shell.
- **Interrupt** sends Ctrl+C to the foreground command.
- **Close terminal** ends that shell and signals its foreground command.
- Search output with the search field; Enter finds the next occurrence and Shift+Enter finds the previous one. Ctrl/Cmd+F focuses search.
- Select output and choose **Ask about selection** to add it to the conversation's context tray. It does not send a message.
- Arrow keys, Home and End navigate the terminal tab list.
- Resizing the terminal updates the native PTY dimensions.
- **Agent command history** remains available separately below the interactive terminal.

Shells continue while switching Books or views. Reloading the browser reconnects to existing shells and replays retained output. Sessions last for the desktop backend's process lifetime; restarting that backend ends them. Each native session retains the latest 2 MiB of output and the terminal display keeps 10,000 scrollback lines. A reconnect explicitly indicates when older output has been discarded.

The native implementation targets macOS/Linux. It uses C `forkpty` and a background reader, with MoonBit session ownership and HTTP handlers. No Rust or shell subprocess emulation is used.

### Integration

- `internal/terminal/`: native PTY bindings, process lifecycle and retained output.
- `internal/moonwiki/workspace_terminal_handlers.mbt`: Book-scoped session registry and HTTP actions.
- `GET /api/workspaces/:book/terminals`: list sessions.
- `POST /api/workspaces/:book/terminals`: start a session with `directory`, `columns`, `rows` and optional `title`.
- `GET /api/workspaces/:book/terminals/:id?after=…`: retained output as base64, `start`/`next` byte positions, and shell status.
- `POST /api/workspaces/:book/terminals/:id`: `input`, `resize`, `interrupt`, `rename` or `close` action.
- Byte offsets are decimal strings in JSON, backed by native 64-bit counters.
- `ui/rabbita-desk/mooncode-terminal-runtime.js`: xterm display, tabs, search, reconnect and context selection.

## Voice and screen context

Expand **Voice & screen** beneath the Code composer.

**Dictate** listens to one phrase and adds recognized text to the existing draft for review. It never sends the draft automatically. **Voice turns** is an explicit conversational mode: each recognized phrase is sent as a normal chat turn, the completed answer is read aloud, and listening resumes. Starting voice turns requires an empty draft so an existing unfinished message is not sent accidentally. **End voice turns** and **Stop speaking** stop the loop.

**Read answer** speaks the latest answer. The spoken-language selector configures browser recognition and synthesis. Availability depends on the browser and its speech services.

### Provider realtime voice

Expand **Provider realtime voice**, choose a realtime model (default `gpt-realtime`), and press **Start provider voice**. This uses the selected chat provider's existing configuration. The provider must implement the OpenAI-compatible Realtime client-secret and WebRTC calls endpoints. MoonClaw creates a short-lived session credential; the regular provider API key stays in MoonClaw.

The connection carries actual microphone audio and provider audio through WebRTC. **Mute**, **Interrupt voice**, **End provider voice**, and the audio playback control remain available. Provider speech transcripts appear in the panel. **Transcript to draft** lets users review and save the conversation as a normal chat turn; the voice transcript itself is transient.

The provider receives a `send_coding_request` function. Repository changes and investigation requests enter the existing Code composer/send workflow, preserving the ordinary task timeline and results. An existing draft or active voice-initiated task prevents another automatic coding send. Completed task results are supplied back to the spoken conversation. Changing chats, leaving Code, or ending voice closes microphone tracks and the peer connection, including permission requests that resolve after navigation.

Routes: MoonDesk `POST /api/mooncode/workspaces/:book/realtime-session` forwards Book scope and the selected model to MoonClaw `POST /v1/mooncode/realtime-session`. MoonClaw returns an ephemeral credential, expiry, realtime model, and provider calls endpoint. The browser exchanges SDP with that calls endpoint and communicates over the `oai-events` channel. This follows the [official WebRTC flow](https://developers.openai.com/api/docs/guides/voice-webrtc) and [Realtime function-call contract](https://developers.openai.com/api/docs/guides/realtime-conversations).

**Share screen** and **Camera** open the normal browser permission/selection flow and show a live preview. **Attach this frame** captures a still image into the existing durable Code image tray. Only frames the user attaches are included in a message; the live stream itself is not sent to the model. Attach several frames to discuss a sequence or interaction. Existing image model compatibility and per-turn attachment behavior continue to apply.

**Stop capture** stops all tracks. Switching Books/chats or leaving Code stops active capture and voice. The collapsed disclosure continues to indicate active listening, screen sharing or camera use. The expanded body scrolls within 45% of the viewport height to keep the draft reachable on short displays.

`mooncode-media-tools-runtime.js` emits `moondesk:code-images` with File objects. The existing MoonBit image-intake bridge consumes them, so captures follow the same persistence and replay path as picked images.

## Suggested next steps

When a conversation has enough context, suggestions appear above the draft. They are explicit contextual shortcuts derived from the latest answer/question, latest command failure, interrupted request and selected source file. They are not represented as model predictions.

Selecting a suggestion appends an editable draft and never sends it. Suggestions, dismissed items and the Show/Hide choice persist per Book and chat in this browser. Suggestions do not reshuffle while an answer is streaming. Empty conversations do not invent work.

## Verification and limits

Focused native test:

```text
moon test internal/terminal --target native --strip
```

Verified a real TTY, initial and changed terminal dimensions, UTF-8 output, Ctrl+C interrupting a sleeping command, retained-output replay, natural shell exit code 7 and repeated close.

Focused browser-state/model tests:

```text
node --test ui/rabbita-desk/mooncode-media-tools-runtime.test.mjs ui/rabbita-desk/mooncode-realtime-client.test.mjs ui/rabbita-desk/mooncode-suggestions-model.test.mjs
```

Thirteen tests cover draft preservation, explicit voice send/wait/speak/listen sequencing, speech cancellation, capture permission completing after navigation, clearing transient voice transcripts on chat changes, empty-conversation behavior, contextual suggestions, SDP/ephemeral-key negotiation, mute/interruption, transcript events, exactly-once coding-tool forwarding, provider failure cleanup and late microphone permission cleanup. Media and WebRTC tests use mocked browser services; they do not establish hardware or external speech-provider availability. MoonClaw separately exercises client-secret creation against a local provider fixture. No paid provider call was made.

The integrated preview was exercised through the browser on October 13:

- Created a terminal in the isolated Coding-demo Book.
- Typed and executed a command that printed `__MOONDESK_PTY_OK__`, confirmed `test -t 0`, and displayed the expected Book directory.
- Searched the output and added the selected match to the conversation context tray.
- Reloaded the page and verified the same session and retained output returned.
- Closed the test shell through the terminal UI.
- Expanded and visually inspected the media controls without granting microphone/camera/screen permissions.

The first 375 × 740 viewport checks found click-routing, composer clipping and focus-restoration issues. The workbench owner corrected these and produced the 59.53-second build. After the user unlocked the Mac, the final browser recheck passed: **Focus chat** reveals the composer, natural scrolling exposes all draft and expanded media controls, and the page has no horizontal overflow (375px document width at a 375px viewport). Exact draft text and chat focus survive reload. **Split view** returns to the work pane; returning to chat retains the draft. Keyboard Tab reaches the next enabled composer control. The viewport override was reset after verification. Terminal/media controls use wrapping layouts and 44px minimum mobile tap targets. Actual camera/microphone capture, external speech recognition and live provider realtime audio were not exercised. Continuous model video is not implemented; screen/camera context uses selected still frames.
