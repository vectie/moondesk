# Coding setup and knowledge library

MoonDesk's coding setup gives a MoonBook reusable skills, working instructions, model presets, saved prompts, connected tools, and searchable reference material. Open **Coding setup** in Code. Changes to skills, instructions, integrations, and indexed knowledge become available on the next coding turn.

## User journeys

### Create or install a skill

1. Open **Skill library** and choose **New skill**, **Import skill**, or **Import folder**.
2. Give the folder a name matching the `name` in the `SKILL.md` YAML header. Include a description describing when the skill should be used.
3. Edit its instructions. Add supporting text files with relative paths, such as `references/examples.md`.
4. Choose **Save and install**. MoonClaw's existing loader discovers the skill for the next turn and the agent can load it through `read_skill`.
5. Choose **Export bundle** to share the skill and its supporting text files as JSON. **Uninstall skill** removes its editable files; History retains the previous version for restoration.

Import accepts Markdown, JSON bundles, or a folder selected by a browser supporting directory inputs. The editor manages text files; it does not provide a binary asset editor, registry marketplace, remote URL downloader, or package dependency installation.

The existing available-skills catalog remains below the editor. It also shows skills discovered outside the managed installation directory, including bundled system skills. Those external entries remain informational rather than silently being copied or overwritten.

### Set book instructions

1. Select **Book instructions**.
2. Review the existing `AGENTS.md`, edit it, and save.
3. Continue a coding conversation. MoonClaw reloads the full book-root file into the task context for each turn.

Saving edits the book's actual `AGENTS.md`. The previous text is retained in History. This editor does not rewrite instructions in ancestor directories or subdirectories.

### Reuse a model configuration

1. Select **Model presets**.
2. Choose an available connected model, reasoning effort, and task purpose; give the combination a name and save.
3. **Use preset** applies the values through the same live controls used by the Code composer.
4. **Use for new chats** makes it the book default. The runtime applies this default when a new, empty Code conversation has loaded its model list. Resuming an existing conversation keeps its current controls.

A disconnected model cannot be applied. Provider account connection remains in the existing Code setup flow. Presets store model selectors and preferences; they do not duplicate credentials or create provider routes.

### Save a repeatable request

1. Select **Saved prompts**, add a name and instructions, then save.
2. Choose **Add to conversation**. The prompt becomes a visible context attachment through the shared `moondesk:add-context` interaction.
3. Review the conversation draft and send it when ready.

Adding a saved prompt does not submit a message by itself.

### Connect external tools

1. Select **Integrations**.
2. Enter a connection name, MCP HTTP endpoint, and optional bearer token.
3. Save, then choose **Test and discover tools** to perform the actual initialization and tool discovery against that server.
4. MoonCode receives the available integration names in its task context. It can discover input schemas with `mcp_list_tools` and invoke a specific tool with `mcp_call_tool`.
5. Pause, enable, edit, or remove a connection from the same view.

The adapter supports the MCP **2025-11-25** Streamable HTTP protocol with JSON or SSE response bodies, initialization notifications, negotiated protocol headers, session IDs, bearer authentication, and paginated discovery via a cursor. A server's `isError` tool result is surfaced as a failed invocation. Credentials are not included in discovery results or version history.

Current transport scope excludes stdio servers, OAuth negotiation, server-initiated sampling/elicitation, and the newer sessionless MCP protocol. These are separate capabilities, not hidden enabled settings.

### Build a knowledge library

1. Select **Knowledge** and **Add source**.
2. Enter a title and the path of a file in the book; choose **Extract from file**. Text and the supported DOCX, XLSX, and PPTX content models can be indexed.
3. Inspect or correct **Searchable text**. **Open original** opens the source file; editing the extracted text leaves that source unchanged.
4. Search the library. Results are ranked using exact phrases, matching terms, and the source title, and include source labels and extracted-text line ranges.
5. Choose **Add passage to conversation** for an explicit citation attachment. MoonClaw also retrieves relevant passages automatically from the current request at the beginning of each coding turn.
6. Re-extract a file after its original changes, or remove it from the library.

The index consists of passages of up to 20 extracted-text lines. Retrieval returns up to 12 ranked passages. Without an embedding provider, the UI identifies this as ranked text retrieval. PDF OCR/extraction, web crawling, automatic change watching, and a separate reranking model are not part of this implementation. Users can paste extracted PDF text into a reference source.

### Enable hybrid semantic retrieval

