//
//  ContentView.swift
//  ExampleWatch Watch App
//

import SwiftUI
import WatchMarkdownView

struct ContentView: View {
    private let outputAnchor = "stream-output"

    @State private var markdownText: String = ""
    @State private var playing = false

    private var displayMarkdown: String {
        markdownText.completedForStreamingPreview()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .center, spacing: 12) {
                    WatchMarkdownView(markdown: displayMarkdown)
                        .id(displayMarkdown)
                    
                        if playing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Button {
                                startStreaming(with: proxy)
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }

                }
                .padding()
            }
            .navigationTitle("MarkdownView")
        }
    }

    @MainActor
    private func startStreaming(with proxy: ScrollViewProxy) {
        guard !playing else { return }

        markdownText = ""
        playing = true

        Task {
            var copy = document
            while !copy.isEmpty {
                try? await Task.sleep(for: .milliseconds(35))
                let chunk = String(copy.prefix(4))
                copy.removeFirst(min(4, copy.count))
                await MainActor.run {
                    markdownText += chunk
                }
            }
            await MainActor.run {
                playing = false
            }
        }
    }
}

#Preview {
    ContentView()
}

private extension String {
    func completedForStreamingPreview() -> String {
        let fenceCount = split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .count(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("```")
        })

        guard !fenceCount.isMultiple(of: 2) else {
            return self
        }
        return self + "\n```"
    }
}
