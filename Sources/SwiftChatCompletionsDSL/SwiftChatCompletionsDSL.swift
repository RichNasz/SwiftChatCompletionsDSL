import Foundation

// MARK: - Core Enums

/// Defines message roles for chat completions
public enum Role: String, Codable, Sendable {
	case system
	case user
	case assistant
	case tool
}

/// Custom errors for LLM API operations
public enum LLMError: Error, Equatable {
	case invalidURL
	case encodingFailed(String)
	case networkError(String)
	case decodingFailed(String)
	case serverError(statusCode: Int, message: String?)
	case rateLimit
	case invalidResponse
	case invalidValue(String)
	case missingBaseURL
	case missingModel
	
	public static func == (lhs: LLMError, rhs: LLMError) -> Bool {
		switch (lhs, rhs) {
			case (.invalidURL, .invalidURL):
				return true
			case (.encodingFailed(let lhsMessage), .encodingFailed(let rhsMessage)):
				return lhsMessage == rhsMessage
			case (.networkError(let lhsMessage), .networkError(let rhsMessage)):
				return lhsMessage == rhsMessage
			case (.decodingFailed(let lhsMessage), .decodingFailed(let rhsMessage)):
				return lhsMessage == rhsMessage
			case (.serverError(let lhsCode, let lhsMessage), .serverError(let rhsCode, let rhsMessage)):
				return lhsCode == rhsCode && lhsMessage == rhsMessage
			case (.rateLimit, .rateLimit):
				return true
			case (.invalidResponse, .invalidResponse):
				return true
			case (.invalidValue(let lhsMessage), .invalidValue(let rhsMessage)):
				return lhsMessage == rhsMessage
			case (.missingBaseURL, .missingBaseURL):
				return true
			case (.missingModel, .missingModel):
				return true
			default:
				return false
		}
	}
}

// MARK: - Protocols

/// Protocol for extensible chat messages
public protocol ChatMessage: Encodable, Sendable {
	var role: Role { get }
}

/// Protocol for configuration parameters that can modify a ChatRequest
public protocol ChatConfigParameter {
	func apply(to request: inout ChatRequest)
}

// MARK: - Core Message Types

/// Basic text-based message implementation
public struct TextMessage: ChatMessage, Sendable {
	public let role: Role
	public let content: String
	
	public init(role: Role, content: String) {
		self.role = role
		self.content = content
	}
	
	private enum CodingKeys: String, CodingKey {
		case role
		case content
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(role, forKey: .role)
		try container.encode(content, forKey: .content)
	}
}

// MARK: - Configuration Parameter Structs

/// Temperature parameter for controlling randomness (0.0-2.0)
public struct Temperature: ChatConfigParameter {
	public let value: Double
	
	public init(_ value: Double) throws {
		guard (0.0...2.0).contains(value) else {
			throw LLMError.invalidValue("Temperature must be between 0.0 and 2.0, got \(value)")
		}
		self.value = value
	}
	
	public func apply(to request: inout ChatRequest) {
		request.temperature = value
	}
}

/// Maximum tokens parameter (must be > 0)
public struct MaxTokens: ChatConfigParameter {
	public let value: Int
	
	public init(_ value: Int) throws {
		guard value > 0 else {
			throw LLMError.invalidValue("MaxTokens must be greater than 0, got \(value)")
		}
		self.value = value
	}
	
	public func apply(to request: inout ChatRequest) {
		request.maxTokens = value
	}
}

/// Top-p parameter for nucleus sampling (0.0-1.0)
public struct TopP: ChatConfigParameter {
	public let value: Double
	
	public init(_ value: Double) throws {
		guard (0.0...1.0).contains(value) else {
			throw LLMError.invalidValue("TopP must be between 0.0 and 1.0, got \(value)")
		}
		self.value = value
	}
	
	public func apply(to request: inout ChatRequest) {
		request.topP = value
	}
}

