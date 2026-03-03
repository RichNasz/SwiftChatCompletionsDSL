//
//  ToolSession.swift
//  SwiftChatCompletionsDSL
//
//  Created by Richard Naszcyniec on 6/23/25.
//  Code assisted by AI
//

import Foundation

// MARK: - Session Component

/// A component that can appear inside a `@SessionBuilder` block.
///
/// `SessionComponent` allows a single result builder to accept both messages
/// (like `System("...")` or `User("...")`) and tool registrations (`AgentTool`).
public enum SessionComponent: Sendable {
	/// A chat message (system prompt, user message, etc.)
	case message(any ChatMessage)
	/// A tool registration with its handler
	case agentTool(AgentTool)
}

// MARK: - Session Builder

/// Result builder for declaratively configuring a session with both messages and tools.
///
/// `SessionBuilder` allows mixing messages and tools in a single builder block,
/// enabling Apple FoundationModels-style declarative configuration.
///
/// ## Example Usage
/// ```swift
/// let session = ToolSession(client: client, model: "gpt-4") {
///     System("You are a helpful assistant.")
///     AgentTool(tool: weatherTool) { args in
///         return "{\"temperature\": 72}"
///     }
/// }
/// ```
@resultBuilder
public struct SessionBuilder {
	public static func buildExpression(_ message: TextMessage) -> [SessionComponent] {
		[.message(message)]
	}

	public static func buildExpression(_ message: any ChatMessage) -> [SessionComponent] {
		[.message(message)]
	}

	public static func buildExpression(_ tool: AgentTool) -> [SessionComponent] {
		[.agentTool(tool)]
	}

	public static func buildBlock(_ components: [SessionComponent]...) -> [SessionComponent] {
		components.flatMap { $0 }
	}

	public static func buildEither(first: [SessionComponent]) -> [SessionComponent] {
		first
	}

	public static func buildEither(second: [SessionComponent]) -> [SessionComponent] {
		second
	}

	public static func buildOptional(_ component: [SessionComponent]?) -> [SessionComponent] {
		component ?? []
	}

	public static func buildArray(_ components: [[SessionComponent]]) -> [SessionComponent] {
		components.flatMap { $0 }
	}
}

// MARK: - Tool Session

/// Log entry for a single tool call execution within a ToolSession.
public struct ToolCallLogEntry: Sendable {
	/// The name of the tool that was called
	public let name: String
	/// The raw JSON arguments passed to the tool
	public let arguments: String
	/// The result returned by the tool handler
	public let result: String
	/// How long the tool execution took
	public let duration: Duration
}

/// Result of a ToolSession run, containing the final response and execution details.
public struct ToolSessionResult: Sendable {
	/// The final chat response (after all tool-calling iterations)
	public let response: ChatResponse
	/// All messages exchanged during the session (including tool calls and results)
	public let messages: [any ChatMessage]
	/// Number of tool-calling iterations performed
	public let iterations: Int
	/// Log of all tool call executions
	public let log: [ToolCallLogEntry]
}

/// Orchestrates the tool-calling loop: send → parse tool_calls → execute → results → repeat.
///
/// `ToolSession` manages the iterative process of sending requests to an LLM,
/// receiving tool call requests, executing the corresponding handlers, and
/// sending results back until the model produces a final text response.
///
/// ## Example Usage
/// ```swift
/// let session = ToolSession(
///     client: client,
///     tools: [weatherTool],
///     handlers: ["get_weather": { args in
///         return "{\"temperature\": 72, \"condition\": \"sunny\"}"
///     }]
/// )
///
/// let result = try await session.run(
///     model: "gpt-4",
///     messages: [TextMessage(role: .user, content: "What's the weather in Paris?")]
/// )
/// print(result.response.firstContent ?? "")
/// ```
public struct ToolSession: Sendable {
	/// Closure type for tool handlers: takes raw JSON arguments, returns result string.
	public typealias ToolHandler = @Sendable (String) async throws -> String

	private let client: LLMClient
	private let tools: [Tool]
	private let toolChoice: ToolChoice?
	private let handlers: [String: ToolHandler]
	private let maxIterations: Int
	private let model: String?
	private let initialMessages: [any ChatMessage]

	/// Creates a new ToolSession.
	/// - Parameters:
	///   - client: The LLM client to use for API calls
	///   - tools: Tool definitions to provide to the model
	///   - toolChoice: Optional tool choice strategy
	///   - maxIterations: Maximum number of tool-calling iterations (default: 10)
	///   - handlers: Dictionary mapping tool names to their handler closures
	public init(
		client: LLMClient,
		tools: [Tool],
		toolChoice: ToolChoice? = nil,
		maxIterations: Int = 10,
		handlers: [String: ToolHandler]
	) {
		// Check for duplicate tool names
		let names = tools.map(\.name)
		let duplicates = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys
		precondition(duplicates.isEmpty, "Duplicate tool names detected: \(duplicates.sorted().joined(separator: ", "))")

		self.client = client
		self.tools = tools
		self.toolChoice = toolChoice
		self.maxIterations = maxIterations
		self.handlers = handlers
		self.model = nil
		self.initialMessages = []
	}

