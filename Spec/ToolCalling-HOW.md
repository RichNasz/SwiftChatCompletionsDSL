# Tool Calling & Agent — Implementation Details

Public API spec: [ToolCalling.md](ToolCalling.md)

---

## ToolSession Loop Algorithm

The `run(model:messages:configParams:)` method implements the iterative tool-calling loop:

1. Initialize `currentMessages` from the input messages array, an empty `allLog: [ToolCallLogEntry]` array, and `iterations = 0`.
2. Enter a while loop bounded by `maxIterations`.
3. Build a `ChatRequest` using the array-based init (`ChatRequest(model:messages:)`), then mutate: set `request.tools = tools`, `request.toolChoice = toolChoice`, and apply each config param via `param.apply(to: &request)`.
4. Call `client.complete(request)` to get the response.
5. Check `response.requiresToolExecution` — if false, return a `ToolSessionResult` with the response, `currentMessages`, current `iterations`, and `allLog`.
6. Record the assistant's tool call message: extract `response.firstContent`, create an `AssistantToolCallMessage` with `content` set to `nil` if the content string is empty, and append it to `currentMessages`.
7. Execute all tool handlers in parallel (see section below).
8. Append a `ToolResultMessage` for each result (in sorted order by original index) to `currentMessages`.
9. Increment `iterations` and loop back to step 3.
10. If the while loop exits (iterations reached `maxIterations`), throw `LLMError.maxIterationsExceeded(maxIterations)`.

The `run(model:messages:config:)` overload calls `config()` to resolve the `@ChatConfigBuilder` block, then delegates to the `configParams:` overload.

## Parallel Tool Execution

When the API returns multiple `tool_calls` in a single response, they are executed concurrently using `withThrowingTaskGroup`:

1. The task group result type is `(Int, String, ToolCallLogEntry)` — the `Int` is the original index for ordering.
2. For each tool call in the array (enumerated for index tracking):
   a. Look up the handler by `toolCall.function.name`. If not found, throw `LLMError.unknownTool(handlerName)` immediately (before adding a task to the group).
   b. Add a task to the group that:
      - Records `ContinuousClock.now` as start time
      - Calls `handler(toolCall.function.arguments)`
      - Computes duration as `clock.now - start`
      - Creates a `ToolCallLogEntry` with name, arguments, result, and duration
      - Returns the tuple `(index, result, logEntry)`
      - On error, wraps it as `LLMError.toolExecutionFailed(toolName:message:)` where message is `"[\(type(of: error))] \(error.localizedDescription)"`
3. Collect all task results into an array, then sort by original index to preserve API-correct ordering.
4. Iterate the sorted results: append each `ToolCallLogEntry` to `allLog`, and append a `ToolResultMessage` (with `toolCallId` from the corresponding `toolCall` and `content` from the result string) to `currentMessages`.

## Duration Tracking

Tool execution duration is measured using `ContinuousClock` (not `Date`/`TimeInterval`). `ContinuousClock` provides monotonic, nanosecond-precision timing that is unaffected by system clock changes or daylight saving time. The duration is stored as Swift's `Duration` type in `ToolCallLogEntry`.

## ToolSession Declarative Init Parsing

The `@SessionBuilder` init receives a `[SessionComponent]` array. It iterates the components:
- `.message(let msg)` → appended to a local `messages` array
- `.agentTool(let agentTool)` → tool definition appended to `toolDefs`, handler stored in `toolHandlers` dictionary keyed by tool name

After parsing, duplicate detection runs using the same `precondition` logic as the explicit init (group names, filter duplicates, crash if non-empty). The init stores `model` and `initialMessages` for use by `run(_ prompt:)`.

## ToolSession `run(_ prompt:)` Shorthand

1. Guard that `model` is non-nil — if nil (explicit init was used), trigger `preconditionFailure` with a descriptive message.
2. Create `messages` by concatenating `initialMessages + [TextMessage(role: .user, content: prompt)]`.
3. Call through to `run(model:messages:)` (no config params).

## Agent.send() Flow

1. Add the user message to `conversation` via `addUser(content:)` and append a `.userMessage` transcript entry.
2. **No-tools path**: If `tools.isEmpty`, build a `ChatRequest` from `conversation.history`, apply each config param, call `client.complete`, extract `firstContent` (defaulting to `""`), add assistant message to conversation, append `.assistantMessage` transcript entry, return the content string.
3. **Tools path**: Create a `ToolSession` using the explicit init, passing `client`, `tools`, `toolChoice`, `maxIterations`, and `toolHandlers`.
4. Copy `configParams` and `conversation.history` to local variables (`configCopy`, `messagesCopy`) — this crosses the actor isolation boundary since `ToolSession.run` is not isolated.
5. Call `session.run(model:messages:configParams:)` with the copied values.
6. Log tool activity from `result.log`: for each log entry, append both a `.toolCall(name:arguments:)` and a `.toolResult(name:result:duration:)` transcript entry.
7. Update conversation: compute `originalCount = conversation.history.count`, then iterate `result.messages.dropFirst(originalCount)` and add each message to conversation via `conversation.add(message:)`.
8. Extract `result.response.firstContent` (defaulting to `""`), add assistant message to conversation, append `.assistantMessage` transcript entry, return the content string.

## Agent Declarative Init Parsing

The `@SessionBuilder` init parses `SessionComponent` array into separate collections:
- `TextMessage` with `.system` role → extracted into `systemMessages: [String]` array
- All other messages → `otherMessages: [any ChatMessage]`
- `.agentTool` → tool defs and handlers (with duplicate detection via `throws`, not `precondition`)

After parsing:
- `configParams` is set to empty `[]`
- `toolChoice` is set to `nil`
- If `systemMessages` has at least one entry, the first is used as the system prompt (added to conversation via `ChatConversation` builder init)
- All `otherMessages` are added to conversation after init via `conversation.add(message:)`

## Agent Builder Init

The builder init uses `@AgentToolBuilder` for tools and `@ChatConfigBuilder` for config:
- Evaluates `tools()` to get `[AgentTool]`
- Maps tools to `[Tool]` definitions
- Builds handler dictionary, detecting duplicates by checking `handlers[name] != nil` before insertion — throws `LLMError.invalidValue("Duplicate tool name: '\(name)'")`
- `toolChoice` is always `nil` in this init
- `configParams` comes from evaluating the config builder

## Agent.reset() Behavior

Calls `conversation.clear()` (removes all messages from history) and `_transcript.removeAll()` (clears the debugging transcript). Both collections are fully emptied.

## Error Context in toolExecutionFailed

The error message includes the error's type name for debugging: `"[\(type(of: error))] \(error.localizedDescription)"`. This helps identify whether the underlying error is a network error, decoding error, custom application error, etc.

## Duplicate Tool Name Detection

- **ToolSession** (both explicit and declarative inits): Uses `precondition` — crashes at creation time if duplicate names are found. Groups names via `Dictionary(grouping:by:)`, filters entries with count > 1, and formats a message with sorted duplicate names.
- **Agent explicit init**: Same `precondition` approach as ToolSession.
- **Agent builder init**: Uses `throws` — checks `handlers[name] != nil` before insertion, throws `LLMError.invalidValue("Duplicate tool name: '\(name)'")`
- **Agent declarative init**: Same `throws` approach as builder init.

The rationale: builder and declarative inits already throw (for config evaluation or by convention), so `throws` is natural. The explicit init doesn't throw, so `precondition` is used for compile-time safety without changing the API contract.
