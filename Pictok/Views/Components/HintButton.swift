import SwiftUI

/// Right-anchored sticker hint button used in EndlessView. Free, 1 use per puzzle.
struct HintButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        StickerButton(title: "Hint", icon: "💡", fill: .pkYellow) {
            if isEnabled { action() }
        }
        .opacity(isEnabled ? 1.0 : 0.4)
        .disabled(!isEnabled)
    }
}

#Preview {
    VStack(spacing: 16) {
        HintButton(isEnabled: true, action: {})
        HintButton(isEnabled: false, action: {})
    }
    .padding()
    .background(Color.pkPaper)
}
