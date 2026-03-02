//
//  MacrosBridge.swift
//  SwiftChatCompletionsDSLMacros
//
//  Bridge between SwiftChatCompletionsMacros and SwiftChatCompletionsDSL types.
//

import Foundation
import SwiftChatCompletionsDSL
import SwiftChatCompletionsMacros

// MARK: - JSONSchema Conversion

extension JSONSchema {
	/// Creates a DSL JSONSchema from a macros package JSONSchemaValue.
	/// - Parameter schemaValue: The macros package schema value to convert
	public init(from schemaValue: JSONSchemaValue) {
		switch schemaValue {
		case .object(let properties, let required):
			var converted: [String: JSONSchema] = [:]
			for (key, value) in properties {
				converted[key] = JSONSchema(from: value)
			}
			self = .object(properties: converted, required: required)

		case .array(let items):
			self = .array(items: JSONSchema(from: items))

		case .string(let description, let enumValues):
			self = .string(description: description, enumValues: enumValues)

		case .integer(let description, let minimum, let maximum):
			self = .integer(description: description, minimum: minimum, maximum: maximum)

		case .number(let description, let minimum, let maximum):
			self = .number(description: description, minimum: minimum, maximum: maximum)

		case .boolean(let description):
			self = .boolean(description: description)
		}
	}
}

// MARK: - Tool Conversion

extension Tool {
	/// Creates a DSL Tool from a macros package ToolDefinition.
	/// - Parameter definition: The macros package tool definition to convert
	public init(from definition: ToolDefinition) {
		self.init(
			function: Tool.Function(
				name: definition.name,
				description: definition.description,
				parameters: JSONSchema(from: definition.parameters)
			)
		)
	}
}

// MARK: - AgentTool Conversion

extension AgentTool {
	/// Creates an AgentTool from a ChatCompletionsTool instance.
	///
	/// This bridges macro-generated tool types with the Agent system.
	/// The tool's `call(arguments:)` method is wrapped to handle JSON
	/// argument decoding and result extraction.
	///
	/// - Parameter instance: An instance of the ChatCompletionsTool conforming type
	public init<T: ChatCompletionsTool>(_ instance: T) {
		let definition = T.toolDefinition
		let tool = Tool(from: definition)
		self.init(tool: tool) { argumentsJSON in
			guard let data = argumentsJSON.data(using: .utf8) else {
				throw LLMError.decodingFailed("Failed to convert arguments to data")
			}
			let args = try JSONDecoder().decode(T.Arguments.self, from: data)
			let output = try await instance.call(arguments: args)
			return output.content
		}
	}
}
