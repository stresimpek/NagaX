//
//  NotificationPromptView.swift
//  PublicSpeakingAPP
//
//  Created by Feby Agatha Christie Kurniawan on 12/11/25.
//

import SwiftUI
import UserNotifications

struct NotificationPromptView: View {
    
    let selectedDate: Date
    let onBack: () -> Void
    let onComplete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.baseColorBlue)
                .ignoresSafeArea()
            
            VStack() {
                Text("Mau diingetin latihannya?")
                    .font(.title1)
                    .foregroundStyle(Color.white)
                    .bold()
                Text("Kamu bakal diingetin h-1 sebelum waktu presentasimu dimulai.")
                    .font(.body)
                    .foregroundStyle(Color.white)

                MicroAnimation(artboardName: "NotificationBell")
                    .frame(width: isIpad ? 260: 200, height: isIpad ? 260 : 200)

                HStack(spacing: 20) {
                    ButtonComponent(
                        title: "Skip Dulu.",
                        systemImage: nil,
                        size: .large,
                        kind: .secondaryBlue
                    ) {
                        onComplete()
                    }
                    
                    ButtonComponent(
                        title: "Mau Dong!",
                        systemImage: nil,
                        size: .large,
                        kind: .primaryYellow
                    ) {
                        requestAndScheduleNotification()
                    }
                    .accessibilityLabel("Mau diingetin")
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
            .accessibilityLabel("Kembali")
        }
    }
    
    private func requestAndScheduleNotification() {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Error meminta izin notifikasi: \(error.localizedDescription)")
                DispatchQueue.main.async { onComplete() }
                return
            }
            
            if granted {
                print("Izin notifikasi diberikan.")
                scheduleNotification()
            } else {
                print("Izin notifikasi ditolak.")
            }
            
            DispatchQueue.main.async {
                onComplete()
            }
        }
    }
    
    private func scheduleNotification() {
            let calendar = Calendar.current
            let center = UNUserNotificationCenter.current()
            
            let identifierH1 = "PRESENTATION_REMINDER_H-1"
            let identifierH0 = "PRESENTATION_REMINDER_H-0"
            
            center.removePendingNotificationRequests(withIdentifiers: [
                identifierH1,
                identifierH0
            ])

            let presentationDayStart = calendar.startOfDay(for: selectedDate)
            
            let notificationDateH0 = presentationDayStart
            
            guard let notificationDateH1 = calendar.date(byAdding: .day, value: -1, to: presentationDayStart) else {
                print("Gagal menghitung tanggal notifikasi H-1.")
                return
            }
            
            if notificationDateH1 > Date() {
                let contentH1 = UNMutableNotificationContent()
                contentH1.title = "Presentasi Besok!"
                contentH1.body = "Besok adalah hari H presentasimu. Manfaatkan hari ini untuk latihan terakhir, ya!"
                contentH1.sound = .default

                let componentsH1 = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDateH1)
                let triggerH1 = UNCalendarNotificationTrigger(dateMatching: componentsH1, repeats: false)
                
                let requestH1 = UNNotificationRequest(identifier: identifierH1, content: contentH1, trigger: triggerH1)
                
                center.add(requestH1) { error in
                    if let error {
                        print("Gagal menjadwalkan notifikasi H-1: \(error.localizedDescription)")
                    } else {
                        print("Notifikasi H-1 berhasil dijadwalkan pada \(notificationDateH1)")
                    }
                }
            } else {
                print("Tanggal notifikasi H-1 sudah lewat, dilewati.")
            }
            
            if notificationDateH0 > Date() {
                let contentH0 = UNMutableNotificationContent()
                contentH0.title = "Presentasi Hari Ini!"
                contentH0.body = "Hari ini adalah hari H! Jangan lupa persiapkan dirimu. Semoga berhasil!"
                contentH0.sound = .default
                
                let componentsH0 = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDateH0)
                let triggerH0 = UNCalendarNotificationTrigger(dateMatching: componentsH0, repeats: false)

                let requestH0 = UNNotificationRequest(identifier: identifierH0, content: contentH0, trigger: triggerH0)

                center.add(requestH0) { error in
                    if let error {
                        print("Gagal menjadwalkan notifikasi Hari H: \(error.localizedDescription)")
                    } else {
                        print("Notifikasi Hari H berhasil dijadwalkan pada \(notificationDateH0)")
                    }
                }
            } else {
                print("Tanggal notifikasi Hari H sudah lewat, dilewati.")
            }
        }
}
