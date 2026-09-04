# OWB second-round feature comparison

Status: feature strategy and implementation recommendation

Compared: 2026-09-04

## Scope

This is the second feature comparison between MoonDesk/MoonBook and the local
Open WebUI (`../owb`) checkout. It deliberately evaluates complete user
workflows rather than hardening work. RBAC, SSO, storage engines, telemetry,
deployment topology, stricter validation, and similar operational controls are
outside this comparison.

The comparison baseline was:

- MoonDesk `main` at `153c8060`, clean and synchronized with `github/main`;
- OWB `main` at `2a960a59f`, clean and synchronized with `origin/main`, with
  the `0.11.3` changelog at its head;
- MoonBook `main` at `b4ae568` plus a substantial local working tree containing
  the portable-agent and evolution implementation. Those MoonBook changes are
  counted as local capability, not as a released or remotely committed feature.

Primary evidence:

- `../owb/README.md`, especially Models and Agents, Notes, Channels, Memory,
  Calendar, Automations, Artifacts, retrieval, image generation, and multi-model
  conversations;
- `../owb/CHANGELOG.md`, especially the `0.11.0`–`0.11.3` user workflows;
- `PRODUCT_CONTRACT.md`, `WORKSPACE_FEATURES.md`, and
  `AGENT_WORKSPACE_EVOLUTION.md` in this repository;
- `../moonbook/docs/PORTABLE_EVOLVING_AGENT.md` and the local
  `../moonbook/agent/` package.

## Product conclusion

MoonDesk no longer has a basic chat-and-document gap. It already provides
document-bound conversations, exact source and artifact references, queued
follow-ups, workspace context, Office selection actions, proposed changes,
history, checks, review threads, preferences, background work, and evidence
export.

The next product leap is:

> Move from “an agent helps with this document” to “a reusable MoonBook agent
> can perform, learn, collaborate, and deliver complete workflows.”

MoonDesk remains the normal human interface. MoonBook is the portable agent and
durable work product. MoonClaw animates it. Bookkeeper governs learning.
MoonTown owns time. MoonFlow owns collaboration. MoonFort and MoonGate support
experiments and comparisons without becoming user-facing concepts.

## Existing feature baseline

The following OWB-inspired capabilities are already substantially covered and
should not be rebuilt under new names:

| User need | Current MoonDesk/MoonBook capability |
| --- | --- |
| Resume work on a document | Durable, renameable, archivable document conversations |
| Continue writing while the agent works | Editable follow-up tray with reorder and send-now |
| Attach existing work | Find & Add, `@file`, drag/drop, prior conversations, artifacts, Inbox items, and URLs |
| Navigate evidence | Typed page, slide, sheet/range, section, anchor, and artifact references |
| Improve Office documents | Selection actions, proposed changes, semantic before/after review, apply, and reject |
| Keep user conventions | Global and workspace preferences/glossary records |
| Run recurring background work | Natural-language automation proposals, MoonTown standing goals, receipts, and manual run |
| Compare implementations | MoonCode fork-and-compare with a shared baseline and explicit selection |
| Export completed work | Work Package export and portable MoonBook agent bundle contracts |

This baseline means that another generic chat sidebar, upload dialog, memory
list, or tool transcript would add surface area without creating a new user
outcome.

## Feature comparison and opportunities

