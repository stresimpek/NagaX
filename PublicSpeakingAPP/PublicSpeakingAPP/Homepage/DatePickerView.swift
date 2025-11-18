//
//  DatePickerView.swift
//  PublicSpeakingAPP
//
//  Created by Regina Celine Adiwinata on 04/11/25.
//

import SwiftUI
import SwiftData

struct DatePickerView: View {
    @Environment(\.modelContext) private var context
    let onBack: () -> Void
    let onComplete: (Date) -> Void
    
    @Query(sort: [SortDescriptor(\PresentationDateModel.date)]) private var savedDates: [PresentationDateModel]

    @State private var pickedDate: Date = .init()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.baseColorBlue)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Tanggal dan jam berapakah kamu akan presentasi?")
                    .font(.title2)
                    .foregroundStyle(Color.white)
                    .bold()

                DatePicker(
                    "",
                    selection: $pickedDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .foregroundStyle(Color.white)
                .datePickerStyle(.wheel)
                .labelsHidden()

                ButtonComponent(
                    title: "PILIH DEADLINE",
                    systemImage: nil,
                    size: .large,
                    kind: .primaryYellow
                ) {
                    saveOrUpdate(date: pickedDate)
                    onComplete(pickedDate)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)

            ButtonComponent(
                title: nil,
                systemImage: "arrow.uturn.left",
                size: .largeIconCircle,
                kind: .secondaryBlue,
                action: onBack
            )
            .padding(.leading, 16)
            .padding(.top, 16)
        }
        .onAppear {
            if let existing = savedDates.first {
                pickedDate = existing.date
            }
        }
    }

    private func saveOrUpdate(date: Date) {
        if let existing = savedDates.first {
            existing.date = date
        } else {
            let item = PresentationDateModel(date: date)
            context.insert(item)
        }
        do { try context.save() } catch {
            print("Gagal menyimpan tanggal: \(error)")
        }
    }
}
