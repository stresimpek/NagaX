//
//  NewEvaluationView.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 05/11/25.
//

import SwiftUI

struct NewEvaluationView: View {
    @StateObject private var viewModel: NewEvaluationViewModel
    
    let onBack: () -> Void
    let onNext: (PracticeSettings) -> Void
    
    init(
        result: EvaluationModel,
        fullTranscript: String,
        sentenceAnalysisResult: String,
        settings: PracticeSettings,
        onBack: @escaping () -> Void,
        onNext: @escaping (PracticeSettings) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: NewEvaluationViewModel(
            result: result,
            fullTranscript: fullTranscript,
            sentenceAnalysisResult: sentenceAnalysisResult,
            settings: settings
        ))
        self.onBack = onBack
        self.onNext = onNext
    }
    
    var body: some View {
        ZStack {
            Image("BG")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)
                .accessibilityHidden(true)
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 49){
                        VStack(spacing: 21){
                            tabsAndPaperSection
                            disclaimerBanner
                        }
                        .padding(.leading, 60)
                        bottomButtons
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                }
                .safeAreaPadding(.horizontal)
            }
        }
        .fullScreenCover(isPresented: $viewModel.showFullScreen) {
            StrukturKalimatFullScreenView(
                showFullScreen: $viewModel.showFullScreen,
                transcript: viewModel.fullTranscript
            )
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private func shouldShowEmptyStateForCurrentTab() -> Bool {
        switch viewModel.currentTab {
        case .artikulasi:
            return viewModel.articulationCalculated && viewModel.articulationCount == 0
        case .fillerWords:
            return viewModel.fillerWordCalculated && viewModel.fillerWordCount == 0
        case .strukturKalimat:
            return viewModel.ineffectiveSentenceCount == 0
        default:
            return false
        }
    }
}

private extension NewEvaluationView {
    var tabsAndPaperSection: some View {
        VStack(spacing: 0) {
            tabsView
                .padding(.bottom, -4)
            
            paperContent
        }.frame(maxWidth: .infinity)
            .padding(.top, 28)
    }
    
