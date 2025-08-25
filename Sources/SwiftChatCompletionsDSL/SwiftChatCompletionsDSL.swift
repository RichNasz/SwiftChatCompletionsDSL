//
//  SwiftChatCompletionsDSL.swift
//  SwiftChatCompletionsDSL
//
//  Created by Richard Naszcyniec on 6/23/25.
//  Code assisted by AI
//

import Foundation

// MARK: - Core Enums

/// Defines message roles for chat completions.
///
/// Each role represents a different participant in the conversation:
/// - `system`: Instructions that define the AI's behavior and personality
/// - `user`: Messages from the human user
/// - `assistant`: Responses from the AI assistant
/// - `tool`: Results from function/tool calls (for advanced usage)
///
/// ## Example Usage
/// ```swift
/// TextMessage(role: .system, content: "You are a helpful assistant.")
/// TextMessage(role: .user, content: "Hello!")
/// TextMessage(role: .assistant, content: "Hi there! How can I help?")
/// ```
public enum Role: String, Codable, Sendable {
	/// Instructions that define the AI's behavior and personality
	case system
	/// Messages from the human user
	case user
	/// Responses from the AI assistant  
	case assistant
	/// Results from function/tool calls
	case tool
}

/// Comprehensive error types for LLM API operations.
///
/// This enum covers all possible failure scenarios when working with LLM APIs,
/// providing detailed error information for proper error handling and debugging.
///
/// ## Common Error Handling Pattern
/// ```swift
/// do {
///     let response = try await client.complete(request)
///     // Handle success
/// } catch LLMError.rateLimit {
///     // Handle rate limiting
/// } catch LLMError.serverError(let statusCode, let message) {
///     // Handle server errors with details
/// } catch LLMError.invalidValue(let description) {
///     // Handle parameter validation errors
/// } catch {
///     // Handle unexpected errors
/// }
/// ```
public enum LLMError: Error, Equatable {
	/// The provided URL string is invalid or malformed
	case invalidURL
	/// JSON encoding of the request failed
	case encodingFailed(String)
	/// Network request failed (connection issues, timeouts, etc.)
	case networkError(String)
	/// JSON decoding of the response failed
	case decodingFailed(String)
	/// Server returned an error response
	case serverError(statusCode: Int, message: String?)
	/// API rate limit exceeded (HTTP 429)
	case rateLimit
	/// Invalid response format from server
	case invalidResponse
	/// Invalid parameter value with descriptive message
	case invalidValue(String)
	/// Base URL is missing or empty
	case missingBaseURL
	/// Model name is missing or empty
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

/// Protocol for extensible chat messages.
///
/// Conform to this protocol to create custom message types beyond the basic ``TextMessage``.
/// This enables support for multimodal content, custom metadata, or specialized message formats.
///
/// ## Requirements
/// - Must be `Encodable` for JSON serialization
/// - Must be `Sendable` for Swift concurrency safety
/// - Must provide a ``Role`` indicating the message sender
///
/// ## Example Implementation
/// ```swift
/// struct ImageMessage: ChatMessage {
///     let role: Role = .user
///     let text: String
///     let imageURL: String
///     
///     private enum CodingKeys: String, CodingKey {
///         case role, content
///     }
///     
///     func encode(to encoder: Encoder) throws {
///         var container = encoder.container(keyedBy: CodingKeys.self)
///         try container.encode(role, forKey: .role)
///         let content = [
///             ["type": "text", "text": text],
///             ["type": "image_url", "image_url": ["url": imageURL]]
///         ]
///         try container.encode(content, forKey: .content)
///     }
/// }
/// ```
public protocol ChatMessage: Encodable, Sendable {
	/// The role of the message sender (system, user, assistant, or tool)
	var role: Role { get }
}

/// Protocol for configuration parameters that can modify a ``ChatRequest``.
///
/// Conform to this protocol to create custom configuration parameters beyond the built-in options.
/// Parameters are applied using the ``ChatConfigBuilder`` result builder syntax.
///
/// ## Requirements
/// - Must implement ``apply(to:)`` to modify the request
/// - Should validate parameter values in the initializer
/// - Throw ``LLMError/invalidValue(_:)`` for invalid values
///
/// ## Example Implementation
/// ```swift
/// struct CustomTimeout: ChatConfigParameter {
///     let seconds: TimeInterval
///     
///     init(_ seconds: TimeInterval) throws {
///         guard seconds > 0 else {
///             throw LLMError.invalidValue("Timeout must be positive, got \(seconds)")
///         }
///         self.seconds = seconds
///     }
///     
///     func apply(to request: inout ChatRequest) {
///         // Apply custom configuration logic
///     }
/// }
/// ```
///
/// ## Built-in Parameters
/// See ``Temperature``, ``MaxTokens``, ``TopP``, ``FrequencyPenalty``, ``PresencePenalty``, 
/// ``N``, ``User``, ``Stop``, ``LogitBias``, and ``Tools`` for examples.
public protocol ChatConfigParameter {
	/// Apply this configuration parameter to the given request.
	/// - Parameter request: The request to modify
	func apply(to request: inout ChatRequest)
}

// MARK: - Core Message Types

/// Basic text-based message implementation.
///
/// The most common message type for simple text conversations. Use this for
/// system prompts, user input, and assistant responses that contain only text.
///
/// ## Example Usage
/// ```swift
/// // System message to define AI behavior
/// TextMessage(role: .system, content: "You are a helpful programming assistant.")
/// 
/// // User question
/// TextMessage(role: .user, content: "How do I declare a variable in Swift?")
/// 
/// // Assistant response (when building conversation history)
/// TextMessage(role: .assistant, content: "In Swift, you can declare variables using 'var' for mutable values or 'let' for constants.")
/// ```
///
/// For more complex content like images or structured data, consider implementing
/// a custom type that conforms to ``ChatMessage``.
public struct TextMessage: ChatMessage, Sendable {
	/// The role of this message (system, user, assistant, or tool)
	public let role: Role
	/// The text content of the message
	public let content: String
	
	/// Creates a new text message.
	/// - Parameters:
	///   - role: The role of the message sender
	///   - content: The text content of the message
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

/// Controls the randomness and creativity of the AI's responses.
///
/// Temperature affects how the model selects tokens during generation:
/// - **Lower values (0.0-0.3)**: More focused, deterministic, and factual responses
/// - **Medium values (0.4-0.7)**: Balanced creativity and coherence  
/// - **Higher values (0.8-2.0)**: More creative, varied, and potentially unexpected responses
///
/// ## Usage Guidelines
/// - **Factual questions**: Use 0.1-0.3 for consistent, accurate answers
/// - **Creative tasks**: Use 0.7-1.2 for stories, brainstorming, creative writing
/// - **Code generation**: Use 0.1-0.5 for predictable, correct code
///
/// ## Example Usage
/// ```swift
/// // For factual questions
/// try Temperature(0.2)
/// 
/// // For creative writing
/// try Temperature(0.8)
/// 
/// // For balanced responses
/// try Temperature(0.7)
/// ```
///
/// - Note: Values must be between 0.0 and 2.0. Values outside this range will throw ``LLMError/invalidValue(_:)``.
public struct Temperature: ChatConfigParameter {
	/// The temperature value between 0.0 and 2.0
	public let value: Double
	
	/// Creates a temperature configuration parameter.
	/// - Parameter value: Temperature value between 0.0 and 2.0
	/// - Throws: ``LLMError/invalidValue(_:)`` if value is outside valid range
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

/// Limits the maximum number of tokens in the AI's response.
///
/// Tokens are the basic units of text processing (roughly equivalent to words or word pieces).
/// This parameter controls the length of the generated response and helps manage costs.
///
/// ## Usage Guidelines
/// - **Short answers**: 50-150 tokens for brief responses
/// - **Explanations**: 200-500 tokens for detailed explanations  
/// - **Long content**: 1000+ tokens for articles, stories, or comprehensive analysis
/// - **Cost control**: Lower values reduce API costs
///
/// ## Token Estimation
/// - ~1 token per word for English text
/// - ~1.3 tokens per word for code
/// - Punctuation and spaces count as separate tokens
///
/// ## Example Usage
/// ```swift
/// // Brief answer
/// try MaxTokens(100)
/// 
/// // Detailed explanation
/// try MaxTokens(300)
/// 
/// // Long-form content
/// try MaxTokens(1500)
/// ```
///
/// - Note: Value must be greater than 0. Zero or negative values will throw ``LLMError/invalidValue(_:)``.
public struct MaxTokens: ChatConfigParameter {
	/// The maximum number of tokens to generate
	public let value: Int
	
