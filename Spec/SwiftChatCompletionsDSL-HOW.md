# SwiftChatCompletionsDSL — Implementation Details

Public API spec: [SwiftChatCompletionsDSL.md](SwiftChatCompletionsDSL.md)

---

## Project Structure

Generate as a Swift Package Manager package. Package.swift declares `swift-tools-version: 6.2` with platforms `macOS(.v13), iOS(.v16)`. The core target `SwiftChatCompletionsDSL` has zero external dependencies. A separate `SwiftChatCompletionsDSLMacros` target bridges to `SwiftChatCompletionsMacros`. Tests live in `SwiftChatCompletionsDSLTests`.

## Access Levels

Mark client-facing types/methods as `public` (e.g., `public actor LLMClient`, `public struct ChatRequest`). Use `private` for internal state (e.g., `private let baseURL`). Ensure `@resultBuilder` structs and protocols are `public`. Validation helper functions (`validateRange`, `validatePositive`, etc.) are `@inlinable` internal (not public) — they are implementation details used by configuration structs.

## Concurrency & Sendable

All types must conform to `Sendable` for Swift 6 strict concurrency. This includes `ChatRequest`, `ChatMessage`, `Role`, `LLMError`, and all response types. For `LLMError`, use string descriptions instead of `Error` objects to maintain `Equatable` conformance. Result builder config closures must be typed `() throws -> [ChatConfigParameter]` to allow throwing parameter initialization within the DSL.

## URL Handling

`baseURL` is used as the complete endpoint URL; validation happens at `LLMClient` init time (empty string throws `missingBaseURL`). No path appending is performed.

## Validation Helpers

Four `@inlinable` internal functions handle parameter validation, each throwing `LLMError.invalidValue` with a descriptive message that includes the parameter name, expected range, and actual value:

- `validateRange(_ value: Double, in range: ClosedRange<Double>, parameterName: String)` — validates a Double falls within a closed range
- `validatePositive(_ value: Int, parameterName: String)` — validates an Int is greater than zero
- `validateNotEmpty(_ value: String, parameterName: String)` — validates a String is not empty
- `validateNotEmpty<T>(_ value: [T], parameterName: String)` — validates an array is not empty
- `validateTimeoutRange(_ value: TimeInterval, in range: ClosedRange<TimeInterval>, parameterName: String)` — validates a timeout value falls within a closed range, formats bounds as `Int` in error message

## JSON Encoding

### CodingKeys

Use `CodingKeys` for snake_case mapping (e.g., `maxTokens` → `max_tokens`, `topP` → `top_p`, `toolChoice` → `tool_choice`). This applies to `ChatRequest`, `ChatResponse`, `ChatDelta`, `AssistantToolCallMessage`, `ToolResultMessage`, and `Usage`.

### ChatRequest Encoding

`ChatRequest` has a custom `encode(to:)` method because `[any ChatMessage]` cannot be encoded automatically. It uses a `nestedUnkeyedContainer` for the messages array, wrapping each message in a private `AnyEncodableMessage` struct that forwards encoding to the underlying `ChatMessage`. `requestTimeout` and `resourceTimeout` are intentionally excluded from `CodingKeys` — they are not sent to the API; they are used locally for URLSession configuration only.

### AnyEncodableMessage

Private struct wrapping `any ChatMessage` for encoding. Its sole purpose is to allow `nestedUnkeyedContainer` to encode existential `ChatMessage` values. Contains a single `let message: any ChatMessage` field and forwards `encode(to:)` to the underlying message.

## JSON Decoding

### Shared JSONDecoder

`LLMClient` has a `private static let jsonDecoder = JSONDecoder()` — a static shared instance that avoids repeated allocations during streaming. No custom key decoding strategy is needed because all types use explicit `CodingKeys` for snake_case mapping.

### ChatResponse.Message Custom Decoder

`ChatResponse.Message` has a custom `init(from decoder:)` that handles the case where the API returns `null` for content (which happens when the model returns tool calls). `content` is decoded via `decodeIfPresent(String.self, ...)` with nil coalesced to `""`. This preserves the `String` type (not `String?`) for backward compatibility.

## LLMClient Initialization

The provided `URLSessionConfiguration` is mutated during `LLMClient.init`:
- `waitsForConnectivity` is set to `false`
- `requestCachePolicy` is set to `.reloadIgnoringLocalAndRemoteCacheData`

These optimizations ensure streaming requests start immediately without waiting for connectivity and always fetch fresh data. The default configuration is `URLSessionConfiguration.default` (still mutated with these settings).

## SessionCache

Private nested `actor` inside `LLMClient`, shared via `private static let sessionCache = SessionCache()`.