    var tabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(viewModel.availableTabs.enumerated()), id: \.offset) { index, tab in
                    Button(action: { viewModel.selectTab(index) }) {
                        Text(viewModel.tabTitle(for: tab))
                            .font(.footnote)
                            .fontWeight(viewModel.selectedTabIndex == index ? .bold : .regular)
                            .foregroundColor(viewModel.selectedTabIndex == index ? Color("BaseColorBrown") : Color("BaseColorBrown"))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 8,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 8
                                )
                                .fill(viewModel.selectedTabIndex == index ? Color("BaseColorWhite") : Color("Beige"))
                            )
                    }
                }
            }
        }
    }
    
    var paperContent: some View {
        VStack(spacing: 0) {
            Divider()
            tabContent
        }
        .background(Color("BaseColorWhite"))
        .shadow(color: .gray.opacity(0.3), radius: 4, x: 0, y: 3)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        EvaluationSectionView(
            evaluatorNote: viewModel.currentEvaluatorNote,
            sectionTitle: viewModel.currentSectionTitle,
            showFullScreen: $viewModel.showFullScreen,
            hasScrollableContent: viewModel.currentHasScrollableContent,
            analysisText: viewModel.sentenceAnalysisResult,
            transcript: viewModel.fullTranscript,
            guidance: viewModel.currentGuidance,
            showEmptyState: shouldShowEmptyStateForCurrentTab(),
            emptyStateMessage: emptyStateMessageForCurrentTab(),
            tabId: "\(viewModel.currentTab)"
        ) {
            contentForCurrentTab
        }
    }
    
    private func emptyStateMessageForCurrentTab() -> String {
        switch viewModel.currentTab {
        case .artikulasi:
            return "Tidak ada artikulasi kurang jelas yang terdeteksi."
        case .fillerWords:
            return "Tidak ada kata jeda yang terdeteksi."
        case .strukturKalimat:
            return "Tidak ada pemborosan kata yang terdeteksi."
        default:
            return ""
        }
    }
    
    @ViewBuilder
    private var contentForCurrentTab: some View {
        switch viewModel.currentTab {
        case .strukturKalimat:
            
            Spacer()
                .frame(maxWidth: .infinity)
                .padding()
            
        case .artikulasi:
            ArticulationTranscriptView(
                fullTranscript: viewModel.fullTranscript,
                onMapsCalculated: { maps, total in
                    viewModel.articulationCount = maps.totalCount
                    viewModel.articulationTotal = total
                    viewModel.articulationCalculated = true
                }
            )
            .padding()
            .accessibilityHidden(true)
        case .fillerWords:
            FillerWordTranscriptView(
                result: viewModel.result,
                fullTranscript: viewModel.fullTranscript,
                onMapsCalculated: { maps in
                    viewModel.fillerWordCount = maps.totalCount
                    viewModel.fillerWordCalculated = true
                }
            )
            .padding()
            .accessibilityHidden(true)
        case .tempo:
            VStack() {
                TempoResultChart(
                    tempoSeries: viewModel.result.tempoSeries,
                    fixedDuration: viewModel.result.durationInSeconds
                )
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding()
        case .intonasi:
            VStack() {
                IntonationResultChart(
                    pitchSeries: viewModel.result.pitchSeries,
                    fixedDuration: viewModel.result.durationInSeconds
                )
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding()
        case .kontakMata:
            EyeContactEvaluationView(
                videoURL: viewModel.result.videoURL,
                gazeEvents: viewModel.result.gazeEvents
            )
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
    
    var disclaimerBanner: some View {
        VStack (alignment: .leading, spacing: 6){
            Text("⚠️ Feedback ini dibuat oleh machine learning")
                .font(.subheadlineBold)
            Text("Cako hanya ngasih insight sebagai alat bantu, tapi tetap kamu yang paling ngerti gaya presentasimu")
                .font(.subheadline)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .foregroundStyle(Color("DarkBlue2"))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.whiteBlue)
            .shadow(color: .lightBlue2, radius: 0, x: 0, y: 4))
    }
    
    var bottomButtons: some View {
        HStack(spacing: 16) {
            ButtonComponent(
                title: "Selesai",
                systemImage: nil,
                size: .medium,
                kind: .secondaryBlue,
                action: onBack
            )
            ButtonComponent(
                title: "Latihan Lagi",
                systemImage: nil,
                size: .medium,
                kind: .primaryYellow,
                action: { onNext(viewModel.settings) }
            )
        }
        .padding(.top, 16)
        .padding(.bottom, 60)
    }
}

struct GuidanceView: View {
    let items: [AttributedString]
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                isExpanded.toggle()
            }) {
                HStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(.cakolightbulb)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                        
                        Text("Tips dari CAKO")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.baseColorBrown)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "minus" : "plus")
                        .foregroundColor(.baseColorBrown)
                        .font(.system(size: 18, weight: .bold))
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        Text("\(index + 1). \(item)")
                            .font(.body)
                            .foregroundColor(.baseColorBrown)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.baseColorWhite.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.brown.opacity(0.5), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct EvaluationSectionView<Content: View>: View {
    let evaluatorNote: AttributedString
    let sectionTitle: String
    @Binding var showFullScreen: Bool
    let hasScrollableContent: Bool
    let content: Content
    let analysisText: String
    let transcript: String
    let guidance: [AttributedString]
    let showEmptyState: Bool
    let emptyStateMessage: String
    @State private var diffComponents: [DiffComponent] = []
    let tabId: String
    
    init(
        evaluatorNote: AttributedString,
        sectionTitle: String,
        showFullScreen: Binding<Bool> = .constant(false),
        hasScrollableContent: Bool,
        analysisText: String = "",
        transcript: String,
        guidance: [AttributedString] = [],
        showEmptyState: Bool = false,
        emptyStateMessage: String = "",
        tabId: String = "",
        @ViewBuilder content: () -> Content
    ) {
        self.evaluatorNote = evaluatorNote
        self.sectionTitle = sectionTitle
        self._showFullScreen = showFullScreen
        self.hasScrollableContent = hasScrollableContent
        self.analysisText = analysisText
        self.transcript = transcript
        self.guidance = guidance
        self.showEmptyState = showEmptyState
        self.emptyStateMessage = emptyStateMessage
        self.tabId = tabId
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack (alignment: .leading){
                Text("Catatan Evaluator:")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.baseColorBrown)
                
                Text(evaluatorNote)
                    .font(.body)
                    .foregroundColor(.darkBlue3)
                    .underline(true, color: Color.baseColorBrown)
                  
            }
            VStack (alignment: .leading){
                Text(sectionTitle)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(Color.baseColorBrown)
                    .accessibilityHidden(true)
                
                if showEmptyState {
                    emptyStateContent
                } else if hasScrollableContent {
                    scrollableContentWithGradient
                } else {
                    staticContent
                }
            }
            
            if !guidance.isEmpty {
                GuidanceView(items: guidance)
                    .id(tabId)
            }
        }
        .padding()
    }
    
    private var emptyStateContent: some View {
            HStack(alignment: .center, spacing: 12) {
                Text(emptyStateMessage)
                    .font(.title3)
                    .foregroundColor(Color.baseColorBrown)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 152.8125, maxHeight: 152.8125, alignment: .center)
            .padding(.horizontal, 50)
            .padding(.vertical, 53)
            .background(Color.yellow2.opacity(0.2))
            .cornerRadius(11.25)
            .overlay(
                RoundedRectangle(cornerRadius: 11.25)
                    .stroke(Color.brown.opacity(0.4), lineWidth: 0.9375)
            )
        }
    
    private var scrollableContentWithGradient: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                if transcript.isEmpty {
                    Text("Tidak ada transkrip yang terekam.")
                        .font(.body)
                        .foregroundColor(.baseColorBrown)
                        .padding()
                    
                } else {
                    if !diffComponents.isEmpty {
                        DiffRenderView(components: diffComponents)
                    } else {
                        Text("\(transcript)")
                            .font(.body)
                            .foregroundColor(.baseColorBrown)
                            .padding()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.brown.opacity(0.5), lineWidth: 1)
        )
        .onAppear {
            diffComponents = DiffComponent.generate(original: transcript, new: analysisText)
        }
    }
    
    private var staticContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.brown.opacity(0.5), lineWidth: 1)
        )
    }
    
    
}

