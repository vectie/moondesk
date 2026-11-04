# Work through composed creator stages

MoonDesk's creator builder can now prepare a composed creator one stage at a
time. Use this when you want to inspect a researcher's findings before handing
them to a writer, or correct an intermediate response before continuing.

1. Open **Packs → Agents → Build your specialist** and reopen or create a
   composed specialist. Composition still needs 2–4 saved single-stage
   specialists using the same installed Book version.
2. In **Work through stages**, enter **Task for these stages** (the representative
   example is the initial value). Add any task-only files before starting.
3. Choose **Start stage work**, then **Preview this stage**. The preview contains
   the original task, overall purpose, this source specialist's captured revision,
   its selected references, required handoff and captured task-file contents.
4. Choose **Prepare this stage in chat**. Review the ordinary chat and use
   **Send** yourself. This uses the existing Book validation and unsaved-work
   handling. Preparation does not send, run or record a response.
5. Return to the builder without selecting another saved creator. Paste the
   observed response into **Observed response to hand onward** and choose
   **Record stage response**. Select the next stage and preview it. Its prompt
   includes the original task and previous stage's recorded response.
6. Repeat until **Final recorded output** appears. Copy the output for your work.
   You can select an earlier stage and replace its recorded response; doing so
   clears later responses, so they must be carried through again explicitly.

The ordinary **Try in chat** route still prepares all stages in one conversation.
Stage work gives each prepared conversation only that stage's declared reference
and capability selections. These are preferences, not an isolation boundary or
new permission grant. Existing Book context and runtime permissions still apply.
The handoff text is supplied by the operator and is not a verified runtime receipt
or accepted Book knowledge. Only the immediately previous response is carried;
write handoffs to preserve earlier findings needed by later stages.

## Session scope

The task and each response permit up to 8,000 characters; stage prompts retain
the existing 48,000-character limit. Task files use the existing four-file,
32 KiB each / 64 KiB total bounds and are copied when starting stage work.
Adding/removing task files afterward does not alter an active stage journey.
Close and successful chat preparation preserve recorded stage work in this page.
Clear, switching/revising creators, and reload discard it. Saving a creator saves
its definition only; it does not save these task inputs or responses. Record a
response before selecting another stage or previewing again.

## Grounding and checks

This connects the already delivered composition snapshots and guarded prepare
path into an operator-controlled intermediate-output journey. It follows the
authored MoonDesk PRD's MOONDESK-B03 service-owned execution/review boundary and
MOONDESK-R03 contextual advanced controls, plus the user's create-creators goal.
It does not modify authored requirements or qualify the separate graph-import
workflow. MoonClaw remains the configured assistant runtime.

From the repository root:

```sh
node --test ui/rabbita-desk/specialist-stage-journey.test.mjs ui/rabbita-desk/specialist-builder-dom.test.mjs ui/rabbita-desk/specialist-composition.test.mjs ui/rabbita-desk/specialist-builder.test.mjs ui/rabbita-desk/specialist-stage-replacement.test.mjs
```

The focused controller and mounted-DOM adapter checks cover two-stage handoff,
exact source references, original task preservation, final output, corrected
earlier responses, captured files surviving preparation, and unavailable Book
handling, alongside existing creator/composition behavior. These are source-level
Node tests, not real-browser layout, native-host or provider qualification.

On 20 October 2026 the focused command passed all 74 tests. The broader
`npm run test:specialists` command passed 171 tests and failed the existing
`specialist-history.test.mjs` import harness: it loads the workspace runtime
through a `data:` URL that cannot resolve `./work-journey-runtime.js`.
The same failure was reproduced on the unchanged restored baseline. The full
suite therefore remains failing; it is not a passed release gate.
