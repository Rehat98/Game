import SwiftUI

struct HowToPlayView: View {
    @State private var page = 0
    @Environment(\.dismiss) private var dismiss

    private let pages: [(emoji: String, title: String, body: String, fill: Color)] = [
        ("📌", "One puzzle a day",
         "A new emoji puzzle drops every day. Movies, songs, books, brands, celebs.",
         .pkYellow),
        ("❤️", "Five hearts, no mercy",
         "Each wrong letter costs a heart. Out of hearts = puzzle locked until tomorrow.",
         .pkRed),
        ("🔥", "Keep the streak alive",
         "Solve daily to build your streak. Share your result spoiler-free. Brag responsibly.",
         .pkGreen),
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(0..<pages.count, id: \.self) { i in
                    let p = pages[i]
                    VStack(spacing: 20) {
                        Text(p.emoji).font(.system(size: 96))
                        Text(p.title).font(.pkTitle)
                        Text(p.body).font(.pkBody).multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    .tag(i)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(p.fill.opacity(0.25))
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            StickerButton(title: page < pages.count - 1 ? "Next" : "Start playing",
                          fill: .pkBlue) {
                if page < pages.count - 1 { page += 1 } else { dismiss() }
            }
            .padding(.bottom, 24)
        }
        .background(Color.pkPaper)
    }
}