| Priority | OWB workflow | MoonSuite today | Recommended feature enhancement |
| --- | --- | --- | --- |
| P0 | Models/agents and imported presets | MoonBook can locally pack, inspect, diff, import, upgrade, and roll back a `.moonbook-agent`, but MoonDesk has no user-facing agent flow | **Agent Library and Agent Passport** |
| P0 | Chat variables collect reusable inputs | MoonDesk can show pack templates, but current owner integrations stop at preview rather than input confirmation, instance creation, and launch | **Reusable task recipes with generated brief forms** |
| P0 | Persistent memory and explicit skill management | Preferences exist and Bookkeeper has a governed evolution lifecycle, but ordinary corrections do not become a visible learning workflow | **Teach this book and Learning Review** |
| P0 | Calendar, automations, timers, and linked generated chats | MoonDesk has cadence/tick records, automation cards, notifications, and ICS export, but no human agenda joining future work to results | **Work Agenda** |
| P1 | Channels, shared folders, threads, mentions, reactions, pins, and sharing | Anchored reviews are durable locally and pack collaboration is read-only; live cross-device collaboration remains a MoonFlow seam | **Book Review Rooms** |
| P1 | Chat forking, branch maps, and multi-model answers | Comparison is intentionally confined to MoonCode and is implementation-oriented | **Try another version for normal document work** |
| P1 | Persistent interactive artifact storage | MoonDesk opens generated files and hosts pack applications, but does not offer an easy user-created living artifact workflow | **Living artifacts** |
| P1 | Voice/video, image generation, and media extraction | Workspace files and Office documents are supported; capture, transcription, visual editing, and contextual media insertion are not a complete flow | **Multimodal document work** |
| P2 | Cloud file pickers and continuously synchronized knowledge sources | MoonDesk imports local files/URLs and can create standing website watches, but lacks reusable connected-source subscriptions | **Subscribed sources** |
| P2 | Public chat links and community agent imports | MoonDesk exports a static Work Package and MoonBook has a portable agent artifact, but neither is yet a normal sharing journey | **Send for review and Share agent** |

## P0 feature definitions

### 1. Agent Library and Agent Passport

The existing Packs home is the correct discovery location. Add an **Agents**
section beside applications and templates; do not add it to the document chat.

An Agent Passport should show:

- the outcome the agent helps produce;
- example tasks and example deliverables;
- accepted knowledge domains and source expectations;
- capabilities expressed in user language;
- supported document types and applications;
- standing work the agent can perform;
- current version, recent changes, and available update;
- evaluation summaries and known limitations;
- the MoonBook that will be created or updated.

Primary journey:

```text
Packs home
  -> browse/search agents
  -> open Agent Passport
  -> try an example or choose Use agent
  -> complete a short brief
  -> create/open MoonBook
  -> receive the first document or result in the normal chat-and-viewer UI
```

Existing MoonBook commands become product operations behind the interface:
inspect before install, diff before update, and rollback from version history.
Users should never need to know those command names.

Ownership:

- MoonBook: passport data, bundle lifecycle, version history, and durable agent;
- MoonDesk: discovery, preview, install/update/rollback presentation;
- MoonGate: optional evaluation summaries;
- MoonClaw: first-run conversation and task execution.

### 2. Reusable task recipes

OWB chat variables demonstrate that an agent workflow often needs a small,
repeatable set of inputs. MoonSuite should express this through owner-defined
schemas rather than prompt variables.

Examples:

- Prepare a board report: period, audience, source set, tone, and output;
- Review a contract: jurisdiction, review goal, risk focus, and deadline;
- Track a research topic: sources, cadence, material-change rule, and output;
- Produce a presentation: audience, duration, brand source, and slide count.

The recipe appears as a compact form generated from the owning pack or
MoonBook schema. Chat may infer fields from the current document and ask only
for missing material decisions. Confirmation creates a durable template
instance and starts the owner workflow.

This closes the currently documented gap where MoonTown and MoonFind templates
stop at **Review in owner** and do not persist a template instance or launch the
workflow.

Primary journey:

```text
choose agent or template
  -> select a recipe
  -> review inferred inputs
  -> answer missing fields in one decision card
  -> confirm
  -> owner creates the instance
  -> work opens in the existing document conversation
```

### 3. Teach this book and Learning Review

MoonBook should improve through normal user feedback rather than making people
edit raw prompts or skill files.

Message and document-change actions gain **Remember this** and
**Teach this book**. The resulting card explains which kind of change is being
proposed:

- preference: terminology, tone, names, or formatting convention;
- knowledge: an accepted fact with its source and scope;
- procedure: a repeatable method learned from a correction;
- capability: a versioned behavior that requires evaluation before adoption.

Primary journey:

```text
user corrects an answer or document change
  -> choose Teach this book
  -> see the proposed lesson in ordinary language
  -> optionally try it on prior examples
  -> accept, revise, or reject
  -> see the MoonBook version and future behavior update
  -> export the evolved agent when desired
```

The Review toolbox should contain a **Learning** tab for pending proposals,
examples, results, accepted lessons, and rollback. The ordinary chat should
show only a small confirmation or an actionable question.

Ownership:

- MoonDesk: teach action and Learning Review UI;
- Bookkeeper: classification, evidence, adoption, and rollback;
- MoonBook: durable learned knowledge/procedures/capability versions;
- MoonClaw: candidate generation and replay on examples;
- MoonGate: comparison evidence when needed.