	/// Creates a new ToolSession with declarative configuration.
	///
	/// Uses `@SessionBuilder` to accept both messages and tools in a single block.
	///
	/// ## Example Usage
	/// ```swift
	/// let session = ToolSession(client: client, model: "gpt-4") {
	///     System("You are a helpful assistant.")
	///     AgentTool(tool: weatherTool) { args in
	///         return "{\"temperature\": 72}"
	///     }
	/// }
	///
	/// let result = try await session.run("What's the weather in Paris?")
	/// ```
	///
	/// - Parameters:
	///   - client: The LLM client to use for API calls
	///   - model: The model identifier
	///   - toolChoice: Optional tool choice strategy
	///   - maxIterations: Maximum number of tool-calling iterations (default: 10)
	///   - configure: A `@SessionBuilder` block containing messages and tools
	public init(
		client: LLMClient,
		model: String,
		toolChoice: ToolChoice? = nil,
		maxIterations: Int = 10,
		@SessionBuilder configure: () -> [SessionComponent]
	) {
		let components = configure()
		var messages: [any ChatMessage] = []
		var toolDefs: [Tool] = []
		var toolHandlers: [String: ToolHandler] = [:]

		for component in components {
			switch component {
			case .message(let msg):
				messages.append(msg)
			case .agentTool(let agentTool):
				toolDefs.append(agentTool.tool)
				toolHandlers[agentTool.tool.name] = agentTool.handler
			}
		}

		// Check for duplicate tool names
		let names = toolDefs.map(\.name)
		let duplicates = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys
		precondition(duplicates.isEmpty, "Duplicate tool names detected: \(duplicates.sorted().joined(separator: ", "))")

		self.client = client
		self.tools = toolDefs
		self.toolChoice = toolChoice
		self.maxIterations = maxIterations
		self.handlers = toolHandlers
		self.model = model
		self.initialMessages = messages
	}

	/// Runs the tool-calling loop until the model produces a final response.
	/// - Parameters:
	///   - model: The model identifier
	///   - messages: Initial messages for the conversation
	///   - config: Optional configuration parameters
	/// - Returns: The final result including response, messages, and execution log
	/// - Throws: `LLMError.maxIterationsExceeded` if the loop doesn't converge,
	///           `LLMError.unknownTool` if model calls an unregistered tool,
	///           or any error from the LLM client
	public func run(
		model: String,
		messages: [any ChatMessage],
		@ChatConfigBuilder config: () throws -> [ChatConfigParameter] = { [] }
	) async throws -> ToolSessionResult {
		try await run(model: model, messages: messages, configParams: config())
	}

	/// Runs the tool-calling loop with pre-computed configuration parameters.
	public func run(
		model: String,
		messages: [any ChatMessage],
		configParams: [ChatConfigParameter]
	) async throws -> ToolSessionResult {
		var currentMessages = messages
		var allLog: [ToolCallLogEntry] = []
		var iterations = 0

		while iterations < maxIterations {
			// Build request with tools
			var request = try ChatRequest(model: model, messages: currentMessages)
			request.tools = tools
			request.toolChoice = toolChoice
			for param in configParams {
				param.apply(to: &request)
			}

			let response = try await client.complete(request)

			guard response.requiresToolExecution,
				  let toolCalls = response.firstToolCalls, !toolCalls.isEmpty else {
				// No tool calls — final response
				return ToolSessionResult(
					response: response,
					messages: currentMessages,
					iterations: iterations,
					log: allLog
				)
			}

			// Record assistant's tool call message
			let assistantContent = response.firstContent
			currentMessages.append(
				AssistantToolCallMessage(
					content: assistantContent?.isEmpty == true ? nil : assistantContent,
					toolCalls: toolCalls
				)
			)

			// Execute all tool handlers in parallel
			let results = try await withThrowingTaskGroup(
				of: (Int, String, ToolCallLogEntry).self
			) { group in
				for (index, toolCall) in toolCalls.enumerated() {
					let handlerName = toolCall.function.name
					guard let handler = handlers[handlerName] else {
						throw LLMError.unknownTool(handlerName)
					}

					group.addTask {
						let clock = ContinuousClock()
						let start = clock.now
						do {
							let result = try await handler(toolCall.function.arguments)
							let duration = clock.now - start
							let logEntry = ToolCallLogEntry(
								name: handlerName,
								arguments: toolCall.function.arguments,
								result: result,
								duration: duration
							)
							return (index, result, logEntry)
						} catch {
							throw LLMError.toolExecutionFailed(
								toolName: handlerName,
								message: "[\(type(of: error))] \(error.localizedDescription)"
							)
						}
					}
				}

				var collected: [(Int, String, ToolCallLogEntry)] = []
				for try await result in group {
					collected.append(result)
				}
				return collected.sorted { $0.0 < $1.0 }
			}

			// Append tool result messages in order
			for (index, result, logEntry) in results {
				allLog.append(logEntry)
				currentMessages.append(
					ToolResultMessage(
						toolCallId: toolCalls[index].id,
						content: result
					)
				)
			}

			iterations += 1
		}

		throw LLMError.maxIterationsExceeded(maxIterations)
	}

	/// Runs the tool-calling loop with a user prompt, using the model and messages
	/// configured via the declarative `@SessionBuilder` initializer.
	///
	/// The prompt is appended as a user message after any initial messages
	/// (such as system prompts) provided during initialization.
	///
	/// ## Example Usage
	/// ```swift
	/// let session = ToolSession(client: client, model: "gpt-4") {
	///     System("You are a helpful assistant.")
	///     AgentTool(tool: weatherTool) { args in
	///         return "{\"temperature\": 72}"
	///     }
	/// }
	///
	/// let result = try await session.run("What's the weather in Paris?")
	/// print(result.response.firstContent ?? "")
	/// ```
	///
	/// - Parameter prompt: The user's message text
	/// - Returns: The final result including response, messages, and execution log
	/// - Throws: `LLMError` for API or tool execution failures
	/// - Precondition: Must be created with the declarative `init(client:model:...)` initializer
	public func run(_ prompt: String) async throws -> ToolSessionResult {
		guard let model else {
			preconditionFailure("run(_:) requires ToolSession to be created with the declarative init(client:model:configure:) initializer")
		}
		let messages = initialMessages + [TextMessage(role: .user, content: prompt)]
		return try await run(model: model, messages: messages)
	}
}
