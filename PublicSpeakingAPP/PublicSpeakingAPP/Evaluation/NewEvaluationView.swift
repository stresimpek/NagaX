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
        settings: PracticeSettings,
        onBack: @escaping () -> Void,
        onNext: @escaping (PracticeSettings) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: NewEvaluationViewModel(
            result: result,
            fullTranscript: fullTranscript,
            settings: settings
        ))
        self.onBack = onBack
        self.onNext = onNext
    }
    
    var body: some View {
        ZStack {
            Color("BaseColorBlue")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    tabsAndPaperSection
                    bottomButtons
                }
                .padding(.horizontal, 16)
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
}

private extension NewEvaluationView {
    var tabsAndPaperSection: some View {
        GeometryReader { geometry in
            let paperWidth = geometry.size.width - 25
            
            VStack(spacing: 0) {
                tabsView(width: paperWidth)
                    .padding(.bottom, -4)
                
                paperContent(width: paperWidth)
            }
            .frame(width: paperWidth)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .frame(height: 480)
    }
    
    func tabsView(width: CGFloat) -> some View {
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
            .frame(width: width, alignment: .leading)
        }
    }
    
    func paperContent(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            Divider()
            tabContent
        }
        .frame(width: width)
        .background(Color("BaseColorWhite"))
        .shadow(color: .gray.opacity(0.3), radius: 4, x: 0, y: 3)
    }

    @ViewBuilder
    private var tabContent: some View {
        EvaluationSectionView(
            evaluatorNote: viewModel.currentEvaluatorNote,
            sectionTitle: viewModel.currentSectionTitle,
            showFullScreen: $viewModel.showFullScreen,
            hasScrollableContent: viewModel.currentHasScrollableContent
        ) {
            contentForCurrentTab
        }
    }
    
    @ViewBuilder
    private var contentForCurrentTab: some View {
        switch viewModel.currentTab {
        case .strukturKalimat:
            Text("")
        case .artikulasi:
            ArticulationTranscriptView(
                fullTranscript: viewModel.fullTranscript
            )
            .padding()
        case .fillerWords:
            FillerWordTranscriptView(
                result: viewModel.result,
                fullTranscript: viewModel.fullTranscript
            ).padding()
        case 3: // Tempo
            VStack() {
                TempoResultChart(tempoSeries: viewModel.result.tempoSeries)
                        .frame(height: 220)
            }
            .frame(maxWidth: .infinity)
            .padding()
        case 4: // Intonasi
            VStack() {
                IntonationResultChart(pitchSeries: viewModel.result.pitchSeries)
                    .frame(height: 220)
            }
            .frame(maxWidth: .infinity)
            .padding()
        case .kontakMata:
            Text("")
        }
    }
    
    var bottomButtons: some View {
        HStack(spacing: 16) {
            ButtonComponent(
                title: "SELESAI",
                systemImage: nil,
                size: .medium,
                kind: .secondaryBlue,
                action: onBack
            )
            ButtonComponent(
                title: "LATIHAN LAGI",
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

struct EvaluationSectionView<Content: View>: View {
    let evaluatorNote: String
    let sectionTitle: String
    @Binding var showFullScreen: Bool
    let hasScrollableContent: Bool
    let content: Content
    
    init(
        evaluatorNote: String,
        sectionTitle: String,
        showFullScreen: Binding<Bool> = .constant(false),
        hasScrollableContent: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.evaluatorNote = evaluatorNote
        self.sectionTitle = sectionTitle
        self._showFullScreen = showFullScreen
        self.hasScrollableContent = hasScrollableContent
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Catatan Evaluator:")
                .font(.headline)
                .foregroundColor(.baseColorBrown)
            
            Text(evaluatorNote)
                .font(.custom("BradleyHandITCTT-Bold", size: 22))
                .foregroundColor(.darkBlue2)
                .italic()
                .underline(true, color: Color.baseColorBrown)
            
            Text(sectionTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color.baseColorBrown)
            
            if hasScrollableContent {
                scrollableContentWithGradient
            } else {
                staticContent
            }
        }
        .padding()
    }
    
    private var scrollableContentWithGradient: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("""
                        Selamat pagi/siang para hadirin semuanya hadirin semuanya. Hari ini saya ingin membahas satu proses biologi yang kelihatannya sederhana, tapi sebenarnya menjadi dasar kehidupan di Bumi. Coba bayangkan: kita bisa bernapas, hewan bisa hidup, tumbuhan tumbuh, dan makanan tersedia... semua itu terjadi karena satu proses: fotosintesis pada tumbuhan fotosintesis.
                        
                        Jadi, apa itu fotosintesis? Fotosintesis adalah proses ketika tumbuhan, alga, dan beberapa bakteri mempunyai kemampuan dapat untuk mengubah cahaya matahari, air, dan karbon dioksida menjadi oksigen dan glukosa. Disebabkan karena reaksi kimia, proses ini menghasilkan oksigen dan energi.
                        """)
                    .font(.custom("Nunito-Regular", size: 17))
                    .foregroundColor(.baseColorBrown)
                    .padding(.bottom, 70)
                }
                .padding()
            }
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.7),
                    Color.white.opacity(0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
            .cornerRadius(10)
            .allowsHitTesting(false)
            
            Button {
                showFullScreen = true
            } label: {
                HStack {
                    Image("Fullscreen")
                    Text("Lihat Selengkapnya")
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .foregroundStyle(Color.baseColorBrown)
                .background(Color.baseColorYellow)
                .cornerRadius(24)
                .shadow(radius: 2)
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.brown.opacity(0.5), lineWidth: 1)
        )
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
                Color("BaseColorWhite").ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(transcript.isEmpty ? "Tidak ada transkrip yang terekam." : transcript)
                            .font(.custom("Nunito-Regular", size: 17))
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
