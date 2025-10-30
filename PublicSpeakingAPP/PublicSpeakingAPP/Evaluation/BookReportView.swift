//
//  BookReportView.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 30/10/25.
//

import SwiftUI
import AVFoundation

// MARK: - Page scrape modifier (single-direction: scrapes DOWN)
struct PageScrapeModifier: AnimatableModifier {
    // 0 = flat (identity), 1 = fully scraped-down (rotated + offset)
    var pct: CGFloat

    var animatableData: CGFloat {
        get { pct }
        set { pct = newValue }
    }

    func body(content: Content) -> some View {
        // Always rotate/offset downward (positive values)
        let rotation = Double(pct * 65) // degrees
        let offsetY = pct * 300.0       // move downwards
        let alpha = Double(1 - pct * 0.3)

        return content
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 1, y: 0, z: 0),
                anchor: .top,
                perspective: 0.7
            )
            .offset(y: offsetY)
            .opacity(alpha)
    }
}

extension AnyTransition {
    // Forward transition: old page scrapes DOWN (removal), new page appears upright (insertion = identity)
    static var pageScrapeForward: AnyTransition {
        .asymmetric(
            insertion: .identity,
            removal: .modifier(
                active: PageScrapeModifier(pct: 1.0),
                identity: PageScrapeModifier(pct: 0.0)
            )
        )
    }

    // Backward transition: new page is inserted from scraped DOWN state (insertion = rotated->flat),
    // old page simply disappears (removal = identity or fade)
    static var pageScrapeBackward: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: PageScrapeModifier(pct: 1.0), // start rotated/down
                identity: PageScrapeModifier(pct: 0.0) // end flat
            ),
            removal: .identity
        )
    }

    // Convenience chooser:
    static func pageScrape(forward: Bool) -> AnyTransition {
        forward ? .pageScrapeForward : .pageScrapeBackward
    }
}



// MARK: - NotebookPlayerView (main container)
struct NotebookPlayerView: View {
    let pages: [String] = [
        "Tempo - A\n\nThis is the content for Tempo - A.\nLine breaks and formatting work.",
        "Tempo - B\n\nNotes for Tempo - B.",
        "Tempo - C\n\nThird page content."
    ]
    
    @State private var isGoingForward = true
    @State private var currentPage = 0
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var animationAmount: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 20) {
                // Left button
                Button(action: previousPage) {
                    Image(systemName: "chevron.left")
                        .font(.largeTitle)
                }
                .disabled(currentPage == 0)
                
                // Paper area
                ZStack {
                    ForEach(Array(pages.indices), id: \.self) { index in
                        if index >= currentPage {
                            let isCurrent = index == currentPage
                            let rotation = isCurrent ? 0.0 : -6.0
                            let offsetY = CGFloat(index - currentPage) * 8
                            let scale = isCurrent ? 1.0 : 0.98
                            let zIndexValue = Double(pages.count - index)
                            let idValue: AnyHashable = isCurrent ? UUID() : index

                            NotebookPageView(
                                pageContent: pages[index],
                                isCurrent: isCurrent
                            )
                            .rotationEffect(.degrees(rotation))
                            .offset(y: offsetY)
                            .scaleEffect(scale)
                            .zIndex(zIndexValue)
                            .id(idValue)
                            .transition(.pageScrape(forward: isGoingForward))
                            .animation(.easeInOut(duration: 0.6), value: currentPage)
                        }
                    }
                }

                .frame(width: geo.size.width * 0.58, height: geo.size.height * 0.9)
                .clipped()
                
                // Right button
                Button(action: nextPage) {
                    Image(systemName: "chevron.right")
                        .font(.largeTitle)
                }
                .disabled(currentPage == pages.count - 1)
                
                // MP3 Player
                MP3PlayerView(isPlaying: $isPlaying)
                    .frame(width: geo.size.width * 0.25)
            }
            .padding()
        }
        .previewInterfaceOrientation(.landscapeLeft)
        .ignoresSafeArea()
    }

    func nextPage() {
        guard currentPage < pages.count - 1 else { return }
        // set direction BEFORE changing page so transition knows which to use
        isGoingForward = true
        withAnimation(.easeInOut(duration: 0.6)) {
            currentPage += 1
        }
    }

    func previousPage() {
        guard currentPage > 0 else { return }
        // set direction BEFORE changing page so insertion uses the backward transition
        isGoingForward = false
        withAnimation(.easeInOut(duration: 0.6)) {
            currentPage -= 1
        }
    }

}


// MARK: - Notebook page view that overlays SwiftUI content on the 'paper' asset
struct NotebookPageView: View {
    let pageContent: String
    var isCurrent: Bool = true

    var body: some View {
        ZStack {
            // Background paper
            Image("Page")
                .resizable()
                .scaledToFit()
                .shadow(color: .black.opacity(isCurrent ? 0.2 : 0.05), radius: isCurrent ? 6 : 2, y: isCurrent ? 4 : 1)

            // SwiftUI content overlay
            VStack(alignment: .leading, spacing: 8) {
                Text(pageTitle(from: pageContent))
                    .font(.title2)
                    .bold()
                    .foregroundColor(.blue)
                Text(pageBody(from: pageContent))
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(EdgeInsets(top: 28, leading: 26, bottom: 28, trailing: 26))
        }
    }

    // Split title/body helpers
    private func pageTitle(from text: String) -> String {
        text.components(separatedBy: "\n").first ?? text
    }

    private func pageBody(from text: String) -> String {
        var comps = text.components(separatedBy: "\n")
        if comps.count > 1 {
            comps.removeFirst()
            return comps.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return ""
        }
    }
}


// MARK: - MP3 Player + Waveform (unchanged structure; uses 'group100' asset)
struct MP3PlayerView: View {
    @Binding var isPlaying: Bool
    @State private var wavePhase = 0.0
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            Image("MP3")
                .resizable()
                .scaledToFit()
                .overlay(
                    VStack {
                        if isPlaying {
                            WaveformView(phase: wavePhase)
                                .frame(height: 40)
                                .onReceive(timer) { _ in
                                    withAnimation(.linear(duration: 0.05)) {
                                        wavePhase += 0.12
                                    }
                                }
                        }
                        Button(action: { isPlaying.toggle() }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 40))
                        }
                    }
                    .padding()
                )
        }
    }
}

struct WaveformView: View {
    var phase: Double

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height
                let midY = height / 2
                for x in stride(from: 0, to: Double(width), by: 2) {
                    let relativeX = x / Double(width)
                    let sine = sin(relativeX * 10 * .pi + phase)
                    path.move(to: CGPoint(x: x, y: Double(midY)))
                    path.addLine(to: CGPoint(x: x, y: Double(midY) - sine * 10.0))
                }
            }
            .stroke(.primary, lineWidth: 2)
        }
    }
}

// MARK: - Preview
#Preview {
    NotebookPlayerView()
}
