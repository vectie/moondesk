///|
using @runtime {trait IsCell}

///|
priv struct TypedCell[Model, Msg] {
  model : Ref[Model]
  dispatcher : Dispatcher[Msg]
  dispatch : (Msg) -> Cmd
  update : (Dispatch[Msg], Msg, Model) -> (Cmd, Model)
  view : (Dispatch[Msg], Model) -> @html.Html
  flags : @runtime.Flags
}

///|
/// Message dispatcher type used by a `Cell`.
///
/// Calling `dispatch(msg)` returns a `Cmd` that enqueues `msg` into the cell's
/// update loop.
pub type Dispatch[Msg] = (Msg) -> Cmd

///|
impl[Model, Msg] IsCell for TypedCell[Model, Msg] with step(self, scheduler) {
  if self.dispatcher.inbox.pop() is Some(msg) {
    let (cmd, model) = (self.update)(self.dispatch, msg, self.model.val)
    self.model.val = model
    scheduler.add(cmd)
    self.flags.mark_dirty()
  } else {
    // violate the invariant
  }
}

///|
impl[Model, Msg] IsCell for TypedCell[Model, Msg] with view(self) {
  (self.view)(self.dispatch, self.model.val).0
}

///|
impl[Model, Msg] IsCell for TypedCell[Model, Msg] with flags(self) {
  self.flags
}

///|
priv struct Dispatcher[Msg] {
  id : @runtime.Id
  inbox : @queue.Queue[Msg]
}

///|
fn[Msg] Dispatcher::message(self : Self[Msg], msg : Msg) -> Cmd {
  // carry the drain (which own model and update) in message will cause memory leak in RC
  @runtime.message(self.id, () => self.inbox.push(msg))
}

///|
/// A cell that encapsulates model, update, and view.
struct Cell(&IsCell)

///|
/// Render this cell as `Html`.
pub fn Cell::view(self : Self) -> Html {
  Html::from_vnode(@runtime.VNode::slot(self.0))
}

///|
/// Create a stateful cell with full `model`/`update`/`view` functionality.
///
/// Type parameters:
///
/// - `Model`: a custom type you need to defined, represent the state of this cell.
/// - `Msg`: a custom `enum` you need to defined, represent the events of this cell. 
///
/// Parameters:
///
/// - `model : Model`:
///    initial `Model` value of the cell.
/// 
/// - `update : (Dispatch[Msg], Msg,Model) -> (Cmd,Model)`:
///    Describe how to compute new `Model` from `Msg` and old `Model`. 
///    This callback also receives a `Dispatch[Msg]`, which converts a `Msg`
///    into a `Cmd`.
/// 
/// - `view : (Dispatch[Msg], Model) -> Html`:
///    Describe how to compute `Html` from `Model`.
///    This callback also receives a `Dispatch[Msg]`, which converts a `Msg`
///    into a `Cmd`.
///
/// ## The update loop
///
/// ```text
/// ┌─────────────────┐
/// │                 ▼
/// │            ┌──────────┐
/// │            │   user   │
/// │            └────┬─────┘
/// │                 │ msg,model
/// │                 ▼
/// │           ┌────────────┐   msg,model
/// │           │  update()  │◄────────────┐
/// │           └──┬───────┬─┘             │
/// │    none,model│       │               │
/// │              ▼       │               │
/// │         ┌────────┐   │cmd,model      │
/// │         │ view() │   │               │
/// │         └────┬───┘   │               │
/// │              │       │               │
/// │          html│       ▼               │
/// │              │   ┌─────────┐         │
/// └──────────────┘   │ runtime │─────────┘
///                    └─────────┘
/// ```
/// 
/// This update loop is a bit more complex than `simple_cell`, but follows the
/// same `model -> update -> view` flow.
///
/// The difference is that `update` also returns a command representing a managed
/// side effect. That side effect is executed by the runtime and may produce
/// another message.
///
pub fn[Model, Msg] cell(
  model~ : Model,
  update~ : (Dispatch[Msg], Msg, Model) -> (Cmd, Model),
  view~ : (Dispatch[Msg], Model) -> Html,
) -> Cell {
  let flags = @runtime.Flags::new()
  let dispatcher = { id: flags.id(), inbox: @queue.new() }
  let dispatch = m => dispatcher.message(m)
  let model = @ref.new(model)
  Cell({ view, update, dispatcher, dispatch, model, flags })
}