/// Frequency penalty parameter (-2.0 to 2.0)
public struct FrequencyPenalty: ChatConfigParameter {
	public let value: Double
	
	public init(_ value: Double) throws {
		guard (-2.0...2.0).contains(value) else {
			throw LLMError.invalidValue("FrequencyPenalty must be between -2.0 and 2.0, got \(value)")
		}
		self.value = value
	}
	
	public func apply(to request: inout ChatRequest) {
		request.frequencyPenalty = value
	}
}

/// Presence penalty parameter (-2.0 to 2.0)
public struct PresencePenalty: ChatConfigParameter {
	public let value: Double
	
	public init(_ value: Double) throws {
		guard (-2.0...2.0).contains(value) else {
			throw LLMError.invalidValue("PresencePenalty must be between -2.0 and 2.0, got \(value)")
		}
		self.value = value
	}
	
	public func apply(to request: inout ChatRequest) {
		request.presencePenalty = value
	}
}

/// Number of completions parameter (must be > 0)
public struct N: ChatConfigParameter {
	public let value: Int
	
	public init(_ value: Int) throws {
		guard value > 0 else {
			throw LLMError.invalidValue("N must be greater than 0, got \(value)")
		}
		self.value = value
	}
	
	public func apply(to request: inout ChatRequest) {
		request.n = value
	}
}

/// Logit bias parameter for token likelihood modification
public struct LogitBias: ChatConfigParameter {
	public let value: [String: Int]
	
	public init(_ value: [String: Int]) {
		self.value = value
	}
	
	public func apply(to request: inout ChatRequest) {
		request.logitBias = value
	}
}

/// User identifier parameter (cannot be empty)
public struct User: ChatConfigParameter {
	public let value: String
	
	public init(_ value: String) throws {
		guard !value.isEmpty else {
			throw LLMError.invalidValue("User identifier cannot be empty")
		}
		self.value = value
	}
	
	public func apply(to request: inout ChatRequest) {
		request.user = value
	}
}

/// Stop sequences parameter (cannot be empty)
public struct Stop: ChatConfigParameter {
	public let value: [String]
	
	public init(_ value: [String]) throws {
		guard !value.isEmpty else {
			throw LLMError.invalidValue("Stop sequences array cannot be empty")
		}
		self.value = value
	}
	
	public func apply(to request: inout ChatRequest) {
		request.stop = value
	}
}

// MARK: - Tool Support (Future Extension)

/// Tool definition for function calling
public struct Tool: Codable, Sendable {
	public let type: String
	public let function: Function
	
	public struct Function: Codable, Sendable {
		public let name: String
		public let description: String
		public let parameters: [String: String]
		
		public init(name: String, description: String, parameters: [String: String]) {
			self.name = name
			self.description = description
			self.parameters = parameters
		}
		
		private enum CodingKeys: String, CodingKey {
			case name, description, parameters
		}
		
		public func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			try container.encode(name, forKey: .name)
			try container.encode(description, forKey: .description)
			try container.encode(parameters, forKey: .parameters)
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			name = try container.decode(String.self, forKey: .name)
			description = try container.decode(String.self, forKey: .description)
			parameters = try container.decode([String: String].self, forKey: .parameters)
		}
	}
	
	public init(type: String = "function", function: Function) {
		self.type = type
		self.function = function
	}
}

/// Tools parameter for function calling
public struct Tools: ChatConfigParameter {
	public let value: [Tool]
	
	public init(_ value: [Tool]) {
		self.value = value
	}
	
	public func apply(to request: inout ChatRequest) {
		request.tools = value
	}
}

// MARK: - Result Builders

/// Result builder for composing message sequences
@resultBuilder
public struct ChatBuilder {
	@inlinable
	public static func buildBlock(_ components: any ChatMessage...) -> [any ChatMessage] {
		Array(components)
	}
	