	/// Creates a maximum tokens configuration parameter.
	/// - Parameter value: Maximum number of tokens (must be > 0)
	/// - Throws: ``LLMError/invalidValue(_:)`` if value is not positive
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

/// Controls nucleus sampling by limiting token selection to the top probability mass.
///
/// Top-P (nucleus sampling) is an alternative to temperature for controlling randomness.
/// Instead of adjusting all token probabilities, it considers only the smallest set of tokens
/// whose cumulative probability exceeds the P value.
///
/// ## How Top-P Works
/// - **Higher values (0.8-1.0)**: Consider more tokens, allowing greater variety
/// - **Lower values (0.1-0.5)**: Focus on most likely tokens, reducing randomness
/// - **0.1**: Very focused, only most probable tokens
/// - **0.9**: Balanced, excludes only least likely tokens
/// - **1.0**: Consider all tokens (no filtering)
///
/// ## Usage Guidelines
/// Top-P works well in combination with temperature:
/// - **Conservative**: TopP(0.3) + Temperature(0.7) for focused responses
/// - **Balanced**: TopP(0.9) + Temperature(0.7) for natural conversation
/// - **Creative**: TopP(0.95) + Temperature(1.0) for varied, creative output
///
/// ## Example Usage
/// ```swift
/// // Conservative, focused responses
/// try TopP(0.3)
/// 
/// // Natural conversation
/// try TopP(0.9)
/// 
/// // Maximum token variety
/// try TopP(1.0)
/// ```
///
/// - Note: Values must be between 0.0 and 1.0. Values outside this range will throw ``LLMError/invalidValue(_:)``.
public struct TopP: ChatConfigParameter {
	/// The top-p value between 0.0 and 1.0
	public let value: Double
	
	/// Creates a top-p configuration parameter.
	/// - Parameter value: Top-p value between 0.0 and 1.0
	/// - Throws: ``LLMError/invalidValue(_:)`` if value is outside valid range
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

/// Reduces repetition by penalizing tokens based on their frequency in the text so far.
///
/// Frequency penalty discourages the model from repeating the same words or phrases
/// by applying a penalty proportional to how often each token has already appeared.
/// This helps create more varied and interesting responses.
///
/// ## How Frequency Penalty Works
/// - **Positive values (0.1-2.0)**: Discourage repetition, promote variety
/// - **Negative values (-0.1 to -2.0)**: Encourage repetition (rarely used)
/// - **0.0**: No penalty applied (default behavior)
///
/// ## Usage Guidelines
/// - **Light reduction (0.1-0.3)**: Subtle reduction in repetition
/// - **Moderate reduction (0.4-0.7)**: Noticeable variety improvement
/// - **Strong reduction (0.8-2.0)**: Significant penalty against repetition
/// - **Creative writing**: 0.2-0.5 for varied vocabulary
/// - **Technical content**: 0.1-0.3 to maintain necessary terminology
///
/// ## Example Usage
/// ```swift
/// // Light anti-repetition for natural conversation
/// try FrequencyPenalty(0.2)
/// 
/// // Moderate penalty for creative writing
/// try FrequencyPenalty(0.5)
/// 
/// // Strong penalty for maximum variety
/// try FrequencyPenalty(1.0)
/// ```
///
/// - Note: Values must be between -2.0 and 2.0. Values outside this range will throw ``LLMError/invalidValue(_:)``.
public struct FrequencyPenalty: ChatConfigParameter {
	/// The frequency penalty value between -2.0 and 2.0
	public let value: Double
	
	/// Creates a frequency penalty configuration parameter.
	/// - Parameter value: Frequency penalty value between -2.0 and 2.0
	/// - Throws: ``LLMError/invalidValue(_:)`` if value is outside valid range
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

/// Encourages the model to talk about new topics by penalizing tokens that have already appeared.
///
/// Presence penalty applies a one-time penalty to tokens that have appeared anywhere in the text,
/// regardless of frequency. This encourages the model to explore new topics and concepts
/// rather than staying focused on previously mentioned subjects.
///
/// ## Difference from Frequency Penalty
/// - **Frequency Penalty**: Penalizes based on *how often* a token appears
/// - **Presence Penalty**: Penalizes based on *whether* a token has appeared at all
///
/// ## How Presence Penalty Works
/// - **Positive values (0.1-2.0)**: Encourage new topics and broader discussion
/// - **Negative values (-0.1 to -2.0)**: Encourage staying on current topics (rarely used)
/// - **0.0**: No penalty applied (default behavior)
///
/// ## Usage Guidelines
/// - **Light encouragement (0.1-0.3)**: Subtle topic diversification
/// - **Moderate encouragement (0.4-0.7)**: Noticeable exploration of new topics
/// - **Strong encouragement (0.8-2.0)**: Significant push toward new concepts
/// - **Brainstorming**: 0.3-0.6 to explore diverse ideas
/// - **Educational content**: 0.1-0.3 to cover broader concepts while maintaining focus
///
/// ## Example Usage
/// ```swift
/// // Light topic diversification
/// try PresencePenalty(0.2)
/// 
/// // Moderate exploration for brainstorming
/// try PresencePenalty(0.5)
/// 
/// // Strong push for new topics
/// try PresencePenalty(1.0)
/// ```
///
/// - Note: Values must be between -2.0 and 2.0. Values outside this range will throw ``LLMError/invalidValue(_:)``.
public struct PresencePenalty: ChatConfigParameter {
	/// The presence penalty value between -2.0 and 2.0
	public let value: Double
	
	/// Creates a presence penalty configuration parameter.
	/// - Parameter value: Presence penalty value between -2.0 and 2.0
	/// - Throws: ``LLMError/invalidValue(_:)`` if value is outside valid range
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

/// Specifies how many chat completion choices to generate for each input message.
///
/// The N parameter allows you to generate multiple different responses to the same prompt,
/// giving you options to choose from or compare different approaches to the same question.
/// This is useful for creative tasks where you want variety, or when you need to select
/// the best response from multiple options.
///
/// ## Usage Guidelines
/// - **Single response (1)**: Standard usage, most cost-effective
/// - **Multiple options (2-5)**: Good for creative tasks or when you want to choose the best response
/// - **High variety (6-10)**: Useful for brainstorming or exploring different approaches
///
/// ## Cost Considerations
/// Generating multiple completions multiplies your token usage and costs:
/// - N=1: Standard cost
/// - N=3: 3x the cost and token usage
/// - N=5: 5x the cost and token usage
///
/// ## Common Use Cases
/// - **Creative writing**: Generate multiple story variations
/// - **Code solutions**: Compare different implementation approaches
/// - **Response selection**: Choose the best answer from several options
/// - **A/B testing**: Compare different response styles
///
/// ## Example Usage
/// ```swift
/// // Generate single response (standard)
/// try N(1)
/// 
/// // Generate 3 options for creative tasks
/// try N(3)
/// 
/// // Generate 5 variations for comparison
/// try N(5)
/// ```
///
/// - Note: Value must be greater than 0. Zero or negative values will throw ``LLMError/invalidValue(_:)``.
public struct N: ChatConfigParameter {
	/// The number of completions to generate (must be > 0)
	public let value: Int
	