- **Purpose**: Caches `URLSession` instances keyed by timeout configuration to avoid creating new sessions for every request with custom timeouts.
- **Max cache size**: 10 entries.
- **Key format**: `"\(requestTimeout ?? 0)-\(resourceTimeout ?? 0)"` — both nil values map to 0.
- **Eviction**: When the cache is full, removes the first key (dictionary iteration order, not true LRU, but prevents unbounded growth).
- **Flow**: If both timeouts are nil, returns the default session immediately (no cache lookup). Otherwise, checks cache by key; if missing, creates a new `URLSessionConfiguration.default`, sets `timeoutIntervalForRequest` and `timeoutIntervalForResource` if provided, sets `waitsForConnectivity = false` and `requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData`, creates a `URLSession`, stores it, and returns it.

## HTTP Request Construction

`createURLRequest()` is a `private nonisolated static` method on `LLMClient` that builds a POST `URLRequest`:
- Sets HTTP method to `"POST"`
- Sets `Authorization: Bearer <apiKey>` header
- Sets `Content-Type: application/json` header
- If `acceptSSE` is true, sets `Accept: text/event-stream` header
- Throws `LLMError.invalidURL` if the URL string is malformed

## HTTP Status Validation

`validateHTTPStatus()` is a `private nonisolated static` method on `LLMClient`:
- 200–299: returns `nil` (success)
- 429: returns `.rateLimit`
- All other codes: returns `.serverError(statusCode:message:)` with the response body decoded as UTF-8 text

## Non-Streaming Request Flow (complete)

1. Create URL request via `createURLRequest(baseURL:apiKey:)`
2. Encode `ChatRequest` via `JSONEncoder`, set as `httpBody`; encoding failure → `LLMError.encodingFailed`
3. Get cached session from `SessionCache` (passing request timeouts + default session)
4. Call `sessionToUse.data(for:)` — URLError with `.timedOut` code maps to `LLMError.networkError("Request timeout exceeded")`, other errors → `LLMError.networkError`
5. Validate HTTP status via `validateHTTPStatus()`
6. Decode response via static shared `jsonDecoder`; `DecodingError` → `LLMError.decodingFailed`

## Streaming Method Isolation

`stream()` is marked `nonisolated` on the `LLMClient` actor. It captures `baseURL`, `apiKey`, and `session` as local `let` constants before entering the `AsyncThrowingStream` closure. This avoids requiring `await` just to create the stream, and the captured values are safe to use across isolation boundaries. A `@Sendable` `Task` runs inside the stream closure.

## SSE Parsing Algorithm

The streaming implementation uses `URLSession.bytes(for:)` to get an `AsyncBytes` sequence, then processes bytes character-by-character:

1. Each byte is converted to a `Character` (via `UnicodeScalar`) and appended to a `String` buffer.
2. **Safety limit**: If the buffer exceeds 1MB (1,000,000 characters), the stream finishes with `LLMError.networkError("SSE buffer exceeded maximum size")`. This prevents memory exhaustion from malformed streams that never send proper delimiters.
3. **Event boundary detection**: The algorithm scans for `\n\n` in the buffer. When found, the text before it is extracted as a complete SSE event, and the buffer is trimmed.
4. **Line parsing**: The event text is split by `\n`. Each line starting with `"data: "` (6-character prefix) has its prefix stripped to extract the data payload.
5. **Termination**: If the data string equals `"[DONE]"`, the stream finishes normally.
6. **Decoding**: The data string is converted to UTF-8 bytes and decoded as `ChatDelta` via the static shared `JSONDecoder`. The decoded delta is yielded to the stream consumer.
7. **Error mapping**: `LLMError` passes through unchanged. `DecodingError` is wrapped as `LLMError.decodingFailed`. All other errors become `LLMError.networkError`.

## Tool Support

`Tool.Function.parameters` uses `JSONSchema` (indirect enum with cases: `object`, `array`, `string`, `integer`, `number`, `boolean`, `null`) for type-safe parameter definitions. A deprecated `[String: String]` init is preserved for backward compatibility — it converts each key-value pair into `.string(description: value)` and wraps them in `.object(properties:required:)` with all keys sorted as required. See [ToolCalling-HOW.md](ToolCalling-HOW.md) and [ToolSupportSpec-HOW.md](ToolSupportSpec-HOW.md) for full tool calling and agent implementation details.

## Testing

Support Swift Testing with `#expect` for async tests. Key considerations:
- Use array-based message initialization for simpler test syntax
- Mock URLSession with URLProtocol for network tests
- Test parameter validation with proper error types
- Tests should be stored in ./Tests/SwiftChatCompletionsDSLTests folder

## Edge Cases

Handle empty messages, rate limits (429), invalid JSON, server errors, and SSE buffer overflow.