	@inlinable
	public static func buildEither(first: [any ChatMessage]) -> [any ChatMessage] {
		first
	}
	
	@inlinable
	public static func buildEither(second: [any ChatMessage]) -> [any ChatMessage] {
		second
	}
	
	@inlinable
	public static func buildOptional(_ component: [any ChatMessage]?) -> [any ChatMessage] {
		component ?? []
	}
	
	@inlinable
	public static func buildArray(_ components: [[any ChatMessage]]) -> [any ChatMessage] {
		components.flatMap { $0 }
	}
	
	@inlinable
	public static func buildLimitedAvailability(_ component: [any ChatMessage]) -> [any ChatMessage] {
		component
	}
}

/// Result builder for composing configuration parameters
@resultBuilder
public struct ChatConfigBuilder {
	@inlinable
	public static func buildBlock(_ components: ChatConfigParameter...) -> [ChatConfigParameter] {
		Array(components)
	}
	
	@inlinable
	public static func buildEither(first: [ChatConfigParameter]) -> [ChatConfigParameter] {
		first
	}
	
	@inlinable
	public static func buildEither(second: [ChatConfigParameter]) -> [ChatConfigParameter] {
		second
	}
	
	@inlinable
	public static func buildOptional(_ component: [ChatConfigParameter]?) -> [ChatConfigParameter] {
		component ?? []
	}
	
	@inlinable
	public static func buildArray(_ components: [[ChatConfigParameter]]) -> [ChatConfigParameter] {
		components.flatMap { $0 }
	}
	
	@inlinable
	public static func buildLimitedAvailability(_ component: [ChatConfigParameter]) -> [ChatConfigParameter] {
		component
	}
}

// MARK: - Core Data Structures

/// Represents an API request for chat completions
public struct ChatRequest: Encodable, Sendable {
	public let model: String
	public let messages: [any ChatMessage]
	public var temperature: Double?
	public var maxTokens: Int?
	public var topP: Double?
	public var frequencyPenalty: Double?
	public var presencePenalty: Double?
	public let stream: Bool
	public var n: Int?
	public var logitBias: [String: Int]?
	public var user: String?
	public var stop: [String]?
	public var tools: [Tool]?
	
	/// Initialize ChatRequest with result builders
	public init(
		model: String,
		stream: Bool = false,
		@ChatConfigBuilder config: () throws -> [ChatConfigParameter] = { [] },
		@ChatBuilder messages: () -> [any ChatMessage]
	) throws {
		guard !model.isEmpty else {
			throw LLMError.missingModel
		}
		
		self.model = model
		self.stream = stream
		self.messages = messages()
		
		// Apply configuration parameters
		for parameter in try config() {
			parameter.apply(to: &self)
		}
	}
	
	/// Initialize ChatRequest with pre-built messages array
	public init(
		model: String,
		stream: Bool = false,
		@ChatConfigBuilder config: () throws -> [ChatConfigParameter] = { [] },
		messages: [any ChatMessage]
	) throws {
		guard !model.isEmpty else {
			throw LLMError.missingModel
		}
		
		self.model = model
		self.stream = stream
		self.messages = messages
		
		// Apply configuration parameters
		for parameter in try config() {
			parameter.apply(to: &self)
		}
	}
	
	private enum CodingKeys: String, CodingKey {
		case model
		case messages
		case temperature
		case maxTokens = "max_tokens"
		case topP = "top_p"
		case frequencyPenalty = "frequency_penalty"
		case presencePenalty = "presence_penalty"
		case stream
		case n
		case logitBias = "logit_bias"
		case user
		case stop
		case tools
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(model, forKey: .model)
		
		// Encode messages directly using a container
		var messagesContainer = container.nestedUnkeyedContainer(forKey: .messages)
		for message in messages {
			try messagesContainer.encode(AnyEncodableMessage(message))
		}
		