	/// Creates a completions count configuration parameter.
	/// - Parameter value: Number of completions to generate (must be > 0)
	/// - Throws: ``LLMError/invalidValue(_:)`` if value is not positive
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

/// Modifies the likelihood of specified tokens appearing in the completion.
///
/// Logit bias allows fine-grained control over token selection by adjusting the log-odds
/// of specific tokens. This is an advanced parameter that enables precise control over
/// model output, such as encouraging or discouraging specific words or phrases.
///
/// ## How Logit Bias Works
/// The bias values modify token probabilities:
/// - **Positive values (+1 to +100)**: Increase likelihood of the token
/// - **Negative values (-1 to -100)**: Decrease likelihood of the token
/// - **Very negative (-100)**: Effectively ban the token from appearing
/// - **0**: No modification (neutral)
///
/// ## Token Identification
/// Tokens are identified by their string representations in the model's tokenizer.
/// Common tokens include:
/// - Words: "hello", "world", "Swift"
/// - Punctuation: ".", ",", "!"
/// - Partial words: "ing", "ed", "un"
///
/// ## Common Use Cases
/// - **Content filtering**: Ban inappropriate words (-100 bias)
/// - **Style control**: Encourage formal language (+10 for "furthermore", "moreover")
/// - **Format enforcement**: Ensure JSON output (+50 for "{", "}", ":")
/// - **Language preferences**: Bias toward specific terminology
///
/// ## Example Usage
/// ```swift
/// // Ban profanity and encourage politeness
/// try LogitBias([
///     "damn": -100,     // Effectively ban
///     "please": 10,     // Encourage politeness
///     "thank": 5        // Slight encouragement
/// ])
/// 
/// // Encourage JSON format
/// try LogitBias([
///     "{": 50,
///     "}": 50,
///     "\"": 20,
///     ":": 30
/// ])
/// 
/// // Discourage repetitive words
/// try LogitBias([
///     "very": -10,
///     "really": -10,
///     "basically": -15
/// ])
/// ```
///
/// - Note: This is an advanced parameter. Token IDs vary between models and require experimentation.
public struct LogitBias: ChatConfigParameter {
	/// Dictionary mapping token strings to bias values (-100 to +100)
	public let value: [String: Int]
	
	/// Creates a logit bias configuration parameter.
	/// - Parameter value: Dictionary of token strings to bias values
	public init(_ value: [String: Int]) {
		self.value = value
	}
	
	public func apply(to request: inout ChatRequest) {
		request.logitBias = value
	}
}

/// Provides a unique identifier for the end-user, which can help OpenAI monitor and detect abuse.
///
/// The user parameter allows you to associate API requests with specific end-users of your application.
/// This is particularly important for applications with multiple users, as it helps with monitoring,
/// abuse detection, and understanding usage patterns.
///
/// ## Primary Benefits
/// - **Abuse detection**: Helps OpenAI identify potential policy violations
/// - **Usage analytics**: Track API usage by individual users
/// - **Rate limiting**: Some rate limits may be applied per user
/// - **Debugging**: Easier to track issues when they occur
///
/// ## Identifier Guidelines
/// - **Should be unique**: Each user should have a distinct identifier
/// - **Should be consistent**: Use the same ID for the same user across sessions
/// - **Should be anonymous**: Don't use personally identifiable information like emails
/// - **Should be alphanumeric**: Avoid special characters that might cause issues
///
/// ## Best Practices
/// - Use hashed user IDs or UUIDs rather than raw user data
/// - Keep identifiers under 256 characters
/// - Use consistent naming conventions across your application
/// - Consider user privacy when choosing identifiers
///
/// ## Example Usage
/// ```swift
/// // Using a hashed user ID
/// try User("user_abc123")
/// 
/// // Using a UUID-based identifier
/// try User("550e8400-e29b-41d4-a716-446655440000")
/// 
/// // Using an application-specific format
/// try User("app_user_12345")
/// ```
///
/// - Note: User identifier cannot be empty. Empty strings will throw ``LLMError/invalidValue(_:)``.
public struct User: ChatConfigParameter {
	/// The user identifier string (cannot be empty)
	public let value: String
	
	/// Creates a user identifier configuration parameter.
	/// - Parameter value: User identifier string (cannot be empty)
	/// - Throws: ``LLMError/invalidValue(_:)`` if value is empty
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

/// Defines up to 4 sequences where the API will stop generating further tokens.
///
/// Stop sequences allow you to control exactly where the model stops generating text.
/// When the model encounters any of the specified sequences, it immediately stops generation,
/// providing precise control over response boundaries and format.
///
/// ## How Stop Sequences Work
/// The model monitors its output and stops as soon as it generates any of the specified sequences.
/// The stop sequence itself is not included in the returned text, giving you clean cutoffs.
///
/// ## Common Use Cases
/// - **Structured formats**: Stop at specific delimiters for consistent formatting
/// - **Dialogue systems**: Stop at speaker changes or conversation boundaries
/// - **Code generation**: Stop at function/class boundaries
/// - **List generation**: Stop after a specific number of items
/// - **Q&A systems**: Stop after complete answers
///
/// ## Limitations
/// - Maximum of 4 stop sequences per request
/// - Each sequence should be relatively short (typically 1-10 characters)
/// - Case-sensitive matching
/// - Sequences are matched exactly as specified
///
/// ## Example Usage
/// ```swift
/// // Stop at common sentence endings
/// try Stop([".", "!", "?"])
/// 
/// // Stop for structured dialogue
/// try Stop(["Human:", "AI:", "\\n\\n"])
/// 
/// // Stop for code boundaries
/// try Stop(["\\n}\\n", "\\nclass ", "\\nfunc "])
/// 
/// // Stop for list formatting
/// try Stop(["\\n\\n", "---", "END_LIST"])
/// ```
///
/// ## Best Practices
/// - Choose sequences that naturally occur at desired stopping points
/// - Avoid sequences that might appear within desired content
/// - Test with various inputs to ensure consistent behavior
/// - Consider using newline sequences for paragraph boundaries
///
/// - Note: Array cannot be empty. Empty arrays will throw ``LLMError/invalidValue(_:)``.
public struct Stop: ChatConfigParameter {
	/// Array of stop sequences (maximum 4, cannot be empty)
	public let value: [String]
	
	/// Creates a stop sequences configuration parameter.
	/// - Parameter value: Array of stop sequences (cannot be empty, maximum 4)
	/// - Throws: ``LLMError/invalidValue(_:)`` if array is empty
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

/// Defines a tool that the model can call to perform actions or retrieve information.
///
/// Tools enable the AI model to interact with external systems, perform calculations,
/// retrieve real-time data, or execute specific functions. This is an advanced feature
/// that allows for more dynamic and interactive AI applications.
///
/// ## Tool Types
/// Currently, only "function" type tools are supported, which allow the model to call
/// predefined functions with specific parameters and receive structured responses.
///
/// ## Function Tool Structure
/// Each function tool must specify:
/// - **Name**: Unique identifier for the function
/// - **Description**: Clear explanation of what the function does
/// - **Parameters**: Schema defining the expected input parameters
///
/// ## Example Usage
/// ```swift
/// let weatherTool = Tool(function: Tool.Function(
///     name: "get_weather",
///     description: "Get current weather information for a specific location",
///     parameters: [
///         "type": "object",
///         "properties": "{\"location\": {\"type\": \"string\", \"description\": \"City name\"}}",
///         "required": "[\"location\"]"
///     ]
/// ))
/// 
/// let calculatorTool = Tool(function: Tool.Function(
///     name: "calculate",
///     description: "Perform basic mathematical calculations",
///     parameters: [
///         "type": "object",
///         "properties": "{\"expression\": {\"type\": \"string\", \"description\": \"Math expression\"}}",
///         "required": "[\"expression\"]"
///     ]
/// ))
/// ```
///
/// - Note: Tool calling requires appropriate model support and additional handling of tool responses.
public struct Tool: Codable, Sendable {
	/// The type of tool (currently only "function" is supported)
	public let type: String
	/// The function definition for this tool
	public let function: Function
	
