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
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
        
    let onBack: () -> Void
    let onComplete: (Date) -> Void
    
    @Query(sort: [SortDescriptor(\PresentationDateModel.date)]) private var savedDates: [PresentationDateModel]

    @State private var selectedDay: Int = 1
    @State private var selectedMonth: Int = 1
    @State private var selectedYear: Int = 2025
    @State private var selectedHour: Int = 0
    @State private var selectedMinute: Int = 0
    
    private let currentDate = Date()
    private let calendar = Calendar.current
    
    private var currentComponents: DateComponents {
        calendar.dateComponents([.day, .month, .year, .hour, .minute], from: currentDate)
    }
    
    private var years: [Int] {
        let currentYear = currentComponents.year ?? 2025
        return Array(currentYear...currentYear + 10)
    }
    
    private var months: [(Int, String)] {
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
                         "Jul", "Ags", "Sep", "Okt", "Nov", "Des"]
        
        return Array(1...12).map { month in
            (month, monthNames[month - 1])
        }
    }
    
    private var availableMonths: [(Int, String)] {
        let currentYear = currentComponents.year ?? 2025
        let currentMonth = currentComponents.month ?? 1
        
        if selectedYear == currentYear {
            return months.filter { $0.0 >= currentMonth }
        } else {
            return months
        }
    }
    
    private var days: [Int] {
        let daysInMonth = calendar.range(of: .day, in: .month, for: createDate())?.count ?? 31
        return Array(1...daysInMonth)
    }
    
    private var availableDays: [Int] {
        let currentYear = currentComponents.year ?? 2025
        let currentMonth = currentComponents.month ?? 1
        let currentDay = currentComponents.day ?? 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: createDate())?.count ?? 31
        
        if selectedYear == currentYear && selectedMonth == currentMonth {
            return Array(currentDay...daysInMonth)
        } else {
            return Array(1...daysInMonth)
        }
    }
    
    private var hours: [Int] {
        Array(0...23)
    }
    
    private var availableHours: [Int] {
        let currentYear = currentComponents.year ?? 2025
        let currentMonth = currentComponents.month ?? 1
        let currentDay = currentComponents.day ?? 1
        let currentHour = currentComponents.hour ?? 0
        
        if selectedYear == currentYear && selectedMonth == currentMonth && selectedDay == currentDay {
            return Array(currentHour...23)
        } else {
            return Array(0...23)
        }
    }
    
    private var minutes: [Int] {
        Array(0...59)
    }
    
    private var availableMinutes: [Int] {
        let currentYear = currentComponents.year ?? 2025
        let currentMonth = currentComponents.month ?? 1
        let currentDay = currentComponents.day ?? 1
        let currentHour = currentComponents.hour ?? 0
        let currentMinute = currentComponents.minute ?? 0
        
        if selectedYear == currentYear && selectedMonth == currentMonth &&
           selectedDay == currentDay && selectedHour == currentHour {
            return Array(currentMinute...59)
        } else {
            return Array(0...59)
        }
    }
    
    private var isSelectedDateTimeValid: Bool {
        let selectedDate = createDate()
        return selectedDate > currentDate
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.baseColorBlue)
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .center, spacing: 24) {
                        Spacer ()
                        Text("Tanggal dan jam berapakah kamu akan presentasi?")
                            .font(.title2)
                            .foregroundStyle(Color.white)
                            .bold()
                            .padding(.horizontal)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .center, spacing: 16) {
                            HStack(spacing: 8) {
                                // HARI
                                dateComponentPicker(
                                    title: "Hari",
                                    value: "\(selectedDay)",
                                    hint: "Tap 2 kali untuk memilih hari"
                                ) {
                                    ForEach(availableDays, id: \.self) { day in
                                        Button(action: {
                                            selectedDay = day
                                            validateAndAdjustSelection()
                                        }) {
                                            Text("\(day)")
                                        }
                                    }
                                }
                                
                                // BULAN
                                dateComponentPicker(
                                    title: "Bulan",
                                    value: months.first(where: { $0.0 == selectedMonth })?.1 ?? "",
                                    hint: "Tap 2 kali untuk memilih bulan"
                                ) {
                                    ForEach(availableMonths, id: \.0) { month in
                                        Button(action: {
                                            selectedMonth = month.0
                                            validateAndAdjustSelection()
                                        }) {
                                            Text(month.1)
                                        }
                                    }
                                }
                                
                                // TAHUN
                                dateComponentPicker(
                                    title: "Tahun",
                                    value: String(format: "%d", selectedYear),
                                    hint: "Tap 2 kali untuk memilih tahun"
                                ) {
                                    ForEach(years, id: \.self) { year in
                                        Button(action: {
                                            selectedYear = year
                                            validateAndAdjustSelection()
                                        }) {
                                            Text(String(format: "%d", year))
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            
                            HStack(spacing: 8) {
                                // JAM
                                dateComponentPicker(
                                    title: "Jam",
                                    value: String(format: "%02d", selectedHour),
                                    hint: "Tap 2 kali untuk memilih jam"
                                ) {
                                    ForEach(availableHours, id: \.self) { hour in
                                        Button(action: {
                                            selectedHour = hour
                                            validateAndAdjustSelection()
                                        }) {
                                            Text(String(format: "%02d", hour))
                                        }
                                    }
                                }
                                
                                Text(":")
                                    .font(.title)
                                    .foregroundStyle(Color.white)
                                    .padding(.top, 20)
                                    .accessibilityHidden(true)
                                
                                // MENIT
                                dateComponentPicker(
                                    title: "Menit",
                                    value: String(format: "%02d", selectedMinute),
                                    hint: "Tap 2 kali untuk memilih menit"
                                ) {
                                    ForEach(availableMinutes, id: \.self) { minute in
                                        Button(action: {
                                            selectedMinute = minute
                                            validateAndAdjustSelection()
                                        }) {
                                            Text(String(format: "%02d", minute))
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: 300)
                        }
                                                
                        Group {
                            if !isSelectedDateTimeValid {
                                ButtonComponent(
                                    title: "Tanggal Invalid",
                                    systemImage: nil,
                                    size: .large,
                                    kind: .primaryYellow
                                ) {
                                    handleCompletion()
                                }
                                .disabled(true)
                                .opacity(0.5)
                            } else {
                                ButtonComponent(
                                    title: "Pilih Deadline",
                                    systemImage: nil,
                                    size: .large,
                                    kind: .primaryYellow
                                ) {
                                    handleCompletion()
                                }
                            }
                        }
                        .padding(.horizontal)
                        Spacer()
                    }
                    .padding(24)
                    .multilineTextAlignment(.center)
                }
        }
            ButtonComponent(
                title: nil,
                systemImage: "arrow.uturn.left",
                size: .largeIconCircle,
                kind: .secondaryBlue,
                action: onBack
            )
            .padding(.leading, 16)
            .padding(.top, 16)
            .accessibilityLabel("Kembali")
        }
        .onAppear {
            initializeWithCurrentOrSavedDate()
        }
    }
    
    @ViewBuilder
    private func dateComponentPicker<Content: View>(
        title: String,
        value: String,
        hint: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body)
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: true, vertical: false)
            
            Menu {
                content()
            } label: {
                HStack {
                    Text(value)
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer(minLength: 8)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.body)
                        .foregroundStyle(Color.white)
                        .accessibilityHidden(true)
                }
                .padding()
                .background(Color.darkBlue2)
                .cornerRadius(12)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title), \(value)")
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
        }
        .accessibilityElement(children: .combine)
    }

    private func handleCompletion() {
        let selectedDate = createDate()
        saveOrUpdate(date: selectedDate)
        onComplete(selectedDate)
    }
    
    private func initializeWithCurrentOrSavedDate() {
        let dateToUse: Date
        if let existing = savedDates.first {
            dateToUse = existing.date
        } else {
            dateToUse = currentDate
        }
        
        let components = calendar.dateComponents([.day, .month, .year, .hour, .minute], from: dateToUse)
        selectedDay = components.day ?? 1
        selectedMonth = components.month ?? 1
        selectedYear = components.year ?? 2025
        selectedHour = components.hour ?? 0
        selectedMinute = components.minute ?? 0
    }
    
    private func createDate() -> Date {
        var components = DateComponents()
        components.day = selectedDay
        components.month = selectedMonth
        components.year = selectedYear
        components.hour = selectedHour
        components.minute = selectedMinute
        return calendar.date(from: components) ?? Date()
    }
    
    private func validateAndAdjustSelection() {
        let currentYear = currentComponents.year ?? 2025
        let currentMonth = currentComponents.month ?? 1
        let currentDay = currentComponents.day ?? 1
        let currentHour = currentComponents.hour ?? 0
        let currentMinute = currentComponents.minute ?? 0
        
        if selectedYear == currentYear && selectedMonth < currentMonth {
            selectedMonth = currentMonth
        }
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: createDate())?.count ?? 31
        if selectedDay > daysInMonth {
            selectedDay = daysInMonth
        }
        
        if selectedYear == currentYear && selectedMonth == currentMonth && selectedDay < currentDay {
            selectedDay = currentDay
        }
        
        if selectedYear == currentYear && selectedMonth == currentMonth &&
           selectedDay == currentDay && selectedHour < currentHour {
            selectedHour = currentHour
        }
        
        if selectedYear == currentYear && selectedMonth == currentMonth &&
           selectedDay == currentDay && selectedHour == currentHour &&
           selectedMinute < currentMinute {
            selectedMinute = currentMinute
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