		try container.encodeIfPresent(temperature, forKey: .temperature)
		try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
		try container.encodeIfPresent(topP, forKey: .topP)
		try container.encodeIfPresent(frequencyPenalty, forKey: .frequencyPenalty)
		try container.encodeIfPresent(presencePenalty, forKey: .presencePenalty)
		try container.encode(stream, forKey: .stream)
		try container.encodeIfPresent(n, forKey: .n)
		try container.encodeIfPresent(logitBias, forKey: .logitBias)
		try container.encodeIfPresent(user, forKey: .user)
		try container.encodeIfPresent(stop, forKey: .stop)
		try container.encodeIfPresent(tools, forKey: .tools)
	}
}

/// Helper for encoding any ChatMessage
private struct AnyEncodableMessage: Encodable {
	private let message: any ChatMessage
	
	init(_ message: any ChatMessage) {
		self.message = message
	}
	
	func encode(to encoder: Encoder) throws {
		try message.encode(to: encoder)
	}
}

/// Utility for managing conversation history
public struct ChatConversation {
	public var history: [any ChatMessage]
	
	/// Initialize with result builder
	public init(@ChatBuilder messages: () -> [any ChatMessage]) {
		self.history = messages()
	}
	
	/// Initialize with optional pre-built history
	public init(history: [any ChatMessage] = []) {
		self.history = history
	}
	
	/// Add a message to the conversation history
	public mutating func add(message: any ChatMessage) {
		history.append(message)
	}
	
	/// Add a user message to the conversation history
	public mutating func addUser(content: String) {
		add(message: TextMessage(role: .user, content: content))
	}
	
	/// Add an assistant message to the conversation history
	public mutating func addAssistant(content: String) {
		add(message: TextMessage(role: .assistant, content: content))
	}
	
	/// Generate a ChatRequest using the conversation history plus optional additional messages
	public func request(
		model: String,
		stream: Bool = false,
		@ChatConfigBuilder config: () throws -> [ChatConfigParameter] = { [] },
		@ChatBuilder additionalMessages: () -> [any ChatMessage] = { [] }
	) throws -> ChatRequest {
		let allMessages = history + additionalMessages()
		return try ChatRequest(model: model, stream: stream, config: config, messages: allMessages)
	}
}

/// Response structure for non-streaming completions
public struct ChatResponse: Decodable, Sendable {
	public let id: String
	public let object: String
	public let created: Int
	public let model: String
	public let choices: [Choice]
	public let usage: Usage?
	
	public struct Choice: Decodable, Sendable {
		public let index: Int
		public let message: Message
		public let finishReason: String?
		
		private enum CodingKeys: String, CodingKey {
			case index
			case message
			case finishReason = "finish_reason"
		}
	}
	
	public struct Message: Decodable, Sendable {
		public let role: Role
		public let content: String
	}
	
	public struct Usage: Decodable, Sendable {
		public let promptTokens: Int
		public let completionTokens: Int
		public let totalTokens: Int
		
		private enum CodingKeys: String, CodingKey {
			case promptTokens = "prompt_tokens"
			case completionTokens = "completion_tokens"
			case totalTokens = "total_tokens"
		}
	}
}

/// Delta structure for streaming completions
public struct ChatDelta: Decodable, Sendable {
	public let choices: [DeltaChoice]
	
	public struct DeltaChoice: Decodable, Sendable {
		public let index: Int
		public let delta: Delta
		public let finishReason: String?
		
		private enum CodingKeys: String, CodingKey {
			case index
			case delta
			case finishReason = "finish_reason"
		}
		
		public struct Delta: Decodable, Sendable {
			public let content: String?
			public let role: Role?
		}
	}
}

// MARK: - LLM Client Actor