struct StrukturKalimatFullScreenView: View {
    @Binding var showFullScreen: Bool
    let transcript: String
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("BaseColorWhite")
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(transcript.isEmpty ? "Tidak ada transkrip yang terekam." : transcript)
                            .font(.body)
                            .foregroundColor(Color("BaseColorBrown"))
                            .padding()
                    }
                    .padding(.top, 10)
                }
            }
            .toolbar {
                Button("Tutup") {
                    showFullScreen = false
                }
                .foregroundColor(.blue)
            }
        }
    }
}

struct DiffRenderView: View {
    let components: [DiffComponent]
    
    let defaultColor = Color(.baseColorBrown)
    let deletedColor = Color.baseColorRed
    let addedColor = Color.darkBlue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            components.reduce(Text("")) { (result, component) in
                let font: Font = component.type == .same ? .system(.body, design: .serif) : .body.bold()
                
                let styledText = Text(component.text)
                    .font(font)
                
                switch component.type {
                case .same:
                    return result + styledText
                        .foregroundColor(defaultColor)
                case .deleted:
                    return result + styledText
                        .foregroundColor(deletedColor)
                        .strikethrough(true, color: deletedColor)
                case .added:
                    return Text("\(result) \(styledText)")
                        .foregroundColor(addedColor)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(generateAccessibilityLabel())
        }
        .lineSpacing(8)
    }
    
    private func generateAccessibilityLabel() -> String {
        return components
            .filter { $0.type != .deleted }
            .map { component -> String in
                if component.type == .added {
                    return " " + component.text
                }
                return component.text
            }
            .joined()
    }
}
