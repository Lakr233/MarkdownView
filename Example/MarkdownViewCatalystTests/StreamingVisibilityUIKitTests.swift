@testable import MarkdownView
import Combine
import MarkdownParser
import SwiftUI
import Testing
import UIKit

/// The demo's own setup on UIKit: a SwiftUI `ScrollView` around a
/// `MarkdownView`, fed one character at a time and throttled as shipped.
/// Every code block and table must be on screen once the stream ends.
@MainActor
struct StreamingVisibilityUIKitTests {
    @MainActor
    final class Feed: ObservableObject {
        @Published var text = ""
    }

    struct Host: View {
        @ObservedObject var feed: Feed
        var body: some View {
            ScrollView {
                MarkdownView(feed.text)
                    .padding()
            }
        }
    }

    private static func exampleDocument() throws -> String {
        let bundle = Bundle(for: BundleToken.self)
        let url = try #require(bundle.url(forResource: "ExampleDocument", withExtension: "md"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private final class BundleToken {}

    private static func spin(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private static func markdownTextView(in view: UIView) -> MarkdownTextView? {
        var queue = [view]
        while !queue.isEmpty {
            let next = queue.removeFirst()
            if let match = next as? MarkdownTextView { return match }
            queue.append(contentsOf: next.subviews)
        }
        return nil
    }

    static func problems(in view: MarkdownTextView) -> [String] {
        var problems: [String] = []
        let runs = view.textLabelView.layoutRuns(matching: .contextView)
        let placed = Set(runs.compactMap { ($0.attributes[.contextView] as? UIView).map(ObjectIdentifier.init) })
        for (index, shown) in view.contextViews.enumerated() {
            let name = "\(type(of: shown)) #\(index)"
            if shown.superview !== view { problems.append("\(name) is detached") }
            if shown.isHidden { problems.append("\(name) is hidden") }
            if !placed.contains(ObjectIdentifier(shown)) { problems.append("\(name) has no line in the layout") }
            if shown.frame.height <= 0 || shown.frame.width <= 0 { problems.append("\(name) has no size: \(shown.frame)") }
            if shown.frame.maxY > view.bounds.maxY + 0.5 {
                problems.append("\(name) sits past the bottom: \(shown.frame) in \(view.bounds)")
            }
        }
        return problems
    }

    @Test("Streaming the demo through SwiftUI ends with every block on screen", arguments: [1, 4])
    func swiftUIStreamEndsWithEveryBlockShown(step: Int) async throws {
        let document = try Self.exampleDocument()
        let feed = Feed()
        let controller = UIHostingController(rootView: Host(feed: feed))
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = .init(x: 0, y: 0, width: 1000, height: 700)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let characters = Array(document)
        var end = 0
        while end < characters.count {
            end = min(characters.count, end + step)
            feed.text = String(characters[0 ..< end])
            await Self.spin(0.0005)
        }
        // Let the throttle deliver the last update and the host settle.
        await Self.spin(0.5)
        window.layoutIfNeeded()
        await Self.spin(0.1)

        let view = try #require(Self.markdownTextView(in: controller.view))
        #expect(view.contextViews.compactMap { $0 as? TableView }.count == 3)
        #expect(view.contextViews.compactMap { $0 as? CodeView }.count == 3)
        let problems = Self.problems(in: view)
        #expect(problems.isEmpty, "\(problems)")
    }

    /// An update that leaves the height alone gets no second layout pass from
    /// its host. iOS 18 clears the label's pending layout before the view lays
    /// out, so the view has to lay the label out itself or read a layout with
    /// no lines and hide every block.
    @Test("An update that keeps the height keeps every block on screen")
    func sameHeightUpdateKeepsBlocks() async throws {
        let document = try Self.exampleDocument()
        let view = MarkdownTextView()
        let controller = UIViewController()
        controller.view.addSubview(view)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = .init(x: 0, y: 0, width: 800, height: 700)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        view.setContentImmediately(.init(parserResult: MarkdownParser().parse(document), theme: .default))
        let height = view.boundingSize(for: 800).height + 200
        view.frame = .init(x: 0, y: 0, width: 800, height: height)
        let characters = Array(document)
        for end in stride(from: characters.count - 40, through: characters.count, by: 4) {
            // The frame stays put: the text grows within the room it has.
            view.setContentImmediately(.init(
                parserResult: MarkdownParser().parse(String(characters[0 ..< end])),
                theme: .default
            ))
            await Self.spin(0.02)
            let problems = Self.problems(in: view)
            #expect(problems.isEmpty, "after \(end) characters: \(problems)")
            if !problems.isEmpty { return }
        }
    }
}
