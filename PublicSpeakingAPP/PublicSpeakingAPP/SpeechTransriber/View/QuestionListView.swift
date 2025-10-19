//
//  QuestionListView.swift
//  PublicSpeakingAPP
//
//  Created by Elisabeth Levana on 15/10/25.
//

import SwiftUI

struct QuestionListView: View {
    @ObservedObject var viewModel: SpeechTranscriberViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Generated Questions")
                .font(.title)
                .bold()
            
            if viewModel.isGeneratingQuestions {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Generating questions...")
                    Spacer()
                }
                .padding()
            } else if let error = viewModel.questionGenerationError {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if viewModel.generatedQuestions.isEmpty {
                Text("No questions generated yet.")
                    .italic()
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        ForEach(viewModel.generatedQuestions.indices, id: \.self) { index in
                            QuestionCard(question: viewModel.generatedQuestions[index], index: index + 1)
                        }
                    }
                }
            }
            
            Button(action: {
                Task {
                    await viewModel.generateQuestionsFromTranscript()
                }
            }) {
                Text(viewModel.generatedQuestions.isEmpty ? "Generate Questions" : "Regenerate Questions")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(viewModel.isGeneratingQuestions || viewModel.transcript.isEmpty)
            .padding(.top)
        }
        .padding()
    }
}

struct QuestionCard: View {
    let question: String
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Text("\(index)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            Text(question)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}