### 4. Work Agenda

The current cadence/tick view and ICS export are useful plumbing, but users
think in dates, deadlines, meetings, reminders, and expected results.

Work Agenda combines:

- one-time reminders and delayed follow-ups;
- recurring MoonTown work;
- document and review deadlines;
- expected deliverable dates;
- upcoming source checks;
- completed and failed runs;
- links to the conversation, document, review, and artifact produced by a run.

It should offer agenda, week, and month views without becoming a general
calendar application. Users can create or change items through normal language:
“remind me Friday,” “run this on the first business day,” or “pause until the
new spreadsheet arrives.”

Background work remains quiet. Only a requested reminder, completed result,
warning, failure, or required decision generates a notification.

Ownership:

- MoonTown: schedules, occurrences, reminders, and result linkage;
- MoonDesk: agenda and conversational scheduling UX;
- MoonClaw: interpretation of natural-language scheduling requests;
- MoonBook: portable standing-work intent and accepted outcomes.

## P1 feature definitions

### 5. Book Review Rooms

Do not copy a generic Channels application. Create a room around a MoonBook,
document, or deliverable.

A Review Room provides:

- invited people and participating agents;
- document-anchored threads for pages, paragraphs, cells, and slide objects;
- replies, mentions, reactions, pinned decisions, assignments, and unread state;
- a decision summary linked to accepted/rejected document changes;
- a quiet agent presence that responds when mentioned and otherwise posts only
  results or actionable warnings.

The document remains in the existing viewer and the room opens from Review.
MoonFlow owns live presence, unread delivery, delegation, and conflict
resolution; MoonDesk renders the user experience.

### 6. Try another version

Normal document users should receive the value of branching without a model
picker or developer comparison screen.

Add **Try another version** to a stable answer or proposed document change. The
user may provide a direction such as “shorter,” “more visual,” or “more
conservative.” MoonDesk creates alternatives from the same source and document
baseline, then shows a document-native comparison of content, citations,
formulas, formatting, and layout. The user can choose one version or ask the
agent to combine selected parts.

MoonFort isolation and MoonGate comparison remain backstage. MoonCode keeps its
full developer-oriented fork-and-compare controls.

### 7. Living artifacts

Turn the existing artifact and pack-app foundations into a direct creation
workflow. A user can ask for an evidence table, tracker, checklist, calculator,
dashboard, or intake form and receive an interactive artifact beside the chat.

Living artifacts should:

- retain book-scoped data across conversations;
- accept direct user edits and chat-directed updates;
- cite their source material;
- appear in Find & Add and synthesis;
- export to the appropriate Office format when possible;
- optionally become a portable app inside the MoonBook agent.

This is the user-facing bridge between generated files and reusable pack
applications.

### 8. Multimodal document work

Media capabilities belong in context, not in a separate image or voice
playground.

Complete journeys include:

- paste a screenshot and ask a question about it;
- photograph a whiteboard and create an editable action plan;
- record a voice note and insert a structured summary into the open document;
- select an image in DOCX/PPTX and request a replacement or edit;
- generate a chart or illustration from cited data and insert it into the
  document;
- attach the transcript, source media, and generated result as ordinary
  artifacts.

MoonLeaf owns document/media representation and insertion fidelity. MoonClaw
owns interpretation and generation. MoonDesk owns capture and review.

## P2 feature definitions

### 9. Subscribed sources

Add **Keep this current** to a workspace folder, website, cloud folder,
repository, or feed. The subscription records what to watch, how often, and
what constitutes a meaningful change.

New or changed material arrives in the MoonBook Inbox. The agent may summarize
and compare it, but Bookkeeper decides what becomes accepted knowledge. The
Work Agenda shows the next check and links completed checks to their results.

Start with local folders, websites, feeds, and Git repositories. Cloud Drive,
OneDrive/SharePoint, Dropbox, Confluence, Notion, Slack, and similar providers
should arrive through connector capabilities rather than provider-specific
branches in MoonDesk.

### 10. Send for review and Share agent

These are two related but distinct export journeys:

- **Send for review** shares a bounded document snapshot, visible conversation
  result, sources, proposed changes, and comment/decision surface. Reviewer
  responses return to the document Review Room.
