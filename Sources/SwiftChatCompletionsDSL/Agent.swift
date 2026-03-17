//
//  Agent.swift
//  SwiftChatCompletionsDSL
//
//  Created by Richard Naszcyniec on 6/23/25.
//  Code assisted by AI
//

import Foundation
import SwiftChatCompletionsMacros

// MARK: - Agent

/// Structured log entry for Agent debugging and observability.
public enum TranscriptEntry: Sendable {
	/// A user message was sent
	case userMessage(String)
	/// The assistant produced a text response
	case assistantMessage(String)
	/// The assistant requested a tool call
	case toolCall(name: String, arguments: String)
	/// A tool returned a result
	case toolResult(name: String, result: String, duration: Duration)
	/// An error occurred
	case error(String)
}

/// Pairs a Tool definition with its handler closure for use with Agent.
public struct AgentTool: Sendable {
	/// The tool definition
	public let tool: Tool
	/// The handler closure that executes the tool
	public let handler: ToolSession.ToolHandler

	/// Creates an AgentTool.
	/// - Parameters:
	///   - tool: The tool definition
	///   - handler: The handler closure
	public init(tool: Tool, handler: @escaping ToolSession.ToolHandler) {
		self.tool = tool
		self.handler = handler
	}

	/// Creates an AgentTool from a `ChatCompletionsTool` instance.
	///
	/// Bridges macro-generated tool types with the Agent system by wrapping
	/// the tool's `call(arguments:)` method to handle JSON argument decoding.
	///
	/// - Parameter instance: An instance of the `ChatCompletionsTool`-conforming type
	public init<T: ChatCompletionsTool>(_ instance: T) {
		let definition = T.toolDefinition
		self.init(tool: definition) { argumentsJSON in
			guard let data = argumentsJSON.data(using: .utf8) else {
				throw LLMError.decodingFailed("Failed to convert arguments to data")
			}
			let args = try JSONDecoder().decode(T.Arguments.self, from: data)
			let output = try await instance.call(arguments: args)
			return output.content
		}
	}
}


/// Result builder for declaratively registering tools with an Agent.
///
/// ## Example Usage
/// ```swift
/// let agent = try Agent(client: client, model: "gpt-4") {
///     AgentTool(tool: weatherTool) { args in
///         return "{\"temperature\": 72}"
///     }
///     AgentTool(tool: calculatorTool) { args in
///         return "42"
///     }
/// }
/// ```
@resultBuilder
public struct AgentToolBuilder {
	public static func buildBlock(_ components: AgentTool...) -> [AgentTool] {
		Array(components)
	}

	public static func buildEither(first: [AgentTool]) -> [AgentTool] {
		first
	}

	public static func buildEither(second: [AgentTool]) -> [AgentTool] {
		second
	}

	public static func buildOptional(_ component: [AgentTool]?) -> [AgentTool] {
		component ?? []
	}

	public static func buildArray(_ components: [[AgentTool]]) -> [AgentTool] {
		components.flatMap { $0 }
	}
}