1. In **Knowledge**, expand **Semantic search**.
2. Configure an OpenAI-compatible embeddings HTTP endpoint, embedding model and optional API token. This is a retrieval connection; it does not change the model used for coding conversations.
3. Re-extract or save each knowledge source. MoonClaw sends the passages to that provider, and the index stores the returned vectors alongside the text.
4. Search again. MoonClaw embeds the query and combines cosine similarity with normalized phrase/term scores. Results retain their source citations, and the UI identifies actual hybrid results.
5. Changing the endpoint or model makes existing vectors ineligible until the source is saved again. Clear the endpoint to use text search only.

Indexing and semantic queries send searchable text to the configured provider. If that provider or MoonClaw is unavailable, the source remains usable for text search and the UI reports the fallback. Configuring an endpoint alone is not presented as a completed semantic index. Embedding dimensions, response indexes and complete batches are checked before stored vectors are associated with passages.

Citation line numbers refer to the searchable extraction, not native paragraph, slide, or spreadsheet positions. Office extraction includes the content supported by MoonDesk's existing document model; images, charts, and unparsed embedded objects are not represented as searchable text.

### Compare and restore changes

**History** records skill, book-instruction, model-preset, saved-prompt, integration and embedding-connection edits. Expand **Compare changes** to inspect the before and saved versions side by side.

- Skills and instructions open as a draft for review before saving.
- Preset, prompt, and integration configurations can be restored directly; restoration creates a new history entry.
- Integration history stores endpoint configuration and whether a token existed, not the token. Restoring a connection retains a current token with the same connection name; a removed credential must be entered again.

## Runtime and data ownership

| Data | Storage and owner | Consumer |
|---|---|---|
| Skill files | MoonLib-derived `moonclaw/skills/<name>` product artifact directory | Existing MoonClaw skill loader and `read_skill` |
| Book instructions | `<book-root>/AGENTS.md` | MoonClaw per-turn task context |
| Presets, prompts, setup history | MoonDesk product artifact `coding-setup/<book-id-hash>.json` | Setup API and Code composer |
| MCP connection configuration | MoonClaw product artifact `mcp-servers.json` | MoonClaw MCP adapter |
| Embedding connection configuration | MoonClaw product artifact `knowledge-embeddings.json` | MoonClaw embedding client; credentials excluded from history |
| Knowledge records and extraction | `<book-root>/book/knowledge/library.json` | Desk search UI and MoonClaw per-turn retrieval |

Product artifact locations follow `product_artifact_for_workspace_root`. Depending on the MoonSuite layout, installed skills and MCP connections can be shared by books using the same resolved product home. Presets, prompts, and setup history are keyed by book identity; instructions and knowledge belong to the actual book directory.

## Application contracts

- `GET/POST /api/mooncode/setup/:workspace_id`: setup snapshot and mutations.
- `GET /api/mooncode/presets/:workspace_id`: lightweight default-preset lookup.
- `GET/POST /api/mooncode/knowledge/:workspace_id`: library snapshot, indexing, editable extraction, search and removal.
- `POST /v1/mooncode/mcp`: authenticated Desk-to-MoonClaw connection inspection using the existing daemon transport.
- `POST /v1/mooncode/knowledge`: embedding indexing and hybrid retrieval through the same daemon transport.
- `moondesk:add-context`: user-reviewed prompt and knowledge attachments.

The HTTP test path calls real tool discovery. Native tests exercise an in-process HTTP MCP server with initialization, session headers, JSON/SSE responses and a tool invocation; they do not claim compatibility with every third-party server. A separate loopback embedding fixture verifies reordered batch responses and semantic retrieval of a paraphrased source with citations, without a paid provider call.

## Implementation references

- `internal/moonwiki/mooncode_setup.mbt` and `mooncode_setup_integrations.mbt`
- `internal/moonwiki/mooncode_knowledge.mbt`
- `ui/rabbita-desk/mooncode-setup-runtime.js` and `mooncode-knowledge-runtime.js`
- `ui/rabbita-desk/styles/mooncode-setup.css`
- `../moonclaw/cmd/daemon/mooncode_book_instructions.mbt`
- `../moonclaw/cmd/daemon/mooncode_knowledge_context.mbt`
- `../moonclaw/cmd/daemon/mooncode_knowledge_embeddings.mbt`
- `../moonclaw/cmd/daemon/mooncode_mcp.mbt`

The MCP transport follows the [2025-11-25 protocol specification](https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/docs/specification/2025-11-25/basic/transports.mdx).