- **Share agent** publishes an Agent Passport and its portable
  `.moonbook-agent` package so another user can inspect, install, update, and
  run it as a new MoonBook.

The existing static Work Package remains the offline evidence receipt. It
should not be overloaded into live collaboration or agent distribution.

## UI placement

The established MoonWiki rule remains unchanged:

```text
left: normal general-agent chat
right: DOCX/XLSX/PPTX/PDF viewer
```

New features belong in existing destinations:

| Feature | Placement |
| --- | --- |
| Agent Library and Agent Passport | Packs home |
| Task recipe brief | Packs/template launch, then normal document chat |
| Teach this book | Answer/change action; proposals under Review → Learning |
| Work Agenda | Quiet Background work expansion and Activity |
| Review Rooms | Review toolbox beside the current document |
| Try another version | Answer/change action with document-native compare |
| Living artifact | Right-hand document/artifact viewer |
| Multimodal capture | Add context and selection actions |
| Subscribed sources | Find & Add source action and Background work |
| Send for review | Review and Export actions |

Do not add model pickers, reasoning controls, terminals, raw prompts, raw skill
editors, tool-detail transcripts, or developer browser chrome to MoonWiki.
Those remain MoonCode features.

## Recommended delivery order

### Milestone A: use a reusable agent

1. Agent Passport read model and MoonDesk service projection.
2. Agent Library on Packs home.
3. Schema-generated recipe brief.
4. Owner-confirmed template instance creation and launch.
5. First result opens in the chat-and-document workspace.

Exit journey:

```text
discover agent -> understand it -> supply a brief -> create MoonBook
-> receive first usable deliverable
```

### Milestone B: evolve the agent

1. Remember/Teach actions.
2. Preference, knowledge, procedure, and capability proposal cards.
3. Learning Review with prior-example trials.
4. Accepted version history and rollback.
5. Export the updated MoonBook agent.

Exit journey:

```text
correct result -> teach book -> review evidence -> adopt lesson
-> use improved behavior -> export new version
```

### Milestone C: work over time

1. Human date/time recurrence model over MoonTown schedules.
2. Agenda/week/month projections.
3. Natural-language create, move, pause, resume, and cancel.
4. Run-result and document linkage.
5. User-selected notification destinations.

Exit journey:

```text
schedule in chat -> see upcoming work -> receive meaningful result
-> open exact conversation/document/artifact
```

### Milestone D: collaborate and explore

1. Send-for-review package and guest review.
2. Book Review Rooms with live MoonFlow transport.
3. Try another version and document-native branch comparison.
4. Living artifacts.

### Milestone E: richer inputs and continuous sources

1. Screenshot and voice capture.
2. Contextual image generation/editing and Office insertion.
3. Local folder, website, feed, and Git subscriptions.
4. Connector-backed cloud subscriptions.

## Feature acceptance journeys

Feature work is complete only when a normal user can finish its outcome without
learning internal product topology:

1. Install an agent from its passport, complete a brief, and receive its first
   document.
2. Correct that document, teach the book, accept the learning proposal, and see
   the correction applied in a later task.
3. Export the evolved agent, import it as another MoonBook, and see its accepted
   knowledge and adopted behavior described in the passport.
4. Schedule a recurring task in natural language, see it in Work Agenda, and
   open the conversation and artifact created by one occurrence.
5. Send a document for review, receive an anchored reviewer comment, mention the
   agent, resolve the thread, and apply the accepted change.
6. Request an alternative draft, compare both versions in the document viewer,
   and apply one without entering MoonCode.
7. Create a living tracker, update it through chat, reopen it later, and export
   it to an Office format.
8. Record a voice note or paste an image, generate a reviewed document change,
   and insert it into the open Office file.
9. Subscribe to a source, receive a meaningful-change result in the Inbox, and
   promote accepted knowledge through Bookkeeper review.

## Features not to copy literally

- A generic model marketplace or model picker in MoonWiki. The user chooses an
  agent outcome; routing remains behind it.
- A standalone generic Notes product. MoonDesk should deepen the existing
  document workspace instead.
- A generic Channels clone. Collaboration should be attached to books,
  documents, deliverables, and decisions.
- Raw skill/prompt editors for ordinary users. Normal corrections should become
  explainable learning proposals; source-level controls remain in MoonCode.
- A separate media playground. Voice, images, and video should enter through
  the current task or document.

