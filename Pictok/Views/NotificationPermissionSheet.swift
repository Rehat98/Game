import SwiftUI
import UserNotifications

struct NotificationPermissionSheet: View {
    @Bindable var store: UserStateStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("🔥")
                .font(.system(size: 96))

            Text("Keep your streak alive")
                .font(.pkTitle)
                .multilineTextAlignment(.center)

            Text("Want a daily reminder so you don't lose your streak? We'll send one ping at 9 AM.")
                .font(.pkBody)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            StickerButton(title: "Yes, remind me", icon: "📌", fill: .pkGreen) {
                Task { await requestPermission() }
            }
            .padding(.horizontal)

            Button("No thanks") {
                store.state.hasAskedForNotificationPermission = true
                store.save()
                dismiss()
            }
            .foregroundStyle(.gray)
            .padding(.bottom, 24)
        }
        .padding()
        .background(Color.pkPaper)
        .presentationDetents([.medium])
    }

    private func requestPermission() async {
        store.state.hasAskedForNotificationPermission = true
        store.save()
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
        dismiss()
    }
}