	/// Represents a callable function with defined parameters and behavior.
	///
	/// Function tools allow the AI model to call external functions with structured parameters.
	/// The model will generate function calls based on the conversation context and the function
	/// descriptions provided.
	///
	/// ## Parameter Schema
	/// The parameters dictionary should follow JSON Schema format to define:
	/// - Parameter types (string, number, boolean, object, array)
	/// - Required vs optional parameters
	/// - Parameter descriptions and constraints
	/// - Default values where applicable
	///
	/// ## Example Function Definitions
	/// ```swift
	/// // Simple function with one required parameter
	/// Tool.Function(
	///     name: "get_time",
	///     description: "Get current time in specified timezone",
	///     parameters: [
	///         "type": "object",
	///         "properties": "{\"timezone\": {\"type\": \"string\"}}",
	///         "required": "[\"timezone\"]"
	///     ]
	/// )
	/// 
	/// // Complex function with multiple parameters
	/// Tool.Function(
	///     name: "send_email",
	///     description: "Send an email to specified recipients",
	///     parameters: [
	///         "type": "object",
	///         "properties": "{\"to\": {\"type\": \"array\", \"items\": {\"type\": \"string\"}}, \"subject\": {\"type\": \"string\"}, \"body\": {\"type\": \"string\"}}",
	///         "required": "[\"to\", \"subject\", \"body\"]"
	///     ]
	/// )
	/// ```
	public struct Function: Codable, Sendable {
		/// The name of the function (must be unique within the tool set)
		public let name: String
		/// Human-readable description of what the function does
		public let description: String
		/// JSON Schema defining the function's input parameters
		public let parameters: [String: String]
		
		/// Creates a new function definition.
		/// - Parameters:
		///   - name: Unique function name
		///   - description: Clear description of function purpose
		///   - parameters: JSON Schema for function parameters
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
	
	/// Creates a new tool definition.
	/// - Parameters:
	///   - type: Tool type (defaults to "function")
	///   - function: Function definition for this tool
	public init(type: String = "function", function: Function) {
		self.type = type
		self.function = function
	}
}

/// Configuration parameter that provides an array of tools the model can call during conversation.
///
/// The Tools parameter enables function calling capabilities by providing the model with
/// a set of predefined functions it can invoke. This allows for dynamic, interactive
/// applications where the AI can perform actions, retrieve data, or execute code.
///
/// ## How Tool Calling Works
/// 1. You provide a set of available tools with their descriptions
/// 2. The model analyzes the conversation and determines when to call functions
/// 3. The model generates function calls with appropriate parameters
/// 4. Your application executes the functions and provides results
/// 5. The model incorporates the results into its response
///
/// ## Tool Calling Flow
/// ```swift
/// // 1. Define available tools
/// let tools = Tools([
///     Tool(function: Tool.Function(
///         name: "get_weather",
///         description: "Get weather for a location",
///         parameters: [/* schema */]
///     )),
///     Tool(function: Tool.Function(
///         name: "calculate",
///         description: "Perform calculations",
///         parameters: [/* schema */]
///     ))
/// ])
/// 
/// // 2. Include tools in request
/// let request = try ChatRequest(model: "gpt-4") {
///     tools
/// } messages: {
///     TextMessage(role: .user, content: "What's the weather in Paris and what's 15 * 23?")
/// }
/// 
/// // 3. Model may call functions based on the query
/// ```
///
/// ## Best Practices
/// - **Clear descriptions**: Write detailed function descriptions for better tool selection
/// - **Proper schemas**: Use accurate JSON schemas for parameters
/// - **Error handling**: Handle function execution errors gracefully
/// - **Security**: Validate all function parameters before execution
/// - **Performance**: Consider caching for frequently called functions
///
/// ## Example Usage
/// ```swift
/// // Single tool
/// Tools([weatherTool])
/// 
/// // Multiple related tools
/// Tools([
///     calculatorTool,
///     weatherTool,
///     searchTool
/// ])
/// 
/// // Comprehensive tool set
/// Tools([
///     Tool(function: Tool.Function(
///         name: "search_web",
///         description: "Search the internet for current information",
///         parameters: ["type": "object", "properties": "{\"query\": {\"type\": \"string\"}}"]
///     )),
///     Tool(function: Tool.Function(
///         name: "get_stock_price",
///         description: "Get current stock price for a symbol",
///         parameters: ["type": "object", "properties": "{\"symbol\": {\"type\": \"string\"}}"]
///     ))
/// ])
/// ```
///
/// - Note: Tool calling requires model support and proper handling of function call responses.
public struct Tools: ChatConfigParameter {
	/// Array of available tools for the model to call
	public let value: [Tool]
	
	/// Creates a tools configuration parameter.
	/// - Parameter value: Array of Tool definitions available to the model
	public init(_ value: [Tool]) {
		self.value = value
	}
	
	public func apply(to request: inout ChatRequest) {
		request.tools = value
	}
}

// MARK: - Result Builders

/// Result builder for composing message sequences using declarative Swift syntax.
///
/// ``ChatBuilder`` enables the creation of message arrays using Swift's result builder feature,
/// allowing you to write message sequences in a natural, declarative way. This eliminates the need
/// for manual array construction and makes conversation building more readable and maintainable.
///
/// ## Basic Usage
/// The builder automatically collects individual messages into an array:
/// ```swift
/// let messages = {
///     TextMessage(role: .system, content: "You are helpful")
///     TextMessage(role: .user, content: "Hello")
///     TextMessage(role: .assistant, content: "Hi there!")
/// }() // Result: [TextMessage, TextMessage, TextMessage]
/// ```
///
/// ## Supported Swift Features
/// The builder supports standard Swift control flow:
///
/// ### Conditional Messages
/// ```swift
/// let includeContext = true
/// 
/// @ChatBuilder func buildMessages() -> [any ChatMessage] {
///     if includeContext {
///         TextMessage(role: .system, content: "Context message")
///     }
///     TextMessage(role: .user, content: "Main message")
/// }
/// ```
///
/// ### Loops and Arrays
/// ```swift
/// let history = [("user", "Hi"), ("assistant", "Hello")]
/// 
/// @ChatBuilder func buildConversation() -> [any ChatMessage] {
///     TextMessage(role: .system, content: "System prompt")
///     
///     for (role, content) in history {
///         if role == "user" {
///             TextMessage(role: .user, content: content)
///         } else {
///             TextMessage(role: .assistant, content: content)
///         }
///     }
/// }
/// ```
///
/// ### Optional Messages
/// ```swift
/// let systemPrompt: String? = "Be helpful"
/// 
/// @ChatBuilder func buildWithOptional() -> [any ChatMessage] {
///     if let prompt = systemPrompt {
///         TextMessage(role: .system, content: prompt)
///     }
///     TextMessage(role: .user, content: "Question")
/// }
/// ```
///
/// ## Usage in ChatRequest
/// The builder is used automatically in ``ChatRequest`` initializers:
/// ```swift
/// let request = try ChatRequest(model: "gpt-4") {
///     try Temperature(0.7)
/// } messages: {
///     // ChatBuilder context - write messages naturally
///     TextMessage(role: .system, content: "You are helpful")
///     TextMessage(role: .user, content: "Hello")
/// }
/// ```
///
/// ## Advanced Patterns
/// Combine with custom message types for complex conversations:
/// ```swift
/// @ChatBuilder func buildComplexConversation() -> [any ChatMessage] {
///     TextMessage(role: .system, content: "System message")
///     
///     // Custom message types work seamlessly
///     CustomImageMessage(role: .user, imageURL: "...", text: "Describe this")
///     
///     // Conditional logic
///     if needsExamples {
///         TextMessage(role: .system, content: "Provide examples")
///     }
/// }
/// ```
///
/// The builder handles all the complexity of collecting diverse message types into a
/// type-safe array while maintaining Swift's natural syntax.
@resultBuilder
public struct ChatBuilder {
	/// Combines multiple chat messages into a single array.
	/// - Parameter components: Variable number of ChatMessage instances
	/// - Returns: Array containing all provided messages
	@inlinable
	public static func buildBlock(_ components: any ChatMessage...) -> [any ChatMessage] {
		Array(components)
	}
	
	/// Handles if-else conditional message inclusion.
	/// - Parameter first: Messages from the if branch
	/// - Returns: The if branch messages
	@inlinable
	public static func buildEither(first: [any ChatMessage]) -> [any ChatMessage] {
		first
	}
	
	/// Handles if-else conditional message inclusion.
	/// - Parameter second: Messages from the else branch
	/// - Returns: The else branch messages
	@inlinable
	public static func buildEither(second: [any ChatMessage]) -> [any ChatMessage] {
		second
	}
	
