import SwiftUI

enum ButterTheme {
    static let background = Color(hex: "1A1A1C")
    static let surface = Color(hex: "2A2A2E")
    static let gold = Color(hex: "F3BA60")
    static let goldDim = Color(hex: "C4943F")
    static let textPrimary = Color(hex: "F5F5F5")
    static let textSecondary = Color(hex: "A0A0A5")
    static let success = Color(hex: "5ABF6E")
    static let deficit = Color(hex: "E57373")

}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum ButterFacts {
    static let trivia: [String] = [
        "It takes 21 pounds of whole milk to make 1 pound of butter.",
        "Butter was likely invented by accident when a nomad tied a bag of milk to his horse.",
        "India produces more butter than any other country — 7.6 million tons per year.",
        "In medieval Europe, butter was a luxury only the rich could afford.",
        "France's Rouen Cathedral has a tower funded by butter sales.",
        "Butter sculpting is a competitive art at US state fairs.",
        "In 11th-century Norway, King Svein imposed a butter tax.",
        "Vikings were buried with butter for the afterlife.",
        "The word 'butter' comes from the Greek 'boutyron' — cow cheese.",
        "A stick of butter has 810 calories. That's about an 8-mile run!",
    ]

    static var random: String {
        trivia.randomElement() ?? trivia[0]
    }
}
