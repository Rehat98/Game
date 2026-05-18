import SwiftUI

struct CategoryChip: View {
    let category: Category
    var subcategory: String? = nil   // shown only if reveal-category hint was used

    var body: some View {
        HStack(spacing: 6) {
            Text(category.icon)
            Text(displayText)
                .font(.pkBody)
                .foregroundStyle(Color.pkInk)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .sticker(fill: .pkGreen, cornerRadius: 10, strokeWidth: 2, shadowOffset: 2)
    }

    private var displayText: String {
        if let sub = subcategory {
            return "\(category.rawValue) · \(sub)"
        }
        return category.rawValue
    }
}

#Preview {
    VStack {
        CategoryChip(category: .movie)
        CategoryChip(category: .movie, subcategory: "Action · 2008")
    }
    .padding()
    .background(Color.pkPaper)
}
