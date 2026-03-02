//
//  ToolSession.swift
//  SwiftChatCompletionsDSL
//
//  Created by Richard Naszcyniec on 6/23/25.
//  Code assisted by AI
//

import Foundation

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
		let names = tools.map(\.function.name)
		let duplicates = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys
		precondition(duplicates.isEmpty, "Duplicate tool names detected: \(duplicates.sorted().joined(separator: ", "))")

		self.client = client
		self.tools = tools
		self.toolChoice = toolChoice
		self.maxIterations = maxIterations
		self.handlers = handlers
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
}
