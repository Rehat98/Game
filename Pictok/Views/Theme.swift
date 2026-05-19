import SwiftUI

extension Color {
    static let pkPaper      = Color(red: 0xFE/255, green: 0xF3/255, blue: 0xD9/255)
    static let pkInk        = Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255)
    static let pkYellow     = Color(red: 0xFF/255, green: 0xD6/255, blue: 0x0A/255)
    static let pkRed        = Color(red: 0xE6/255, green: 0x39/255, blue: 0x46/255)
    static let pkGreen      = Color(red: 0x06/255, green: 0xD6/255, blue: 0xA0/255)
    static let pkBlue       = Color(red: 0x11/255, green: 0x8A/255, blue: 0xB2/255)
}

extension Font {
    static let pkTitle      = Font.system(size: 36, weight: .black, design: .rounded)
    static let pkSubtitle   = Font.system(size: 17, weight: .heavy, design: .rounded)
    static let pkBody       = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let pkKey        = Font.system(size: 18, weight: .bold, design: .monospaced)
    static let pkBlank      = Font.system(size: 22, weight: .heavy, design: .monospaced)
}

/// Applies the sticker look: rounded rect, 3pt black stroke, hard-edged drop shadow.
struct StickerModifier: ViewModifier {
    var fill: Color = .white
    var cornerRadius: CGFloat = 12
    var strokeWidth: CGFloat = 3
    var shadowOffset: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.pkInk, lineWidth: strokeWidth)
                    )
                    .shadow(color: .pkInk, radius: 0, x: shadowOffset, y: shadowOffset)
            )
    }
}

extension View {
    func sticker(fill: Color = .white,
                 cornerRadius: CGFloat = 12,
                 strokeWidth: CGFloat = 3,
                 shadowOffset: CGFloat = 4) -> some View {
        modifier(StickerModifier(fill: fill,
                                 cornerRadius: cornerRadius,
                                 strokeWidth: strokeWidth,
                                 shadowOffset: shadowOffset))
    }
}
