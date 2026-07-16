# Swift Code Style Guidelines

## Verify Build
- You must build with `xcodebuild` on `Example/Example.xcworkspace` with scheme `Example` and target `Mac Catalyst`.
- You must use `xcbeautify` to save your context and tokens.

## Core Style
- **Indentation**: 4 spaces
- **Braces**: Opening brace on same line
- **Spacing**: Single space around operators and commas
- **Naming**: PascalCase for types, camelCase for properties/methods

## File Organization
- Logical directory grouping
- PascalCase files for types, `+` for extensions
- Modular design with extensions

## Modern Swift Features
- **@Observable macro**: Replace `ObservableObject`/`@Published`
- **Swift concurrency**: `async/await`, `Task`, `actor`, `@MainActor`
- **Result builders**: Declarative APIs
- **Property wrappers**: Use line breaks for long declarations
- **Opaque types**: `some` for protocol returns

## Code Structure
- Early returns to reduce nesting
- Guard statements for optional unwrapping
- Single responsibility per type/extension
- Value types over reference types

## Error Handling
- `Result` enum for typed errors
- `throws`/`try` for propagation
- Optional chaining with `guard let`/`if let`
- Typed error definitions

## Architecture
- Avoid using protocol-oriented design unless necessary
- Dependency injection over singletons
- Composition over inheritance
- Factory/Repository patterns
- For Markdown tables, map web logical pixels directly to native points while preserving theme typography and dynamic colors; carry parser-provided column alignment through to each native cell, and derive viewport-filling widths from bounded natural column widths.
- Derive table cell vertical placement from the resolved row height, and regression-test rendered corner radius, background colors, and stripe layers whenever table layout changes.
- Keep a table's natural content width inside its horizontal scroll view; the outer table view exposes intrinsic height only so host windows remain horizontally resizable.

## Debug Assertions
- Use `assert()` for development-time invariant checking
- Use `assertionFailure()` for unreachable code paths
- Assertions removed in release builds for performance
- Precondition checking with `precondition()` for fatal errors

## Memory Management
- `weak` references for cycles
- `unowned` when guaranteed non-nil
- Capture lists in closures
- `deinit` for cleanup
