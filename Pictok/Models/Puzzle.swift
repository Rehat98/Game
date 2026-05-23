import Foundation

struct Puzzle: Codable, Identifiable, Equatable {
    let id: String
    let date: String      // "YYYY-MM-DD"
    let emoji: String
    let answer: String    // UPPERCASE, spaces preserved
    let category: Category
    let subcategory: String
    let difficulty: Difficulty
}

enum Category: String, Codable, CaseIterable {
    case movie = "Movie"
    case song  = "Song"
    case book  = "Book"
    case brand = "Brand"
    case celeb = "Celeb"
    case food  = "Food"
    case tv    = "TV"

    var icon: String {
        switch self {
        case .movie: return "🎬"
        case .song:  return "🎵"
        case .book:  return "📚"
        case .brand: return "🏷️"
        case .celeb: return "🎤"
        case .food:  return "🍕"
        case .tv:    return "📺"
        }
    }
}

enum Difficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard

    var displayName: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        }
    }
}