	/// Handles optional message inclusion.
	/// - Parameter component: Optional array of messages
	/// - Returns: The messages if present, empty array otherwise
	@inlinable
	public static func buildOptional(_ component: [any ChatMessage]?) -> [any ChatMessage] {
		component ?? []
	}
	
	/// Flattens arrays of messages from loops into a single array.
	/// - Parameter components: Arrays of messages from loop iterations
	/// - Returns: Single flattened array containing all messages
	@inlinable
	public static func buildArray(_ components: [[any ChatMessage]]) -> [any ChatMessage] {
		components.flatMap { $0 }
	}
	
	/// Handles messages with limited availability annotations.
	/// - Parameter component: Messages with availability restrictions
	/// - Returns: The messages unchanged
	@inlinable
	public static func buildLimitedAvailability(_ component: [any ChatMessage]) -> [any ChatMessage] {
		component
	}
}

/// Result builder for composing configuration parameters using declarative Swift syntax.
///
/// ``ChatConfigBuilder`` enables the creation of configuration parameter arrays using Swift's
/// result builder feature. This allows you to specify model behavior parameters in a natural,
/// readable way without manual array construction.
///
/// ## Basic Usage
/// The builder automatically collects configuration parameters into an array:
/// ```swift
/// let config = {
///     try Temperature(0.7)
///     try MaxTokens(150)
///     try TopP(0.9)
/// }() // Result: [Temperature, MaxTokens, TopP]
/// ```
///
/// ## Supported Swift Features
/// The builder supports standard Swift control flow for dynamic configuration:
///
/// ### Conditional Configuration
/// ```swift
/// let isCreativeTask = true
/// 
/// @ChatConfigBuilder func buildConfig() throws -> [ChatConfigParameter] {
///     if isCreativeTask {
///         try Temperature(0.9)      // High creativity
///         try TopP(0.95)
///     } else {
///         try Temperature(0.1)      // Low creativity for factual tasks
///         try TopP(0.5)
///     }
///     try MaxTokens(200)
/// }
/// ```
///
/// ### Environment-Based Configuration
/// ```swift
/// let environment = "production"
/// 
/// @ChatConfigBuilder func environmentConfig() throws -> [ChatConfigParameter] {
///     try Temperature(0.7)
///     try MaxTokens(300)
///     
///     if environment == "development" {
///         try User("dev-user")
///         try N(3)                  // Multiple responses for comparison
///     }
///     
///     if environment == "production" {
///         try FrequencyPenalty(0.1) // Reduce repetition
///     }
/// }
/// ```
///
/// ### Optional Parameters
/// ```swift
/// let userID: String? = getCurrentUserID()
/// 
/// @ChatConfigBuilder func userConfig() throws -> [ChatConfigParameter] {
///     try Temperature(0.7)
///     
///     if let id = userID {
///         try User(id)
///     }
/// }
/// ```
///
/// ## Usage in ChatRequest
/// The builder is used automatically in ``ChatRequest`` initializers:
/// ```swift
/// let request = try ChatRequest(model: "gpt-4") {
///     // ChatConfigBuilder context - specify parameters naturally
///     try Temperature(0.7)
///     try MaxTokens(150)
///     
///     if needsVariety {
///         try FrequencyPenalty(0.2)
///     }
/// } messages: {
///     TextMessage(role: .user, content: "Hello")
/// }
/// ```
///
/// ## Error Handling
/// Configuration parameters can throw validation errors:
/// ```swift
/// @ChatConfigBuilder func safeConfig() throws -> [ChatConfigParameter] {
///     try Temperature(0.7)     // ✅ Valid
///     try MaxTokens(150)       // ✅ Valid
///     try Temperature(3.0)     // ❌ Throws LLMError.invalidValue
/// }
/// ```
///
/// ## Advanced Patterns
/// Combine with custom configuration types:
/// ```swift
/// @ChatConfigBuilder func advancedConfig() throws -> [ChatConfigParameter] {
///     try Temperature(0.8)
///     try MaxTokens(500)
///     
///     // Custom configuration parameters
///     CustomTimeout(seconds: 30)
///     
///     // Tool configuration
///     Tools([weatherTool, calculatorTool])
/// }
/// ```
///
/// The builder provides type safety while maintaining Swift's natural syntax for
/// complex configuration scenarios.
@resultBuilder
public struct ChatConfigBuilder {
	/// Combines multiple configuration parameters into a single array.
	/// - Parameter components: Variable number of ChatConfigParameter instances
	/// - Returns: Array containing all provided parameters
	@inlinable
	public static func buildBlock(_ components: ChatConfigParameter...) -> [ChatConfigParameter] {
		Array(components)
	}
	
	/// Handles if-else conditional parameter inclusion.
	/// - Parameter first: Parameters from the if branch
	/// - Returns: The if branch parameters
	@inlinable
	public static func buildEither(first: [ChatConfigParameter]) -> [ChatConfigParameter] {
		first
	}
	
	/// Handles if-else conditional parameter inclusion.
	/// - Parameter second: Parameters from the else branch
	/// - Returns: The else branch parameters
	@inlinable
	public static func buildEither(second: [ChatConfigParameter]) -> [ChatConfigParameter] {
		second
	}
	
	/// Handles optional parameter inclusion.
	/// - Parameter component: Optional array of parameters
	/// - Returns: The parameters if present, empty array otherwise
	@inlinable
	public static func buildOptional(_ component: [ChatConfigParameter]?) -> [ChatConfigParameter] {
		component ?? []
	}
	
	/// Flattens arrays of parameters from loops into a single array.
	/// - Parameter components: Arrays of parameters from loop iterations
	/// - Returns: Single flattened array containing all parameters
	@inlinable
	public static func buildArray(_ components: [[ChatConfigParameter]]) -> [ChatConfigParameter] {
		components.flatMap { $0 }
	}
	
