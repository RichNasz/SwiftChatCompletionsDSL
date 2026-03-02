// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "SwiftChatCompletionsDSL",
	platforms: [
		.macOS(.v13),
		.iOS(.v16),
	],
	products: [
		.library(
			name: "SwiftChatCompletionsDSL",
			targets: ["SwiftChatCompletionsDSL"]
		),
		.library(
			name: "SwiftChatCompletionsDSLMacros",
			targets: ["SwiftChatCompletionsDSLMacros"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/RichNasz/SwiftChatCompletionsMacros.git", from: "0.1.0"),
	],
	targets: [
		.target(
			name: "SwiftChatCompletionsDSL"
		),
		.target(
			name: "SwiftChatCompletionsDSLMacros",
			dependencies: [
				"SwiftChatCompletionsDSL",
				.product(name: "SwiftChatCompletionsMacros", package: "SwiftChatCompletionsMacros"),
			]
		),
		.testTarget(
			name: "SwiftChatCompletionsDSLTests",
			dependencies: ["SwiftChatCompletionsDSL"]
		),
	]
)
