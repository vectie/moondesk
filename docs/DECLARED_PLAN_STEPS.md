# Duplicate or remove declared plan steps

Open a Book with a declared work graph, open Flow, and use **Author a new
declared plan** below the composition canvas. **Duplicate declared operation**
creates a new safe item ID from the selected step's original source operation.
You can duplicate an already duplicated row; its template remains the original
source step. Change the copy's input paths, dependency IDs, criteria and timeout
for the work you want to declare.

**Remove this step** removes only that row from the local child draft. It does
not remove dependents. Repair dependencies explicitly using the remaining item
IDs. The editor blocks preparation of dangling dependencies, cycles, invalid
IDs and empty plans. Reopen a saved draft to recover an earlier saved form.

Save/reopen retains additions, removals and incomplete fields for this exact
source. Earlier v1 local drafts continue to reopen. A source change uses a
separate draft identity. Storage errors or concurrent saves keep the visible
form and display a warning.

Prepare checks the complete child, current source/catalog/health, and input
bytes through the existing fixed native Flow planning bridge. Review the
explicit added/removed rows, field changes and migration preview, then choose
**Import this child plan** or **Import this reviewed revision**. Preparation
and import are separate actions and neither dispatches work. A lost response
can be recovered with the existing prepared-result reload controls.

Copies preserve the source product owner, operation, schemas, requested
authority and required claim. They get a new declaration identity, so matching
operation names or identical inputs cannot inherit the template's accepted
checkpoint. Unchanged remaining steps still use the ordinary migration checks.
The original graph, parent run and accepted history remain unchanged. The
execution-sandbox client remains deny-only.

The v2 form carries an explicit `added_templates` mapping from new item ID to
an original source item ID. A source-owned item cannot be remapped to another
operation. Omitted original rows are removals; dependencies are never silently
rewired. Captured spatial reference evidence is resolved using the original
template's exact contract, including for copies. This is declared work authoring,
not a capability registry, approval mechanism or execution permission.

Qualification is compiled UI and native/HTTP testing. It does not establish
graphical browser, installed desktop, provider, hardware or customer acceptance.
