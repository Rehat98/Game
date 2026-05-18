import SwiftUI

struct StickerButton: View {
    let title: String
    var icon: String? = nil
    var fill: Color = .pkYellow
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            HapticsService.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon { Text(icon) }
                Text(title)
                    .font(.pkSubtitle)
                    .foregroundStyle(Color.pkInk)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .sticker(fill: fill, cornerRadius: 14, strokeWidth: 3,
                 shadowOffset: pressed ? 1 : 4)
        .offset(x: pressed ? 3 : 0, y: pressed ? 3 : 0)
        .animation(.easeOut(duration: 0.08), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        StickerButton(title: "Share", icon: "📤") {}
        StickerButton(title: "How to Play", icon: "💡", fill: .pkGreen) {}
        StickerButton(title: "Continue", fill: .pkRed) {}
    }
    .padding()
    .background(Color.pkPaper)
}