	/// Handles parameters with limited availability annotations.
	/// - Parameter component: Parameters with availability restrictions
	/// - Returns: The parameters unchanged
	@inlinable
	public static func buildLimitedAvailability(_ component: [ChatConfigParameter]) -> [ChatConfigParameter] {
		component
	}
}

// MARK: - Core Data Structures

/// Represents a complete API request for chat completions with model, configuration, and messages.
///
/// ``ChatRequest`` is the central data structure that encapsulates everything needed to make
/// a chat completion API call. It combines the target model, behavioral configuration parameters,
/// and conversation messages into a single, encodable request object.
///
/// ## Core Components
/// Every chat request consists of three essential elements:
/// 1. **Model**: The LLM to use for generation (e.g., "gpt-4", "claude-3")
/// 2. **Configuration**: Parameters controlling model behavior (temperature, tokens, etc.)
/// 3. **Messages**: The conversation history and new input to process
///
/// ## Request Construction
/// Use the DSL syntax with result builders for clean, readable request construction:
/// ```swift
/// let request = try ChatRequest(model: "gpt-4") {
///     // Configuration parameters
///     try Temperature(0.7)
///     try MaxTokens(150)
///     try TopP(0.9)
/// } messages: {
///     // Conversation messages
///     TextMessage(role: .system, content: "You are a helpful assistant.")
///     TextMessage(role: .user, content: "Explain quantum computing.")
/// }
/// ```
///
/// ## Streaming vs Non-Streaming
/// Control response delivery mode with the `stream` parameter:
/// ```swift
/// // Non-streaming: Get complete response at once
/// let batchRequest = try ChatRequest(model: "gpt-4", stream: false) {
///     try Temperature(0.7)
/// } messages: {
///     TextMessage(role: .user, content: "Quick question")
/// }
/// 
/// // Streaming: Get response incrementally
/// let streamRequest = try ChatRequest(model: "gpt-4", stream: true) {
///     try Temperature(0.7)
/// } messages: {
///     TextMessage(role: .user, content: "Long explanation needed")
/// }
/// ```
///
/// ## Configuration Flexibility
/// Mix and match configuration parameters based on your needs:
/// ```swift
/// // Minimal configuration
/// let simple = try ChatRequest(model: "gpt-4") {
/// } messages: {
///     TextMessage(role: .user, content: "Hello")
/// }
/// 
/// // Comprehensive configuration
/// let detailed = try ChatRequest(model: "gpt-4") {
///     try Temperature(0.8)
///     try MaxTokens(500)
///     try FrequencyPenalty(0.1)
///     try PresencePenalty(0.1)
///     try User("user-123")
///     try Stop(["END", "STOP"])
/// } messages: {
///     TextMessage(role: .system, content: "Be creative but concise.")
///     TextMessage(role: .user, content: "Write a story.")
/// }
/// ```
///
/// ## Pre-built Message Arrays
/// For dynamic message construction, use the array-based initializer:
/// ```swift
/// let messages: [any ChatMessage] = buildConversationHistory()
/// let request = try ChatRequest(model: "gpt-4") {
///     try Temperature(0.7)
/// } messages: messages
/// ```
///
/// ## Validation and Safety
/// The request validates configuration during construction:
/// - Model name cannot be empty
/// - All configuration parameters are validated individually
/// - Type safety prevents runtime configuration errors
///
/// ```swift
/// // This will throw LLMError.missingModel
/// try ChatRequest(model: "") { /* config */ } messages: { /* messages */ }
/// 
/// // This will throw LLMError.invalidValue during Temperature construction
/// try ChatRequest(model: "gpt-4") {
///     try Temperature(3.0)  // Invalid: must be 0.0-2.0
/// } messages: { /* messages */ }
/// ```
///
/// The request object is thread-safe (``Sendable``) and ready for async/await usage.
public struct ChatRequest: Encodable, Sendable {
	/// The model to use for the completion (e.g., "gpt-4", "gpt-3.5-turbo")
	public let model: String
	/// Array of messages comprising the conversation
	public let messages: [any ChatMessage]
	/// Sampling temperature between 0 and 2. Higher values make output more random
	public var temperature: Double?
	/// Maximum number of tokens to generate in the completion
	public var maxTokens: Int?
	/// Nucleus sampling parameter: only tokens with top_p mass are considered
	public var topP: Double?
	/// Penalty for frequency of token usage (-2.0 to 2.0)
	public var frequencyPenalty: Double?
	/// Penalty for presence of tokens (-2.0 to 2.0)
	public var presencePenalty: Double?
	/// Whether to stream back partial progress as server-sent events
	public let stream: Bool
	/// Number of completions to generate for each prompt
	public var n: Int?
	/// Modify likelihood of specified tokens appearing in completion
	public var logitBias: [String: Int]?
	/// Unique identifier representing your end-user for abuse monitoring
	public var user: String?
	/// Up to 4 sequences where the API will stop generating further tokens
	public var stop: [String]?
	/// List of tools the model may call
	public var tools: [Tool]?
	
	/// Creates a new chat completion request using result builder syntax.
	///
	/// This is the primary initializer for building requests with the DSL syntax.
	/// It uses result builders to provide a clean, declarative way to specify
	/// configuration parameters and messages.
	///
	/// ## Example Usage
	/// ```swift
	/// let request = try ChatRequest(model: "gpt-4") {
	///     try Temperature(0.7)
	///     try MaxTokens(150)
	/// } messages: {
	///     TextMessage(role: .system, content: "You are helpful.")
	///     TextMessage(role: .user, content: "Hello!")
	/// }
	/// ```
	///
	/// ## Streaming Support
	/// ```swift
	/// let streamingRequest = try ChatRequest(model: "gpt-4", stream: true) {
	///     try Temperature(0.7)
	/// } messages: {
	///     TextMessage(role: .user, content: "Long response needed")
	/// }
	/// ```
	///
	/// - Parameters:
	///   - model: The model identifier (cannot be empty)
	///   - stream: Whether to stream the response (defaults to false)
	///   - config: Configuration parameters using ChatConfigBuilder
	///   - messages: Messages using ChatBuilder
	/// - Throws: ``LLMError/missingModel`` if model is empty, or parameter validation errors
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
	
	/// Creates a new chat completion request with a pre-built message array.
	///
	/// Use this initializer when you have dynamically constructed messages
	/// or want to reuse an existing message array from conversation history.
	///
	/// ## Example Usage
	/// ```swift
	/// let existingMessages: [any ChatMessage] = loadConversationHistory()
	/// 
	/// let request = try ChatRequest(model: "gpt-4") {
	///     try Temperature(0.7)
	/// } messages: existingMessages
	/// ```
	///
	/// ## Dynamic Message Construction
	/// ```swift
	/// func buildMessages() -> [any ChatMessage] {
	///     var messages: [any ChatMessage] = []
	///     messages.append(TextMessage(role: .system, content: "System prompt"))
	///     
	///     for (role, content) in conversationHistory {
	///         messages.append(TextMessage(role: role, content: content))
	///     }
	///     
	///     return messages
	/// }
	/// 
	/// let request = try ChatRequest(model: "gpt-4") {
	///     try Temperature(0.7)
	/// } messages: buildMessages()
	/// ```
	///
	/// - Parameters:
	///   - model: The model identifier (cannot be empty)
	///   - stream: Whether to stream the response (defaults to false)
	///   - config: Configuration parameters using ChatConfigBuilder
	///   - messages: Pre-built array of ChatMessage instances
	/// - Throws: ``LLMError/missingModel`` if model is empty, or parameter validation errors
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

/// Manages conversation history and provides convenient methods for building multi-turn conversations.
///
/// ``ChatConversation`` is a stateful utility that helps manage ongoing conversations
/// by maintaining a history of messages and providing convenient methods for adding
/// new messages and generating requests. It's particularly useful for chat applications
/// where you need to maintain context across multiple exchanges.
///
/// ## Basic Usage
/// Start with an initial system prompt and build the conversation:
/// ```swift
/// var conversation = ChatConversation {
///     TextMessage(role: .system, content: "You are a helpful assistant.")
/// }
/// 
/// // Add messages to the conversation
/// conversation.addUser(content: "Hello!")
/// conversation.addAssistant(content: "Hi there! How can I help you?")
/// conversation.addUser(content: "What's the weather like?")
/// 
/// // Generate request with full history
/// let request = try conversation.request(model: "gpt-4") {
///     try Temperature(0.7)
/// }
/// ```
///
/// ## Empty Conversation
/// Start with no history and build dynamically:
/// ```swift
/// var conversation = ChatConversation()
/// 
/// // Add system message first
/// conversation.add(message: TextMessage(role: .system, content: "Be helpful."))
/// 
/// // Continue building conversation
/// conversation.addUser(content: "Hi")
/// ```
///
/// ## Pre-built History
/// Initialize with existing message history:
/// ```swift
/// let existingMessages: [any ChatMessage] = loadFromDatabase()
/// var conversation = ChatConversation(history: existingMessages)
/// 
/// // Continue the conversation
/// conversation.addUser(content: "Continue our discussion...")
/// ```
///
/// ## Request Generation
/// Generate requests that include the full conversation context:
/// ```swift
/// // Simple request with conversation history
/// let request = try conversation.request(model: "gpt-4")
/// 
/// // Request with additional configuration
/// let configuredRequest = try conversation.request(model: "gpt-4") {
///     try Temperature(0.8)
///     try MaxTokens(300)
/// }
/// 
/// // Request with additional messages (without modifying history)
/// let requestWithExtra = try conversation.request(model: "gpt-4") {
///     try Temperature(0.7)
/// } additionalMessages: {
///     TextMessage(role: .system, content: "Additional context for this request only")
/// }
/// ```
///
/// ## State Management
/// The conversation maintains mutable state:
/// ```swift
/// var conversation = ChatConversation()
/// 
/// print(conversation.history.count) // 0
/// 
/// conversation.addUser(content: "Hello")
/// print(conversation.history.count) // 1
/// 
/// conversation.addAssistant(content: "Hi!")
/// print(conversation.history.count) // 2
/// ```
///
/// ## Integration with Responses
/// Easily add assistant responses from API calls:
/// ```swift
/// let client = try LLMClient(baseURL: "...", apiKey: "...")
/// 
/// // Send request
/// let request = try conversation.request(model: "gpt-4") {
///     try Temperature(0.7)
/// }
/// 
/// let response = try await client.complete(request)
/// 
/// // Add response to conversation history
/// if let content = response.choices.first?.message.content {
///     conversation.addAssistant(content: content)
/// }
/// ```
///
/// This pattern allows for seamless conversation continuity across multiple API calls.
public struct ChatConversation {
	/// The mutable array of messages comprising the conversation history
	public var history: [any ChatMessage]
	
