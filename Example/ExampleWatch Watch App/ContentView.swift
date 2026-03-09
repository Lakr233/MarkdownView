//
//  ContentView.swift
//  ExampleWatch Watch App
//

import SwiftUI
import WatchMarkdownView

private let kAnimation = Animation.interpolatingSpring(
    mass: 1,
    stiffness: 170,
    damping: 26,
    initialVelocity: 0
)
private let kScrollAnimationDuration: Duration = .milliseconds(250)
private let kScrollThrottleInterval: Duration = .milliseconds(300)

struct ContentView: View {
    private let outputAnchor = "stream-output"

    @State private var markdownText: String = ""
    @State private var playing = false
    @State private var lastScrollTime = ContinuousClock.now
    @State private var pendingScrollTask: Task<Void, Never>?

    private var displayMarkdown: String {
        markdownText.completedForStreamingPreview()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .center, spacing: 12) {
                    Button {
                        startStreaming(with: proxy)
                    } label: {
                        Circle()
                            .fill(.blue)
                            .frame(width: 52, height: 52)
                            .overlay {
                                if playing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .offset(x: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(playing)

                    WatchMarkdownView(markdown: displayMarkdown)
                        .id(displayMarkdown)

                    Color.clear
                        .frame(height: 1)
                        .id(outputAnchor)

                    Spacer()
                        .frame(width: 128, height: 128, alignment: .center)
                }
                .padding()
            }
            .navigationTitle("MarkdownView")
            .onChange(of: displayMarkdown) {
                guard playing else { return }
                scheduleScroll(with: proxy)
            }
            .onChange(of: playing) {
                guard !playing else { return }
                scheduleScroll(with: proxy, forceFinal: true)
            }
            .onDisappear {
                pendingScrollTask?.cancel()
                pendingScrollTask = nil
            }
        }
    }

    @MainActor
    private func startStreaming(with proxy: ScrollViewProxy) {
        guard !playing else { return }

        pendingScrollTask?.cancel()
        pendingScrollTask = nil
        markdownText = ""
        playing = true
        lastScrollTime = .now
        scrollToBottom(with: proxy)

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

    @MainActor
    private func scheduleScroll(with proxy: ScrollViewProxy, forceFinal: Bool = false) {
        pendingScrollTask?.cancel()

        if forceFinal {
            pendingScrollTask = Task {
                try? await Task.sleep(for: kScrollAnimationDuration)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    scrollToBottom(with: proxy)
                    pendingScrollTask = nil
                }
            }
            return
        }

        let now = ContinuousClock.now
        let elapsed = lastScrollTime.duration(to: now)
        guard elapsed >= kScrollThrottleInterval else {
            pendingScrollTask = Task {
                let delay = kScrollThrottleInterval - elapsed
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    scrollToBottom(with: proxy)
                    pendingScrollTask = nil
                }
            }
            return
        }

        scrollToBottom(with: proxy)
    }

    @MainActor
    private func scrollToBottom(with proxy: ScrollViewProxy) {
        lastScrollTime = .now
        withAnimation(kAnimation) {
            proxy.scrollTo(outputAnchor, anchor: .bottom)
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
