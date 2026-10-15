# Code review and source editing

This guide describes the October 13 product implementation. It distinguishes connected workflows from the checks that have actually run. The feature ledger is in [PRODUCT_FEATURE_PROGRAM_2026-10-13.md](PRODUCT_FEATURE_PROGRAM_2026-10-13.md).

## Review a commit or branch

1. Open a coding book and choose the **Review** workbench pane.
2. Expand **History & review discussions**, then choose **Commit history**.
3. Search the loaded commit messages, authors or revisions. **Load older commits** reads another page; the search is over loaded commits.
4. Select a commit to inspect its changes without checking it out. Use **Previous change**, **Next change**, **Side by side / Unified**, and **Next unviewed**.
5. Mark hunks **Viewed** as you inspect them. Viewed state belongs to the book, revision, file and hunk. The selected comparison's scroll position and display mode are retained locally.
6. For a branch comparison, open **Repository**, select a base and choose **Compare with this base**. This compares the current branch against the merge base with the selected ref.

**Highlight changed tokens** emphasizes the changed parts of paired lines. It is a textual token comparison, not a language-wide semantic equivalence claim. **Compare JSON structure** reads the selected commit's before/after file and reports changed JSON value paths. It ignores object key order and formatting. Arrays remain ordered. Invalid JSON reports an error. Other languages do not currently have structural tree comparison.

The inherited Git reader limits the size of one displayed response. Very large commit diffs report an error rather than silently displaying an incomplete patch. Binary files are identified but not rendered as text.

## Read and discuss a pull request

1. Choose **PR discussions**, select an open PR or enter a PR number.
2. Read its conversation and review threads. Threads identify source paths, line locations, resolved state and comments on earlier revisions.
3. Write a reply and select **Post reply to GitHub**, or use the conversation's **Post comment to GitHub**.
4. Use **Resolve discussion** or **Reopen discussion** to update the actual GitHub thread.

Posting occurs only when the user chooses the posting action. Reply drafts remain in local browser storage when posting fails. Errors are shown beside the reply. The thread list supports **Load more discussions**. The conversation displays the latest 50 comments; each review thread displays its first 50 comments. When additional comments exist, the UI links to GitHub rather than claiming to show the entire history.

These actions require the connected host's signed-in GitHub CLI. Implementation and request construction were checked; this development pass did not post live GitHub comments or resolve live discussions.

## Turn a finding into work and review the result

1. Use **Ask for this change** on a local review note, commit hunk or GitHub review comment.
2. Inspect the review context chip in the coding composer. Existing draft text is preserved. Send the message when ready.
3. Open **Findings**. A finding starts as a draft. After the service accepts the message, it links to the actual conversation. **Refresh task status** correlates the finding marker with the canonical command ID and status returned by the task service.
4. Use **Open coding conversation** to inspect the agent response.
5. Use **Inspect resulting file changes** to compare the current file against its original reviewed revision. This includes committed and working changes since that revision. The revision must exist in the local repository; a PR may first need its worktree opened or its branch fetched.
6. Choose **Mark verified after review** when the result addresses the finding. Agent completion alone never marks a finding verified. A verified finding can be reopened.

Findings are local review records. Conversation and execution state still belong to MoonClaw. Follow-ups without a file location can link to a conversation but cannot offer a file-specific resulting diff.

## Ask an agent to review

Choose **Agent review**, then select working changes, a branch against a base, a commit, or a custom scope. **Prepare review in chat** adds explicit review instructions to the composer. Send the message to begin. The instructions request actionable findings with locations and suggested fixes, while asking the agent not to edit during the review.

## Use Git while coding

The **Repository** tab provides real operations:

- Stage or unstage individual files.
- Commit staged changes with a retained commit-message draft.
- Switch to an existing branch, or create and switch to a new branch.
- Create an isolated worktree from the current commit using a new branch name. Uncommitted edits stay in the current book.
- Inspect worktrees and open those registered in the book library.

Git errors retain the user's inputs and are displayed in the review panel. Worktrees outside the library show their location without pretending they are registered books. These operations do not add push, merge or destructive-reset controls.

## Navigate and edit source

The existing editor's definition/reference results, local declarations and line jumps share **Back to location** and **Forward to location**. **Alt+Left / Alt+Right** provide keyboard navigation; **Ctrl/Cmd+G** focuses the line-and-column field. **F12** goes to a definition and **Shift+F12** requests references where supported.

Cursor, selection and scroll positions are retained per book and file. Navigation history survives reopening the book. Stored navigation contains locations, not copies of source text. Positions are bounded to current content and avoid splitting Unicode surrogate pairs. Compiler diagnostics and reference results provide next/previous navigation.

### Language support

| Language | Connected behavior | Scope |
| --- | --- | --- |
| MoonBit | Existing compiler diagnostics, definition lookup and references | Saved source through the configured MoonFort execution service |
| JavaScript / TypeScript | TypeScript parser syntax diagnostics; real language-service definitions and references | Source buffers opened in the current book, including imports whose files have been opened |
| JSON | Parsing diagnostics, existing JSON explorer/editor tools; committed structural comparison | Current document or selected commit |
| Other supported editor languages | Existing highlighting, completion vocabulary and local declaration hints | Textual hints; not compiler semantics |

The JS/TS service is loaded only when requested. TypeScript 6.0.3 is used for its browser-compatible language-service API; TypeScript 7's native package does not expose that API. JS/TS diagnostics are explicitly syntax checks. This implementation does not claim a project build, dependency-aware type check, or a general LSP connection. Open imported source files to make them available for navigation.

## Compare two model answers or approaches

The **Compare** pane lets users choose two models and either compare read-only answers or isolated implementation approaches. Each accepted conversation is saved independently. If one branch fails to start, the accepted conversation remains visible and **Retry A/B only** retries the missing branch with its original request identity. Inputs remain available on partial failure.

Results refresh while work is active and preserve the last answer if a refresh fails. Usage is shown only when the task service reports measured usage. **Continue with this** records the selected branch and opens its conversation; it does not silently merge or promote code. Isolated implementation approaches retain their existing dependency on MoonFort comparison support.

## Verification in this development pass

- Fifteen focused review/editor Node tests passed: diff line numbering and pairing, JSON paths, token boundaries, review scopes, finding-to-command correlation, source navigation and Unicode positions, persistent location isolation, and real JS/TS definitions/references across opened imports.
- Additional comparison tests cover partial start preservation, retry identity and active-turn polling.
- The existing source navigation DOM test passed after the editor integration changes.
- MoonBit checks, interface generation, formatting and final browser/build validation are coordinated by the integrating agent. This document does not label unperformed live GitHub or live Git mutation checks as verified.