	/// Creates a new conversation with initial messages using result builder syntax.
	///
	/// Use this initializer to set up a conversation with an initial system prompt
	/// or pre-existing conversation context.
	///
	/// ## Example Usage
	/// ```swift
	/// let conversation = ChatConversation {
	///     TextMessage(role: .system, content: "You are a helpful coding assistant.")
	///     TextMessage(role: .user, content: "I need help with Swift.")
	///     TextMessage(role: .assistant, content: "I'd be happy to help! What specific topic?")
	/// }
	/// ```
	///
	/// - Parameter messages: Initial messages using ChatBuilder syntax
	public init(@ChatBuilder messages: () -> [any ChatMessage]) {
		self.history = messages()
	}
	
	/// Creates a new conversation with optional pre-built message history.
	///
	/// Use this initializer for empty conversations or when you have an existing
	/// message array from persistence or other sources.
	///
	/// ## Example Usage
	/// ```swift
	/// // Empty conversation
	/// var emptyConversation = ChatConversation()
	/// 
	/// // With existing history
	/// let existingMessages = loadFromDatabase()
	/// var restoredConversation = ChatConversation(history: existingMessages)
	/// ```
	///
	/// - Parameter history: Existing message array (defaults to empty)
	public init(history: [any ChatMessage] = []) {
		self.history = history
	}
	
	/// Adds a message to the conversation history.
	///
	/// Use this for adding any type of message, including custom message types.
	///
	/// ## Example Usage
	/// ```swift
	/// conversation.add(message: TextMessage(role: .system, content: "System update"))
	/// conversation.add(message: CustomImageMessage(role: .user, imageURL: "..."))
	/// ```
	///
	/// - Parameter message: The ChatMessage to add to the history
	public mutating func add(message: any ChatMessage) {
		history.append(message)
	}
	
	/// Adds a user message to the conversation history.
	///
	/// Convenience method for adding text messages from the user.
	///
	/// ## Example Usage
	/// ```swift
	/// conversation.addUser(content: "What's the weather like today?")
	/// conversation.addUser(content: "Can you explain how this code works?")
	/// ```
	///
	/// - Parameter content: The text content of the user message
	public mutating func addUser(content: String) {
		add(message: TextMessage(role: .user, content: content))
	}
	
	/// Adds an assistant message to the conversation history.
	///
	/// Convenience method for adding text messages from the assistant.
	/// Typically used to record responses from API calls.
	///
	/// ## Example Usage
	/// ```swift
	/// conversation.addAssistant(content: "The weather is sunny and 72°F.")
	/// 
	/// // After API call
	/// let response = try await client.complete(request)
	/// if let content = response.choices.first?.message.content {
	///     conversation.addAssistant(content: content)
	/// }
	/// ```
	///
	/// - Parameter content: The text content of the assistant message
	public mutating func addAssistant(content: String) {
		add(message: TextMessage(role: .assistant, content: content))
	}
	
