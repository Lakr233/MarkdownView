# AGENTS.md — MarkdownView

A native markdown renderer (AppKit/UIKit text views behind a SwiftUI wrapper),
used as the chat transcript's text engine in the AirBuild app. It is consumed
there as a **released SPM version**, so a fix for that app is: land here, tag,
then bump the app's `Package.resolved`.

## Verify

- `Script/test.sh` is the build gate: it builds the `Example` scheme in
  `Example/Example.xcworkspace` across macOS, **Mac Catalyst**, iOS, iOS
  Simulator, xrOS and xrOS Simulator. All six must pass — this package ships on
  all of them, and the platform splits are where it breaks.
- `swift test` runs `MarkdownParserTests` and `MarkdownViewTests`.
- Pipe `xcodebuild` through `xcbeautify` to save context and tokens.
- **Performance claims are measured, not asserted.** `MarkdownViewBenchmark` is
  an executable target; compare `op_ms` (it divides by the sub-operations one
  iteration performs, so a 120-update stream and a single render are on the
  same scale) before and after, and say which case moved.

## Rendering invariants

Earned the hard way during the August 2026 streaming work; breaking one of
these shows up in the host app as dropped frames while an answer streams, not
as a failing test.

- **A rebuild only rebuilds what changed.** A streamed answer rebuilds the whole
  document per token, so all but the last block would otherwise be rebuilt to
  the same bytes. `BlockFragmentCache` keeps each block's attributed string
  across rebuilds, matched on **position and node together** — never the node
  alone, or two identical blockquotes would share one group and paint a single
  bar through the paragraph between them. Anything not per-block is decided once
  in `isUsable(with:for:)`, so an unusable cache costs one comparison, not one
  per block.
- **Theme and content are set in one build.** Two passes mean two layouts and a
  visible correction.
- **Resolve fallback fonts only where the document changed**, and drop the
  language attribute once it has chosen a font.
- **Async work reports completion narrowly**: a view is told *which* code block
  finished highlighting; a table that already shows a value says so rather than
  re-rendering. Keep a stale highlight on screen while a fresh map is pending.
- **SwiftUI two-phase layout is answered synchronously.** The representable
  reports its size from `sizeThatFits(_:)`; do not mirror a measured height into
  SwiftUI state and feed it back through `frame(minHeight:)` — that is a second
  layout pass on every content change. Deferred applies re-enter layout through
  `invalidateIntrinsicContentSize`. Zero-width probes get a zero minimum width;
  other probes get the last concrete width.

## Swift code style

### Core Style
- **Indentation**: 4 spaces
- **Braces**: Opening brace on same line
- **Spacing**: Single space around operators and commas
- **Naming**: PascalCase for types, camelCase for properties/methods

### File Organization
- Logical directory grouping
- PascalCase files for types, `+` for extensions
- Modular design with extensions

### Modern Swift Features
- **@Observable macro**: Replace `ObservableObject`/`@Published`
- **Swift concurrency**: `async/await`, `Task`, `actor`, `@MainActor`
- **Result builders**: Declarative APIs
- **Property wrappers**: Use line breaks for long declarations
- **Opaque types**: `some` for protocol returns

### Code Structure
- Early returns to reduce nesting
- Guard statements for optional unwrapping
- Single responsibility per type/extension
- Value types over reference types

### Error Handling
- `Result` enum for typed errors
- `throws`/`try` for propagation
- Optional chaining with `guard let`/`if let`
- Typed error definitions

### Architecture
- Avoid using protocol-oriented design unless necessary
- Dependency injection over singletons
- Composition over inheritance
- Factory/Repository patterns
- For Markdown tables, map web logical pixels directly to native points while preserving theme typography and dynamic colors; carry parser-provided column alignment through to each native cell, and derive viewport-filling widths from bounded natural column widths.
- Derive table cell vertical placement from the resolved row height, and regression-test rendered corner radius, background colors, and stripe layers whenever table layout changes.
- Keep a table's natural content width inside its horizontal scroll view; the outer table view exposes intrinsic height only so host windows remain horizontally resizable.

### Debug Assertions
- Use `assert()` for development-time invariant checking
- Use `assertionFailure()` for unreachable code paths
- Assertions removed in release builds for performance
- Precondition checking with `precondition()` for fatal errors

### Memory Management
- `weak` references for cycles
- `unowned` when guaranteed non-nil
- Capture lists in closures
- `deinit` for cleanup
