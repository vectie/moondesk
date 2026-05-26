///|
pub using @runtime {trait Scheduler, type EffectKind}

///|
pub let immediately : EffectKind = Immediately

///|
pub let after_render : EffectKind = AfterRender

///|
/// A deferred command handled by the Rabbita runtime.
///
/// `Cmd` models side effects in the update loop. Commands are returned from
/// `update` or embedded in `Html` event handlers, and are executed later by
/// the runtime.
pub type Cmd = @runtime.Cmd

///|
/// A command that does nothing.
pub let none : Cmd = @runtime.none

///|
/// Combine multiple commands into one command.
#inline
pub fn batch(cmds : Array[Cmd]) -> Cmd {
  @runtime.batch(cmds)
}

///|
/// Create a **low-level** effect command for runtime and FFI integration.
/// **Consider use higher-level helpers like `perform`, `delay`, `@http.post()`, and 
/// `@dialog.show()` in app code.**
/// 
/// This function allows you to write wrappers that encapsulate FFI in a
/// command when the functionality is not provided by Rabbita yet. 
/// 
/// Parameters:
/// 
/// - `callback`: receives the runtime `Scheduler`, so it can enqueue follow-up
///   commands (for example, after an async callback).
/// 
/// - `kind`: determines when the effect runs.
///   - `Immediately`: run as soon as the runtime receives it.
///   - `AfterRender`: run after DOM patching for the current flush completes.
/// 
/// Example: 
/// 
/// ```moonbit nocheck
/// extern "js" fn set_timeout(f : () -> Unit, ms : Int) = "(f,ms) => setTimeout(f, ms)"
///
/// pub fn delay(cmd : Cmd, ms : Int) -> Cmd {
///   raw_effect(scheduler => set_timeout(() => scheduler.add(cmd), ms))
/// }
/// ```
#inline
pub fn raw_effect(
  callback : (&Scheduler) -> Unit,
  kind? : EffectKind = Immediately,
) -> Cmd {
  @runtime.effect(callback, kind~)
}

///|
/// Create a command that runs an effectful async function
#cfg(target="js")
pub fn effect(f : async () -> Unit noraise) -> Cmd {
  raw_effect(_ => @js.async_run(() => f()))
}

///|
/// Create a command that runs an async function.
/// 
/// The async function `f` is executed, then its result is converted into a new
/// command by `msg` and scheduled back into the update loop.
#cfg(target="js")
pub fn[A] perform(msg : (A) -> Cmd, f : async () -> A noraise) -> Cmd {
  raw_effect(scheduler => @js.async_run(() => scheduler.add(msg(f()))))
}

///|
/// Create a command that runs an async function and handles errors.
/// 
/// Similar to `perform`, but captures errors and passes `Result[A, E]` to `msg`.
#cfg(target="js")
pub fn[A, E : Error] attempt(
  msg : (Result[A, E]) -> Cmd,
  f : async () -> A raise E,
) -> Cmd {
  raw_effect(scheduler => {
    @js.async_run(() => {
      let msg = try f() catch {
        e => msg(Err(e))
      } noraise {
        r => msg(Ok(r))
      }
      scheduler.add(msg)
    })
  })
}

///|
/// Delay execution of a command by `ms` milliseconds.
///
/// The delayed command is added back to the message queue after the timer fires.
#cfg(target="js")
pub fn delay(cmd : Cmd, ms : Int) -> Cmd {
  raw_effect(scheduler => set_timeout(() => scheduler.add(cmd), ms))
}

///|
#cfg(target="js")
extern "js" fn set_timeout(f : () -> Unit, ms : Int) = "(f,ms) => setTimeout(f, ms)"
