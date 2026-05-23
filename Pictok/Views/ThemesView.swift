import SwiftUI

/// Themes tab landing — pick "All" (random across the whole bundle, equivalent
/// to legacy Endless) or a single category to play through only that theme.
/// On selection, defers to EndlessView with a pre-filtered puzzle pool and a
/// back-to-Themes callback.
struct ThemesView: View {
    @Bindable var store: UserStateStore
    let loader: PuzzleLoader

    @State private var selection: Selection? = nil

    enum Selection: Hashable {
        case all
        case category(Category)
    }

    var body: some View {
        if let selection {
            EndlessView(
                loader: loader,
                store: store,
                category: {
                    if case .category(let c) = selection { return c }
                    return nil
                }(),
                onBack: { self.selection = nil }
            )
        } else {
            picker
        }
    }

    private var picker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Themes")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Color.pkInk)
                    .padding(.top, 12)

                Text("Pick a theme and play through it.")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.pkInk.opacity(0.6))
                    .padding(.bottom, 4)

                allCard
                ForEach(Category.allCases, id: \.self) { categoryCard($0) }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color.pkPaper)
    }

    private var allCard: some View {
        themeCard(
            icon: "🎲",
            title: "All themes",
            subtitle: subtitle(count: loader.allPuzzles.count, suffix: "puzzles · random rotation")
        ) { selection = .all }
    }

    private func categoryCard(_ category: Category) -> some View {
        let count = loader.allPuzzles.filter { $0.category == category }.count
        return themeCard(
            icon: category.icon,
            title: displayName(for: category),
            subtitle: subtitle(count: count, suffix: count == 1 ? "puzzle" : "puzzles")
        ) { selection = .category(category) }
    }

    private func themeCard(icon: String,
                           title: String,
                           subtitle: String,
                           tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(spacing: 16) {
                Text(icon).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color.pkInk)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.pkInk.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.pkInk.opacity(0.4))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.pkInk.opacity(0.07), radius: 10, x: 0, y: 4)
                    .shadow(color: Color.pkInk.opacity(0.04), radius: 2,  x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func subtitle(count: Int, suffix: String) -> String {
        "\(count) \(suffix)"
    }

    private func displayName(for category: Category) -> String {
        switch category {
        case .movie: return "Movies"
        case .song:  return "Songs"
        case .book:  return "Books"
        case .brand: return "Brands"
        case .celeb: return "Celebs"
        case .food:  return "Food"
        case .tv:    return "TV Shows"
        }
    }
}
