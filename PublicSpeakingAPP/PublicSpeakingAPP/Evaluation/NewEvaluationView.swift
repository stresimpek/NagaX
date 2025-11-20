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
        // MARK: - Trigger Delete on Disappear
        .onDisappear {
            viewModel.deleteVideoFile()
        }
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
                            .font(.system(size: 13, weight: viewModel.selectedTabIndex == index ? .bold : .regular))
                            .foregroundColor(viewModel.selectedTabIndex == index ? Color("BaseColorBrown") : Color("BaseColorBrown").opacity(0.3))
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
            emptyStateMessage: emptyStateMessageForCurrentTab()
        ) {
            contentForCurrentTab
        }
    }
    
    private func emptyStateMessageForCurrentTab() -> String {
        switch viewModel.currentTab {
        case .artikulasi:
            return "TIDAK ADA ARTIKULASI KURANG JELAS YANG TERDETEKSI SELAMA KAMU PRESENTASI"
        case .fillerWords:
            return "TIDAK ADA KATA JEDA YANG TERDETEKSI SELAMA KAMU PRESENTASI"
        case .strukturKalimat:
            return "TIDAK ADA PEMBOROSAN KATA YANG TERDETEKSI DALAM PRESENTASIMU"
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
        case .fillerWords:
            FillerWordTranscriptView(
                result: viewModel.result,
                fullTranscript: viewModel.fullTranscript,
                onMapsCalculated: { maps in
                    viewModel.fillerWordCount = maps.totalCount
                    viewModel.fillerWordCalculated = true
                }
            ).padding()
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
            // MARK: - FIX DI SINI
            // Mempassing parameter gazeEvents agar fitur 'Jump' berfungsi
            EyeContactEvaluationView(
                videoURL: viewModel.result.videoURL,
                gazeEvents: viewModel.result.gazeEvents
            )
            .padding()
        }
    }
    
    var disclaimerBanner: some View {
        VStack (alignment: .leading, spacing: 6){
            Text("⚠️ Feedback ini dibuat oleh machine learning")
                .font(.custom("Nunito-Black", size: 13))
            Text("Cako hanya ngasih insight sebagai alat bantu, tapi tetap kamu yang paling ngerti gaya presentasimu")
                .font(.custom("Nunito-Medium", size: 11))
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
                title: "SELESAI",
                systemImage: nil,
                size: .largeIconCircle,
                kind: .secondaryBlue,
                action: onBack
            )
            ButtonComponent(
                title: "LATIHAN LAGI",
                systemImage: nil,
                size: .largeIconCircle,
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
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(.lightbulb)
                .foregroundColor(.yellow)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Text("\(index + 1). \(item)")
                        .font(.body)
                        .foregroundColor(.baseColorBrown)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.baseColorWhite.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.brown.opacity(0.5), lineWidth: 1)
        )
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
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Catatan Evaluator:")
                .font(.footnoteBold)
                .foregroundColor(.baseColorBrown)
            
            Text(evaluatorNote)
                .font(.body)
                .foregroundColor(.darkBlue2)
                .underline(true, color: Color.baseColorBrown)
            
            Text(sectionTitle)
                .font(.footnoteBold)
                .foregroundColor(Color.baseColorBrown)
            
            if showEmptyState {
                            emptyStateContent
                        } else if hasScrollableContent {
                            scrollableContentWithGradient
                        } else {
                            staticContent
                        }
            Text("Guidance:")
                .font(.footnoteBold)
                .foregroundColor(.baseColorBrown)
            
            if !guidance.isEmpty {
                GuidanceView(items: guidance)
            }
        }
        .padding()
    }
    
    private var emptyStateContent: some View {
            HStack(alignment: .center, spacing: 12) {
                Text(emptyStateMessage)
                    .font(.title3)
                    .foregroundColor(Color.baseColorBrown.opacity(0.5))
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
        .frame(maxWidth: .infinity, minHeight: 240)
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
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .leading)
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
    let deletedColor = Color.red
    let addedColor = Color.blue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            components.reduce(Text("")) { (result, component) in
                let styledText = Text(component.text)
                    .font(.body)
                
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
        }
        .font(.body)
        .lineSpacing(8)
    }
}
