# Writing Command Handlers

Command handlers are free functions that receive the components they need as typed arguments — a limited form of dependency injection. They can be synchronous or asynchronous and follow the same basic rules in both cases.

Handlers live by convention in `sable_ircd/src/command/handlers/` and are registered via the `#[command_handler]` attribute macro.

---

## Registering a Handler

```rust
#[command_handler("PRIVMSG")]
fn handle_privmsg(
    source: UserSource,
    response: &dyn CommandResponse,
    target: TargetParameter,
    text: &str,
) -> CommandResult {
    // ...
}
```

The macro has two forms:

| Form | Example | Purpose |
|---|---|---|
| Single argument | `#[command_handler("JOIN")]` | Registers in the default global dispatcher for client commands. |
| Two arguments | `#[command_handler("CERT", in("NS"))]` | Registers in a named secondary dispatcher (e.g. for services commands). |

---

## Synchronous vs. Asynchronous

**Synchronous handlers** run to completion before any other command or network event is processed. No concurrency concerns.

**Asynchronous handlers** may suspend at `await` points, during which other commands or events may be processed. By default, the handler operates on a snapshot of network state as it was when the handler was first invoked — all injected references remain valid but reflect that snapshot.

If a handler needs up-to-date state after an `await`:

- Accept object names (strings), not parsed objects, as positional arguments.
- Do not inject `&Network` directly; instead take `&ClientServer` and call `.network()` as needed.
- Release network state references before each `await` point and re-acquire them after.
- Store object IDs between accesses, not object references.

The primary use case for async handlers is commands that send a request to a services or remote node and need to act on the response in the same function.

---

## Ambient Arguments

Ambient arguments are injected by the framework before positional arguments are parsed. The following types are supported:

| Type | Description |
|---|---|
| `&dyn Command` | The command being executed. Used to send responses to the originating connection. |
| `&ClientServer` | The client server handling the command. |
| `&Network` | Read-only snapshot of current network state. |
| `ServicesTarget` | Requires an active services instance; provides an interface to send remote requests. |

**Source types** (also usable as ambient arguments):

| Type | Description |
|---|---|
| `CommandSource` | Any source — user or pre-client. |
| `UserSource` | Requires a fully registered user. |
| `PreClientSource` | Requires a pre-registration connection. |
| `LoggedInUserSource` | Requires a registered user who is logged in to an account. |

If the source requirement is not met, an appropriate error is sent and the handler is not invoked.

---

## Positional Arguments

Positional arguments are parsed left-to-right from the IRC command arguments. Each typically consumes one protocol argument.

| Type | Description |
|---|---|
| `&str` | Raw argument string, verbatim. |
| `u32` | Argument parsed as an unsigned integer. |
| `Nickname`, `ChannelKey`, `ChannelRoleName`, `CustomRoleName` | Validated name types. |
| `wrapper::User`, `wrapper::Channel`, `wrapper::Account`, `wrapper::ChannelRegistration` | Nick or channel name looked up in network state. |
| `TargetParameter` | Either a nickname or channel name; looks up the relevant object. |
| `RegisteredChannel` | Channel that must both exist and be registered; provides references to both. |

---

## Conditional Wrappers

These wrappers modify how an argument is consumed and whether it is required.

| Wrapper | Behaviour |
|---|---|
| `Option<T>` | Consumes the argument if present. Provides `Some(T)` if parseable, `None` otherwise. |
| `IfParses<T>` | Consumes the argument only if it parses as `T`. Otherwise leaves it for the next argument. Useful for optional typed arguments in a non-final position. |
| `Conditional<T>` | Attempts to parse `T`, stores any error. Call `.require()?` to return the value or propagate the error to the client. Used when the argument is required only in some code paths. |

`Conditional<T>` can also be used for ambient arguments — for example, when a services connection is only needed in certain branches of a handler.