///|
/// Create a cell and also return its `Dispatch`.
///
/// This is useful when messages need to be sent from outside.
/// 
/// Type parameters:
///
/// - `Model`: a custom type you need to defined, represent the state of this cell.
/// - `Msg`: a custom `enum` you need to defined, represent the events of this cell. 
///
/// Parameters:
///
/// - `model : Model`:
///    initial `Model` value of the cell.
/// 
/// - `update : (Dispatch[Msg], Msg,Model) -> (Cmd,Model)`:
///    Describe how to compute new `Model` from `Msg` and old `Model`. 
///    This callback also receives a `Dispatch[Msg]`, which converts a `Msg`
///    into a `Cmd`.
/// 
/// - `view : (Dispatch[Msg], Model) -> Html`:
///    Describe how to compute `Html` from `Model`.
///    This callback also receives a `Dispatch[Msg]`, which converts a `Msg`
///    into a `Cmd`.
///
/// ## The update loop
///
/// ```text
/// ┌─────────────────┐
/// │                 ▼
/// │            ┌──────────┐
/// │            │   user   │
/// │            └────┬─────┘
/// │                 │ msg,model
/// │                 ▼
/// │           ┌────────────┐   msg,model
/// │           │  update()  │◄────────────┐
/// │           └──┬───────┬─┘             │
/// │    none,model│       │               │
/// │              ▼       │               │
/// │         ┌────────┐   │cmd,model      │
/// │         │ view() │   │               │
/// │         └────┬───┘   │               │
/// │              │       │               │
/// │          html│       ▼               │
/// │              │   ┌─────────┐         │
/// └──────────────┘   │ runtime │─────────┘
///                    └─────────┘
/// ```
/// 
/// This update loop is a bit more complex than `simple_cell`, but follows the
/// same `model -> update -> view` flow.
///
/// The difference is that `update` also returns a command representing a managed
/// side effect. That side effect is executed by the runtime and may produce
/// another message.
///
pub fn[Model, Msg] cell_with_dispatch(
  model~ : Model,
  update~ : (Dispatch[Msg], Msg, Model) -> (Cmd, Model),
  view~ : (Dispatch[Msg], Model) -> Html,
) -> (Dispatch[Msg], Cell) {
  let flags = @runtime.Flags::new()
  let dispatcher = { id: flags.id(), inbox: @queue.new() }
  let dispatch = m => dispatcher.message(m)
  let model = @ref.new(model)
  (dispatch, Cell({ view, update, dispatcher, dispatch, model, flags }))
}

///|
/// Create a cell with simplified `model`/`update`/`view`.
/// 
/// Type parameters:
/// 
/// - `Model`: a custom type you need to defined, represent the state of this cell.
/// - `Msg`: a custom `enum` you need to defined, represent the events of this cell. 
/// 
/// Parameters:
/// 
/// - `model : Model`: initial Model value of the cell.
/// - `update : (Msg, Model) -> Model`: describe how to compute new Model from Msg and old Model.
/// - `view : (Dispatch[Msg], Model) -> Html`: describes how to render Html from Model.
///   This callback also receives a dispatch argument, which converts a Msg
///   into a Cmd.
/// 
/// ## The update loop
///
/// ```text
///    ┌──────┐
///    │ user │◀─────────┐
///    └──────┘          │
///        │ msg, model  │
///        ▼             │
///  ┌──────────┐        │
///  │ update() │        │ html
///  └──────────┘        │
///        │ model       │
///        ▼             │
///   ┌────────┐         │
///   │ view() │─────────┘
///   └────────┘
/// ```
/// 
/// At startup, the initial `model` is rendered as `Html` by `view`. The rendered 
/// HTML can include message-producing command, for example:
/// 
/// ```moonbit nocheck
/// button(on_click=dispatch(MyMsg), "click me")
/// ```
///
/// When the user clicks the button, `MyMsg` is sent to `update` with the current
/// model. `update` then computes the next model from that message, and the new
/// model is rendered again by `view`.
/// 
/// ## Example 
/// 
/// ```moonbit check
/// test "counter" {
///   struct Model {
///     count : Int
///   }
///   enum Msg {
///     Click
///   }
///   let app = @rabbita.simple_cell(
///     model={ count: 0 },
///     update=(msg, model) => {
///       match msg {
///         Click => { count: model.count + 1 }
///       }
///     },
///     view=(dispatch, model) => {
///       div([
///         h1("You clicked \{model.count} times."),
///         button(on_click=dispatch(Click), "+"),
///       ])
///     },
///   )
///   ignore(app) // use `new(app).mount("id")` in client
/// }
/// ```
pub fn[Model, Msg] simple_cell(
  model~ : Model,
  update~ : (Msg, Model) -> Model,
  view~ : (Dispatch[Msg], Model) -> Html,
) -> Cell {
  cell(model~, update=(_, msg, model) => (none, update(msg, model)), view~)
}

///|
pub fn[Model, Msg] simple_cell_with_dispatch(
  model~ : Model,
  update~ : (Msg, Model) -> Model,
  view~ : (Dispatch[Msg], Model) -> Html,
) -> (Dispatch[Msg], Cell) {
  let flags = @runtime.Flags::new()
  let dispatcher = { id: flags.id(), inbox: @queue.new() }
  let dispatch = m => dispatcher.message(m)
  let model = @ref.new(model)
  (
    dispatch,
    Cell({
      view,
      update: (_, msg, model) => (none, update(msg, model)),
      dispatcher,
      dispatch,
      model,
      flags,
    }),
  )
}

///|
/// Create a static cell that always renders the same `Html`.
///
/// Rather than use `static_cell`, it's recommend to wrap a function that return html directly:
/// 
/// ```moonbit nocheck
/// fn button(text : String, on_click~ : Cmd) -> Html {
///   @html.button(style=["..."], on_click~, text)
/// }
/// ```
pub fn static_cell(html : Html) -> Cell {
  cell(model=(), update=fn(_, _ : Unit, _ : Unit) { (none, ()) }, view=fn(
    _,
    _,
  ) {
    html
  })
}