	/// Generates a ChatRequest using the conversation history plus optional additional messages.
	///
	/// This method combines the conversation history with optional additional messages
	/// to create a complete request. The additional messages are not added to the
	/// conversation history, making them useful for one-time context or instructions.
	///
	/// ## Example Usage
	/// ```swift
	/// // Basic request with conversation history
	/// let request = try conversation.request(model: "gpt-4")
	/// 
	/// // With configuration
	/// let configuredRequest = try conversation.request(model: "gpt-4") {
	///     try Temperature(0.8)
	///     try MaxTokens(200)
	/// }
	/// 
	/// // With additional context (not added to history)
	/// let contextualRequest = try conversation.request(model: "gpt-4") {
	///     try Temperature(0.7)
	/// } additionalMessages: {
	///     TextMessage(role: .system, content: "Respond in French for this request only")
	/// }
	/// ```
	///
	/// - Parameters:
	///   - model: The model identifier for the request
	///   - stream: Whether to stream the response (defaults to false)
	///   - config: Configuration parameters using ChatConfigBuilder
	///   - additionalMessages: Extra messages for this request only (not added to history)
	/// - Returns: A ChatRequest ready to send to the API
	/// - Throws: ``LLMError/missingModel`` if model is empty, or parameter validation errors
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

/// Thread-safe client for LLM API interactions using Swift's actor model.
///
/// ``LLMClient`` provides a safe, concurrent interface for making chat completion requests
/// to OpenAI-compatible APIs. Built as an actor, it ensures thread safety while supporting
/// both streaming and non-streaming requests with comprehensive error handling.
///
/// ## Initialization
/// Create clients for different LLM providers by specifying the appropriate base URL:
/// ```swift
/// // OpenAI
/// let openAIClient = try LLMClient(
///     baseURL: "https://api.openai.com/v1/chat/completions",
///     apiKey: "your-openai-key"
/// )
/// 
/// // Azure OpenAI
/// let azureClient = try LLMClient(
///     baseURL: "https://your-resource.openai.azure.com/openai/deployments/your-deployment/chat/completions?api-version=2023-12-01-preview",
///     apiKey: "your-azure-key"
/// )
/// 
/// // Local LLM server (like Ollama, LM Studio)
/// let localClient = try LLMClient(
///     baseURL: "http://localhost:8080/v1/chat/completions",
///     apiKey: "not-required-for-local"
/// )
/// ```
///
/// ## Non-Streaming Requests
/// Use ``complete(_:)`` for traditional request-response interactions:
/// ```swift
/// let request = try ChatRequest(model: "gpt-4") {
///     try Temperature(0.7)
///     try MaxTokens(150)
/// } messages: {
///     TextMessage(role: .user, content: "Explain quantum computing")
/// }
/// 
/// let response = try await client.complete(request)
/// if let content = response.choices.first?.message.content {
///     print("Response: \(content)")
/// }
/// ```
///
/// ## Streaming Requests
/// Use ``stream(_:)`` for real-time response generation:
/// ```swift
/// let streamingRequest = try ChatRequest(model: "gpt-4", stream: true) {
///     try Temperature(0.7)
/// } messages: {
///     TextMessage(role: .user, content: "Write a long story")
/// }
/// 
/// for await delta in client.stream(streamingRequest) {
///     if let content = delta.choices.first?.delta.content {
///         print(content, terminator: "")
///     }
/// }
/// ```
///
/// ## Error Handling
/// The client provides detailed error information for robust applications:
/// ```swift
/// do {
///     let response = try await client.complete(request)
///     // Handle success
/// } catch LLMError.rateLimit {
///     // Handle rate limiting
///     print("Rate limit exceeded, please retry later")
/// } catch LLMError.serverError(let statusCode, let message) {
///     // Handle server errors
///     print("Server error \(statusCode): \(message ?? "Unknown")")
/// } catch LLMError.networkError(let description) {
///     // Handle network issues
///     print("Network error: \(description)")
/// } catch {
///     // Handle unexpected errors
///     print("Unexpected error: \(error)")
/// }
/// ```
///
/// ## Session Configuration
/// Customize network behavior with URLSession configuration:
/// ```swift
/// let config = URLSessionConfiguration.default
/// config.timeoutIntervalForRequest = 60
/// config.timeoutIntervalForResource = 300
/// 
/// let client = try LLMClient(
///     baseURL: "https://api.openai.com/v1/chat/completions",
///     apiKey: "your-key",
///     sessionConfiguration: config
/// )
/// ```
///
/// ## Thread Safety
/// As an actor, ``LLMClient`` is inherently thread-safe:
/// ```swift
/// let client = try LLMClient(baseURL: "...", apiKey: "...")
/// 
/// // Safe to call from multiple tasks concurrently
/// async let response1 = client.complete(request1)
/// async let response2 = client.complete(request2)
/// 
/// let (result1, result2) = try await (response1, response2)
/// ```
///
/// ## Provider Compatibility
/// Works with any API that follows the OpenAI Chat Completions format:
/// - OpenAI GPT models
/// - Azure OpenAI Service
/// - Anthropic Claude (with compatible wrapper)
/// - Local servers (Ollama, LM Studio, etc.)
/// - Custom API implementations
///
/// The client handles authentication via Bearer token and expects standard JSON responses.
@available(macOS 12.0, iOS 15.0, *)
public actor LLMClient {
	/// The base URL for the chat completions endpoint
	private let baseURL: String
	/// API key for authentication
	private let apiKey: String
	/// URLSession for network requests
	private let session: URLSession
	
	/// Creates a new LLM client for making chat completion requests.
	///
	/// The client is configured with a base URL pointing to a chat completions endpoint
	/// and an API key for authentication. It supports any OpenAI-compatible API.
	///
	/// ## Supported Providers
	/// Configure for different LLM providers by adjusting the base URL:
	/// 
	/// **OpenAI:**
	/// ```swift
	/// let client = try LLMClient(
	///     baseURL: "https://api.openai.com/v1/chat/completions",
	///     apiKey: "sk-..."
	/// )
	/// ```
	/// 
	/// **Azure OpenAI:**
	/// ```swift
	/// let client = try LLMClient(
	///     baseURL: "https://your-resource.openai.azure.com/openai/deployments/gpt-4/chat/completions?api-version=2023-12-01-preview",
	///     apiKey: "your-azure-key"
	/// )
	/// ```
	/// 
	/// **Local Development:**
	/// ```swift
	/// let client = try LLMClient(
	///     baseURL: "http://localhost:8080/v1/chat/completions",
	///     apiKey: "optional-for-local"
	/// )
	/// ```
	///
	/// ## Session Configuration
	/// Customize network behavior for your specific needs:
	/// ```swift
	/// let config = URLSessionConfiguration.default
	/// config.timeoutIntervalForRequest = 30
	/// config.timeoutIntervalForResource = 600
	/// 
	/// let client = try LLMClient(
	///     baseURL: "https://api.openai.com/v1/chat/completions",
	///     apiKey: "your-key",
	///     sessionConfiguration: config
	/// )
	/// ```
	///
	/// - Parameters:
	///   - baseURL: Complete endpoint URL for chat completions (cannot be empty)
	///   - apiKey: API key for Bearer token authentication
	///   - sessionConfiguration: URLSession configuration (defaults to .default)
	/// - Throws: ``LLMError/missingBaseURL`` if baseURL is empty
	public init(baseURL: String, apiKey: String, sessionConfiguration: URLSessionConfiguration = .default) throws {
		guard !baseURL.isEmpty else {
			throw LLMError.missingBaseURL
		}
		
		self.baseURL = baseURL
		self.apiKey = apiKey
		self.session = URLSession(configuration: sessionConfiguration)
	}
	
	/// Sends a non-streaming chat completion request and returns the complete response.
	///
	/// Use this method for traditional request-response interactions where you need
	/// the complete response before proceeding. This is ideal for short responses,
	/// batch processing, or when you need to analyze the full response content.
	///
	/// ## Example Usage
	/// ```swift
	/// let request = try ChatRequest(model: "gpt-4") {
	///     try Temperature(0.7)
	///     try MaxTokens(200)
	/// } messages: {
	///     TextMessage(role: .user, content: "Explain photosynthesis briefly")
	/// }
	/// 
	/// do {
	///     let response = try await client.complete(request)
	///     
	///     if let content = response.choices.first?.message.content {
	///         print("Response: \(content)")
	///     }
	///     
	///     // Access usage statistics
	///     if let usage = response.usage {
	///         print("Tokens used: \(usage.totalTokens)")
	///     }
	/// } catch {
	///     print("Request failed: \(error)")
	/// }
	/// ```
	///
	/// ## Response Structure
	/// The response contains one or more choices with the model's output:
	/// ```swift
	/// let response = try await client.complete(request)
	/// 
	/// for (index, choice) in response.choices.enumerated() {
	///     print("Choice \(index): \(choice.message.content)")
	///     print("Finish reason: \(choice.finishReason ?? "unknown")")
	/// }
	/// ```
	///
	/// ## Error Handling
	/// The method provides detailed error information for proper handling:
	/// ```swift
	/// do {
	///     let response = try await client.complete(request)
	/// } catch LLMError.rateLimit {
	///     // Implement retry logic with exponential backoff
	/// } catch LLMError.serverError(let statusCode, let message) {
	///     // Handle specific server errors
	/// } catch LLMError.networkError(let description) {
	///     // Handle connectivity issues
	/// }
	/// ```
	///
	/// - Parameter request: The chat completion request to send
	/// - Returns: Complete chat response with all choices and metadata
	/// - Throws: ``LLMError`` for various failure scenarios including network, server, and encoding errors
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
	
	/// Creates a streaming chat completion request that yields partial responses in real-time.
	///
	/// Use this method for interactive applications where you want to display the response
	/// as it's being generated. This provides a better user experience for long responses
	/// and allows for real-time interaction patterns.
	///
	/// ## Basic Streaming Usage
	/// ```swift
	/// let request = try ChatRequest(model: "gpt-4", stream: true) {
	///     try Temperature(0.7)
	///     try MaxTokens(500)
	/// } messages: {
	///     TextMessage(role: .user, content: "Write a detailed explanation of machine learning")
	/// }
	/// 
	/// print("AI: ", terminator: "")
	/// for await delta in client.stream(request) {
	///     if let content = delta.choices.first?.delta.content {
	///         print(content, terminator: "")
	///         fflush(stdout)  // Ensure immediate output
	///     }
	///     
	///     // Check for completion
	///     if let finishReason = delta.choices.first?.finishReason {
	///         print("\n[Finished: \(finishReason)]")
	///         break
	///     }
	/// }
	/// ```
	///
	/// ## Building Complete Responses
	/// Accumulate delta content to build the full response:
	/// ```swift
	/// var fullResponse = ""
	/// 
	/// for await delta in client.stream(request) {
	///     if let content = delta.choices.first?.delta.content {
	///         fullResponse += content
	///         updateUI(with: fullResponse)  // Update UI incrementally
	///     }
	///     
	///     if delta.choices.first?.finishReason != nil {
	///         saveResponse(fullResponse)  // Save complete response
	///         break
	///     }
	/// }
	/// ```
	///
	/// ## Interactive Chat Interface
	/// Perfect for building chat applications:
	/// ```swift
	/// func streamResponse(to userMessage: String) async {
	///     conversation.addUser(content: userMessage)
	///     
	///     let request = try conversation.request(model: "gpt-4", stream: true) {
	///         try Temperature(0.7)
	///     }
	///     
	///     var assistantResponse = ""
	///     
	///     for await delta in client.stream(request) {
	///         if let content = delta.choices.first?.delta.content {
	///             assistantResponse += content
	///             displayTypingEffect(content)
	///         }
	///         
	///         if delta.choices.first?.finishReason != nil {
	///             conversation.addAssistant(content: assistantResponse)
	///             break
	///         }
	///     }
	/// }
	/// ```
	///
	/// ## Error Handling in Streams
	/// The stream handles errors gracefully by terminating:
	/// ```swift
	/// for await delta in client.stream(request) {
	///     // Process delta...
	/// }
	/// // Stream automatically ends on errors or completion
	/// ```
	///
	/// ## Server-Sent Events (SSE)
	/// The method handles the SSE protocol automatically:
	/// - Parses `data:` lines from the stream
	/// - Handles `[DONE]` completion signals
	/// - Decodes JSON delta objects
	/// - Yields ``ChatDelta`` objects with incremental content
	///
	/// ## Performance Considerations
	/// - Streaming reduces perceived latency for long responses
	/// - Memory efficient as it doesn't buffer the entire response
	/// - Allows for early termination if needed
	/// - Provides real-time user feedback
	///
	/// ## Stream Lifecycle
	/// 1. Request is sent with `stream: true`
	/// 2. Server responds with SSE stream
	/// 3. Delta objects are yielded as they arrive
	/// 4. Stream ends when `[DONE]` is received or error occurs
	///
	/// - Parameter request: The chat completion request (should have `stream: true`)
	/// - Returns: AsyncStream yielding ``ChatDelta`` objects with incremental response content
	/// 
	/// - Note: This method is `nonisolated` for optimal streaming performance while maintaining thread safety.
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
