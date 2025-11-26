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
        let currentYear = currentComponents.year ?? 2025
        let currentMonth = currentComponents.month ?? 1
        
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
            
            VStack(alignment: .center, spacing: 32) {
                Text("Tanggal dan jam berapakah kamu akan presentasi?")
                    .font(.title2)
                    .foregroundStyle(Color.white)
                    .bold()
                    .padding(.horizontal)

                HStack(alignment: .center, spacing: 16) {
                    Spacer()
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hari")
                                .font(.body)
                                .foregroundStyle(Color.white)
                            
                            Menu {
                                ForEach(availableDays, id: \.self) { day in
                                    Button(action: {
                                        selectedDay = day
                                        validateAndAdjustSelection()
                                    }) {
                                        Text("\(day)")
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("\(selectedDay)")
                                        .foregroundStyle(Color.white)
                                    Spacer()
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
                            .accessibilityHint("Tap 2 kali untuk memilih hari")
                        }
                        .accessibilityElement(children: .combine)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bulan")
                                .font(.body)
                                .foregroundStyle(Color.white)
                            
                            Menu {
                                ForEach(availableMonths, id: \.0) { month in
                                    Button(action: {
                                        selectedMonth = month.0
                                        validateAndAdjustSelection()
                                    }) {
                                        Text(month.1)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(months.first(where: { $0.0 == selectedMonth })?.1 ?? "")
                                        .foregroundStyle(Color.white)
                                        .lineLimit(1)
                                    Spacer()
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
                            .accessibilityHint("Tap 2 kali untuk memilih bulan")
                        }
                        .accessibilityElement(children: .combine)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tahun")
                                .font(.body)
                                .foregroundStyle(Color.white)
                            
                            Menu {
                                ForEach(years, id: \.self) { year in
                                    Button(action: {
                                        selectedYear = year
                                        validateAndAdjustSelection()
                                    }) {
                                        Text(String(format: "%d", year))
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(String(format: "%d", selectedYear))
                                        .foregroundStyle(Color.white)
                                    Spacer()
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
                            .accessibilityHint("Tap 2 kali untuk memilih tahun")
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .frame(width: 400)

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Jam")
                                .font(.body)
                                .foregroundStyle(Color.white)
                            
                            Menu {
                                ForEach(availableHours, id: \.self) { hour in
                                    Button(action: {
                                        selectedHour = hour
                                        validateAndAdjustSelection()
                                    }) {
                                        Text(String(format: "%02d", hour))
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(String(format: "%02d", selectedHour))
                                        .foregroundStyle(Color.white)
                                    Spacer()
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
                            .accessibilityHint("Tap 2 kali untuk memilih jam")
                        }
                        .accessibilityElement(children: .combine)
                        
                        Text(":")
                            .font(.title)
                            .foregroundStyle(Color.white)
                            .padding(.top, 20)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Menit")
                                .font(.body)
                                .foregroundStyle(Color.white)
                            
                            Menu {
                                ForEach(availableMinutes, id: \.self) { minute in
                                    Button(action: {
                                        selectedMinute = minute
                                        validateAndAdjustSelection()
                                    }) {
                                        Text(String(format: "%02d", minute))
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(String(format: "%02d", selectedMinute))
                                        .foregroundStyle(Color.white)
                                    Spacer()
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
                            .accessibilityHint("Tap 2 kali untuk memilih menit")
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .frame(width: 200)
                    Spacer()
                }

                if !isSelectedDateTimeValid {
                    ButtonComponent(
                        title: "Tanggal Invalid",
                        systemImage: nil,
                        size: .large,
                        kind: .primaryYellow
                    ) {
                        let selectedDate = createDate()
                        saveOrUpdate(date: selectedDate)
                        onComplete(selectedDate)
                    }
                    .disabled(!isSelectedDateTimeValid)
                    .opacity(0.5)
                    .padding(.horizontal)
                } else {
                    ButtonComponent(
                        title: "Pilih Deadline",
                        systemImage: nil,
                        size: .large,
                        kind: .primaryYellow
                    ) {
                        let selectedDate = createDate()
                        saveOrUpdate(date: selectedDate)
                        onComplete(selectedDate)
                    }
                    .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
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
            .accessibilityLabel("Kembali")
        }
        .onAppear {
            initializeWithCurrentOrSavedDate()
        }
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