/// High-level persistent agent with conversation history and tool execution.
///
/// `Agent` manages a multi-turn conversation with an LLM, automatically handling
/// tool calls via `ToolSession`. It maintains conversation history and a debugging
/// transcript for observability.
///
/// ## Example Usage
/// ```swift
/// let agent = try Agent(client: client, model: "gpt-4", systemPrompt: "You are helpful.") {
///     AgentTool(tool: weatherTool) { args in
///         return "{\"temperature\": 72, \"condition\": \"sunny\"}"
///     }
/// }
///
/// let response = try await agent.send("What's the weather in Paris?")
/// print(response)
/// ```
public actor Agent {
	private let client: LLMClient
	private let model: String
	private var conversation: ChatConversation
	private let tools: [Tool]
	private let toolChoice: ToolChoice?
	private let toolHandlers: [String: ToolSession.ToolHandler]
	private let configParams: [ChatConfigParameter]
	private let maxToolIterations: Int
	private var _transcript: [TranscriptEntry] = []

	/// The full conversation history.
	public var history: [any ChatMessage] {
		conversation.history
	}

	/// The debugging transcript of all agent activity.
	public var transcript: [TranscriptEntry] {
		_transcript
	}

	/// The names of all registered tools.
	public var registeredToolNames: [String] {
		tools.map(\.name)
	}

	/// The number of registered tools.
	public var toolCount: Int {
		tools.count
	}

	/// Creates a new Agent with explicit tool definitions and handlers.
	/// - Parameters:
	///   - client: The LLM client to use
	///   - model: The model identifier
	///   - systemPrompt: Optional system prompt
	///   - tools: Tool definitions
	///   - toolChoice: Optional tool choice strategy
	///   - toolHandlers: Dictionary mapping tool names to handlers
	///   - config: Configuration parameters
	///   - maxToolIterations: Maximum tool-calling loop iterations (default: 10)
	public init(
		client: LLMClient,
		model: String,
		systemPrompt: String? = nil,
		tools: [Tool] = [],
		toolChoice: ToolChoice? = nil,
		toolHandlers: [String: ToolSession.ToolHandler] = [:],
		config: [ChatConfigParameter] = [],
		maxToolIterations: Int = 10
	) throws {
		let names = tools.map(\.name)
		let duplicates = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys
		guard duplicates.isEmpty else {
			throw LLMError.invalidValue("Duplicate tool names detected: \(duplicates.sorted().joined(separator: ", "))")
		}

		self.client = client
		self.model = model
		self.tools = tools
		self.toolChoice = toolChoice
		self.toolHandlers = toolHandlers
		self.configParams = config
		self.maxToolIterations = maxToolIterations

		if let systemPrompt {
			self.conversation = ChatConversation {
				TextMessage(role: .system, content: systemPrompt)
			}
		} else {
			self.conversation = ChatConversation()
		}
	}

	/// Creates a new Agent using the builder pattern for tools.
	/// - Parameters:
	///   - client: The LLM client to use
	///   - model: The model identifier
	///   - systemPrompt: Optional system prompt
	///   - maxToolIterations: Maximum tool-calling loop iterations (default: 10)
	///   - config: Configuration parameters using ChatConfigBuilder
	///   - tools: Tools using AgentToolBuilder
	public init(
		client: LLMClient,
		model: String,
		systemPrompt: String? = nil,
		maxToolIterations: Int = 10,
		@ChatConfigBuilder config: () throws -> [ChatConfigParameter] = { [] },
		@AgentToolBuilder tools: () -> [AgentTool]
	) throws {
		let agentTools = tools()
		let toolDefs = agentTools.map(\.tool)
		var handlers: [String: ToolSession.ToolHandler] = [:]
		for agentTool in agentTools {
			let name = agentTool.tool.name
			if handlers[name] != nil {
				throw LLMError.invalidValue("Duplicate tool name: '\(name)'")
			}
			handlers[name] = agentTool.handler
		}

		self.client = client
		self.model = model
		self.tools = toolDefs
		self.toolChoice = nil
		self.toolHandlers = handlers
		self.configParams = try config()
		self.maxToolIterations = maxToolIterations

		if let systemPrompt {
			self.conversation = ChatConversation {
				TextMessage(role: .system, content: systemPrompt)
			}
		} else {
			self.conversation = ChatConversation()
		}
	}

	/// Creates a new Agent with declarative `@SessionBuilder` configuration.
	///
	/// Uses `@SessionBuilder` to accept both messages and tools in a single block.
	/// The first system message found in the components is used as the system prompt.
	///
	/// ## Example Usage
	/// ```swift
	/// let agent = try Agent(client: client, model: "gpt-4") {
	///     System("You are a helpful assistant.")
	///     AgentTool(tool: weatherTool) { args in
	///         return "{\"temperature\": 72}"
	///     }
	/// }
	///
	/// let response = try await agent.run("What's the weather?")
	/// ```
	///
	/// - Parameters:
	///   - client: The LLM client to use
	///   - model: The model identifier
	///   - maxToolIterations: Maximum tool-calling loop iterations (default: 10)
	///   - configure: A `@SessionBuilder` block containing messages and tools
	/// - Throws: `LLMError.invalidValue` if duplicate tool names are detected
	public init(
		client: LLMClient,
		model: String,
		maxToolIterations: Int = 10,
		@SessionBuilder configure: () -> [SessionComponent]
	) throws {
		let components = configure()
		var systemMessages: [String] = []
		var otherMessages: [any ChatMessage] = []
		var toolDefs: [Tool] = []
		var handlers: [String: ToolSession.ToolHandler] = [:]

		for component in components {
			switch component {
			case .message(let msg):
				if msg.role == .system, let textMsg = msg as? TextMessage {
					systemMessages.append(textMsg.content)
				} else {
					otherMessages.append(msg)
				}
			case .agentTool(let agentTool):
				let name = agentTool.tool.name
				if handlers[name] != nil {
					throw LLMError.invalidValue("Duplicate tool name: '\(name)'")
				}
				toolDefs.append(agentTool.tool)
				handlers[name] = agentTool.handler
			case .toolDefinition:
				// Bare Tool definitions are not meaningful in Agent context (no handler);
				// silently ignore to allow shared @SessionBuilder blocks.
				break
			}
		}

		self.client = client
		self.model = model
		self.tools = toolDefs
		self.toolChoice = nil
		self.toolHandlers = handlers
		self.configParams = []
		self.maxToolIterations = maxToolIterations

		if let systemPrompt = systemMessages.first {
			self.conversation = ChatConversation {
				TextMessage(role: .system, content: systemPrompt)
			}
		} else {
			self.conversation = ChatConversation()
		}

		// Add any non-system messages to conversation
		for msg in otherMessages {
			self.conversation.add(message: msg)
		}
	}

	/// Sends a user message and returns the assistant's response.
	///
	/// If the model requests tool calls, they are automatically executed
	/// and the results are sent back until a final text response is produced.
	///
	/// - Parameter message: The user's message text
	/// - Returns: The assistant's text response
	/// - Throws: `LLMError` for API or tool execution failures
	public func send(_ message: String) async throws -> String {
		conversation.addUser(content: message)
		_transcript.append(.userMessage(message))

		if tools.isEmpty {
			// No tools — simple completion
			var request = try ChatRequest(model: model, messages: conversation.history)
			for param in configParams {
				param.apply(to: &request)
			}

			let response = try await client.complete(request)
			let content = response.firstContent ?? ""
			conversation.addAssistant(content: content)
			_transcript.append(.assistantMessage(content))
			return content
		}

		// Use ToolSession for tool-calling loop
		let session = try ToolSession(
			client: client,
			tools: tools,
			toolChoice: toolChoice,
			maxIterations: maxToolIterations,
			handlers: toolHandlers
		)

		// Copy to local to cross isolation boundary
		let configCopy = configParams
		let messagesCopy = conversation.history
		let result = try await session.run(
			model: model,
			messages: messagesCopy,
			configParams: configCopy
		)

		if result.hitIterationLimit {
			throw LLMError.maxIterationsExceeded(maxToolIterations)
		}

		// Record tool activity in transcript
		for entry in result.log {
			_transcript.append(.toolCall(name: entry.name, arguments: entry.arguments))
			_transcript.append(.toolResult(name: entry.name, result: entry.result, duration: entry.duration))
		}

		// Update conversation with all messages from the session
		// Replace history from the point where we started
		let originalCount = conversation.history.count
		let newMessages = result.messages.dropFirst(originalCount)
		for msg in newMessages {
			conversation.add(message: msg)
		}

		// Add final assistant response
		let content = result.response.firstContent ?? ""
		conversation.addAssistant(content: content)
		_transcript.append(.assistantMessage(content))
		return content
	}

	/// Resets the agent's conversation history and transcript.
	public func reset() {
		conversation.clear()
		_transcript.removeAll()
	}
}
