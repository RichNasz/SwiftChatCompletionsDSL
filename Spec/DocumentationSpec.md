# Swift Package Documentation Specification: SwiftChatCompletionsDSL

## Overview
This document specifies the documentation requirements for the package named SwiftChatCompletionsDSL

## Requirements
- **Documentation**: Include a README.md with an overview of the project, a summary of what a DSL is, a description of the DSL in the package, and simple usage examples that includes streaming and non-streaming text inference requests. Use DocC for comprehensive documentation, with a `.docc` folder containing articles.

## README.md Structure
The root README.md file must include the following sections in order:

1. **Package Title and Badge Section**
   - Project name and brief tagline
   - Swift version badge, platform badges
   - Build status and documentation links

2. **Overview Section**
   - Clear description of what SwiftChatCompletionsDSL does
   - Brief explanation of what a DSL (Domain Specific Language) is
   - Key benefits and use cases

3. **Quick Start Section**
   - Installation instructions (Swift Package Manager)
   - Minimal working example (< 10 lines of code)
   - Link to comprehensive documentation

4. **Usage Examples Section**
   - Basic non-streaming example with explanation
   - Basic streaming example with explanation
   - Link to Examples/ folder for more complex scenarios

5. **Documentation Links Section**
   - Link to generated DocC documentation
   - Link to DSL guide for beginners
   - Link to architecture documentation

6. **Requirements Section**
   - Swift version requirements
   - Platform support (macOS, iOS versions)
   - Dependencies (if any)

7. **Contributing and License Section**
   - Contribution guidelines
   - License information

## DocC Documentation
Documentation must be generated using DocC, Apple's documentation compiler for Swift. All public APIs in source files must include triple-slash (///) comments structured with Markdown sections (e.g., Summary, Discussion, Parameters, Returns, Throws) as per Apple standards.

**CRITICAL REQUIREMENT**: The documentation must include a comprehensive DSL (Domain Specific Language) guide that makes SwiftChatCompletionsDSL accessible to developers at all experience levels. The DSL documentation is essential for package adoption and significantly lowers the barrier to entry for new users.

Create a DocC catalog in the target source directory: `Sources/SwiftChatCompletionsDSL/SwiftChatCompletionsDSL.docc/`. **Critical**: The catalog must be located within the target's source directory (`Sources/SwiftChatCompletionsDSL/`) for Xcode's DocC plugin to properly associate documentation with the target and build it automatically. This folder contains markdown articles and resources. To build the DocC archive, run:
```bash
swift package generate-documentation --target SwiftChatCompletionsDSL
```
This produces a `.doccarchive` file for hosting or viewing in Xcode/Preview.

### API Documentation Standards
All public APIs must include comprehensive triple-slash comments following this structure:

```swift
/// Brief summary of what the function/type does.
///
/// Detailed discussion explaining the purpose, behavior, and any important
/// implementation details. This section can span multiple paragraphs.
///
/// - Parameters:
///   - parameterName: Description of what this parameter does
///   - anotherParam: Description with constraints or validation rules
/// - Returns: Description of what is returned, including type information
/// - Throws: List of specific errors that can be thrown with descriptions
/// - Note: Additional important information for developers
/// - Warning: Critical warnings about usage or potential issues
///
/// ## Example Usage
/// ```swift
/// let example = try SomeType(parameter: "value")
/// let result = try example.someMethod()
/// ```
public func someMethod(parameter: String) throws -> ResultType {
    // Implementation
}
```

### DocC Catalog Structure
The catalog structure within the target source directory:
```
SwiftChatCompletionsDSL/                           ← Package root
├── Package.swift
├── README.md                                      ← Root README with quick start
├── Sources/
│   └── SwiftChatCompletionsDSL/                   ← Target source directory
│       ├── SwiftChatCompletionsDSL.docc/         ← DocC catalog here (within target)
│       │   ├── SwiftChatCompletionsDSL.md        ← Main documentation file (target-named, includes introduction)
│       │   ├── Architecture.md                   ← Article (standard Markdown format)
│       │   ├── DSL.md                            ← Article (standard Markdown format) - DSL guide for beginners
│       │   ├── Usage.md                          ← Article (standard Markdown format)
│       │   └── Resources/                        ← Images, diagrams, assets
│       │       ├── architecture-diagram.png
│       │       ├── dsl-flow-chart.svg
│       │       └── code-examples/
│       └── ...                                   ← Source files
├── Tests/
└── Examples/
```

### Resource Management Guidelines
The `Resources/` folder within the DocC catalog should organize assets as follows:
- **Images**: Use `.png` for screenshots, `.svg` for diagrams when possible
- **Code Examples**: Store longer code examples in separate files for reuse
- **Naming Convention**: Use kebab-case with descriptive names (e.g., `streaming-example-diagram.png`)
- **File Size**: Optimize images for web viewing (< 500KB recommended)
- **Documentation**: Include alt-text for all images for accessibility

**Important File Naming Convention**: 
- **Main documentation file** must be named after the target (`SwiftChatCompletionsDSL.md`) for proper Xcode DocC plugin integration
- **Articles** use `.md` extension with standard Markdown format (no special directives required)
All conventions conform to Apple's DocC standards for optimal developer documentation generation.

**Required Documentation Articles**:
- **SwiftChatCompletionsDSL.md** (REQUIRED): Main target documentation file
- **Architecture.md** (REQUIRED): Technical architecture and design patterns
- **DSL.md** (REQUIRED): Critical beginner-friendly Domain Specific Language guide
- **Usage.md** (REQUIRED): Comprehensive usage examples for all experience levels

**Target Source Directory Location Benefits**:
- **Xcode Integration**: DocC plugin automatically discovers and builds documentation when located in target source directory
- **SPM Compatibility**: `swift package generate-documentation` works seamlessly with target-associated documentation
- **Target Association**: Documentation correctly associates with the SwiftChatCompletionsDSL target by being in its source directory
- **Build Automation**: Documentation builds automatically when building the target in Xcode
- **Source Proximity**: Documentation lives alongside the source code it documents, improving maintainability
- **Distribution Ready**: Generated `.doccarchive` is properly structured for hosting with correct target association

The documentation files should be generated with content that aligns with the package's purpose:

### Documentation Article Specifications

- **SwiftChatCompletionsDSL.md**: Main target documentation with the following structure:
  1. Introduction and overview 
  2. Key benefits and getting started guide
  3. **"Learn More About" section** with cross-references to other articles (placed after introductory content, before Topics section)
  4. **Topics section** organizing all API symbols by category
  5. **See Also section** with article descriptions

- **Architecture.md**: Detailed technical explanations of the package architecture using standard Markdown format:
  - Result Builder Pattern implementation
  - Actor-based concurrency model
  - Type-safe configuration system
  - JSON serialization strategy
  - Error handling patterns
  - Extensibility points for custom messages and parameters

- **DSL.md**: **CRITICAL** beginner-friendly guide to the Domain Specific Language using standard Markdown format. This article is essential for package adoption as it makes SwiftChatCompletionsDSL accessible to developers unfamiliar with DSLs. Must include:
  - What DSLs are and why they matter
  - Step-by-step examples starting with simple workflows
  - Common patterns and best practices
  - Practical code examples without assuming prior DSL knowledge
  - Comparison with traditional API approaches
  - Progressive complexity from basic to advanced usage
  - Troubleshooting common DSL mistakes

- **Usage.md**: Practical examples and code snippets for all experience levels using standard Markdown format:
  - **For Beginners** section with non-technical explanations
  - Basic streaming and non-streaming examples
  - Configuration parameter usage
  - Conversation management patterns
  - Error handling examples
  - **Graduating to Advanced** subsection showing how to use all features of the DSL
  - Custom message and parameter extensions
  - Integration with different LLM providers

**Critical Structure**: The "Learn More About" section in SwiftChatCompletionsDSL.md must come after introductory content but before the Topics section to ensure proper navigation flow for developers browsing the documentation.

### Code Example Standards
All code examples in documentation must follow these standards:

- **Language Tags**: Always specify `swift` for Swift code blocks
- **Complete Examples**: Provide runnable code when possible, not fragments
- **Comments**: Include explanatory comments for complex operations
- **Error Handling**: Show proper error handling patterns
- **Imports**: Include necessary import statements
- **Formatting**: Use consistent indentation (4 spaces) and Swift naming conventions

Example format:
```swift
import SwiftChatCompletionsDSL

// Create a client for OpenAI's API
let client = try LLMClient(
    baseURL: "https://api.openai.com/v1/chat/completions",
    apiKey: "your-api-key-here"
)

// Build a request using the DSL
let request = try ChatRequest(model: "gpt-4") {
    try Temperature(0.7)
    try MaxTokens(150)
} messages: {
    TextMessage(role: .system, content: "You are a helpful assistant.")
    TextMessage(role: .user, content: "Explain async/await in Swift.")
}

// Send the request
let response = try await client.complete(request)
print(response.choices.first?.message.content ?? "No response")
```

### DocC Documentation Generation
- **File Extensions**: Articles use `.md` with standard Markdown format
- **Content Structure**: Use standard Markdown headers, lists, code blocks, and formatting
- **Cross-References**: Use `<doc:FileName>` syntax for linking between documentation files
- **Code Examples**: Include practical code examples directly in Markdown code blocks with proper language tags
- **DSL Documentation**: **MANDATORY** creation of DSL.md article explaining Domain Specific Language concepts with beginner-friendly examples, step-by-step tutorials, and practical code samples
- **Generation Command**: Document generation with `swift package generate-documentation --target SwiftChatCompletionsDSL`

### Version and Release Documentation
- **CHANGELOG.md**: Maintain a changelog following semantic versioning
- **Migration Guides**: Include migration instructions for breaking changes
- **Version Compatibility**: Document Swift and platform version requirements for each release
- **Deprecation Notices**: Clearly mark deprecated APIs with migration paths

### Quality Assurance
- **Link Validation**: Ensure all cross-references and external links work
- **Code Testing**: Verify all code examples compile and run correctly
- **Accessibility**: Include alt-text for images and diagrams
- **Consistency**: Maintain consistent terminology and formatting throughout
- **Review Process**: Documentation changes should be reviewed alongside code changes