/// Thread-safe client for LLM API interactions
@available(macOS 12.0, iOS 15.0, *)
public actor LLMClient {
	private let baseURL: String
	private let apiKey: String
	private let session: URLSession
	
	/// Initialize the LLM client
	/// - Parameters:
	///   - baseURL: Complete endpoint URL (e.g., "https://api.openai.com/v1/chat/completions")
	///   - apiKey: API key for authentication
	///   - sessionConfiguration: Optional URLSession configuration (defaults to .default)
	public init(baseURL: String, apiKey: String, sessionConfiguration: URLSessionConfiguration = .default) throws {
		guard !baseURL.isEmpty else {
			throw LLMError.missingBaseURL
		}
		
		self.baseURL = baseURL
		self.apiKey = apiKey
		self.session = URLSession(configuration: sessionConfiguration)
	}
	
	/// Send a non-streaming completion request
	/// - Parameter request: The chat completion request
	/// - Returns: The chat completion response
	/// - Throws: LLMError for various failure scenarios
	public func complete(_ request: ChatRequest) async throws -> ChatResponse {
		guard let url = URL(string: baseURL) else {
			throw LLMError.invalidURL
		}
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
		urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
		
		do {
			let requestData = try JSONEncoder().encode(request)
			urlRequest.httpBody = requestData
		} catch {
			throw LLMError.encodingFailed(error.localizedDescription)
		}
		
		do {
			let (data, response) = try await session.data(for: urlRequest)
			
			if let httpResponse = response as? HTTPURLResponse {
				switch httpResponse.statusCode {
					case 200...299:
						break
					case 429:
						throw LLMError.rateLimit
					default:
						let errorMessage = String(data: data, encoding: .utf8)
						throw LLMError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
				}
			}
			
			do {
				return try JSONDecoder().decode(ChatResponse.self, from: data)
			} catch {
				throw LLMError.decodingFailed(error.localizedDescription)
			}
		} catch let error as LLMError {
			throw error
		} catch {
			throw LLMError.networkError(error.localizedDescription)
		}
	}
	
	/// Create a streaming completion request
	/// - Parameter request: The chat completion request (should have stream: true)
	/// - Returns: AsyncStream of ChatDelta objects
	nonisolated public func stream(_ request: ChatRequest) -> AsyncStream<ChatDelta> {
		let baseURL = self.baseURL
		let apiKey = self.apiKey
		let session = self.session
		
		return AsyncStream { continuation in
			Task { @Sendable in
				do {
					guard let url = URL(string: baseURL) else {
						continuation.finish()
						return
					}
					
					var urlRequest = URLRequest(url: url)
					urlRequest.httpMethod = "POST"
					urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
					urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
					urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
					
					let requestData = try JSONEncoder().encode(request)
					urlRequest.httpBody = requestData
					
					let (asyncBytes, response) = try await session.bytes(for: urlRequest)
					
					if let httpResponse = response as? HTTPURLResponse {
						switch httpResponse.statusCode {
							case 200...299:
								break
							case 429:
								continuation.finish()
								return
							default:
								continuation.finish()
								return
						}
					}
					
					var buffer = ""
					for try await byte in asyncBytes {
						let character = Character(UnicodeScalar(byte))
						buffer.append(character)
						
						// Process complete SSE events (separated by \n\n)
						while let eventRange = buffer.range(of: "\n\n") {
							let event = String(buffer[..<eventRange.lowerBound])
							buffer.removeSubrange(..<eventRange.upperBound)
							
							// Parse SSE data lines
							for line in event.components(separatedBy: "\n") {
								if line.hasPrefix("data: ") {
									let data = String(line.dropFirst(6)) // Remove "data: " prefix
									
									if data == "[DONE]" {
										continuation.finish()
										return
									}
									
									if let jsonData = data.data(using: .utf8) {
										do {
											let delta = try JSONDecoder().decode(ChatDelta.self, from: jsonData)
											continuation.yield(delta)
										} catch {
											// Continue processing other deltas even if one fails
											continue
										}
									}
								}
							}
						}
					}
					
					continuation.finish()
				} catch {
					continuation.finish()
				}
			}
		}
	}
}
