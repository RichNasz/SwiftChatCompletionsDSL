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
	],
	dependencies: [
		.package(url: "https://github.com/RichNasz/SwiftChatCompletionsMacros.git", from: "0.1.1"),
	],
	targets: [
		.target(
			name: "SwiftChatCompletionsDSL",
			dependencies: [
				.product(name: "SwiftChatCompletionsMacros", package: "SwiftChatCompletionsMacros"),
			]
		),
		.testTarget(
			name: "SwiftChatCompletionsDSLTests",
			dependencies: ["SwiftChatCompletionsDSL"]
		),
	]
)
