import SwiftUI

enum ButterTheme {
    // Light cream palette (v2 redesign)
    static let background = Color(hex: "FFFDF7")
    static let surface = Color(hex: "FFFFFF")
    static let surfaceBorder = Color(hex: "F0E6D0")
    static let gold = Color(hex: "D4940A")
    static let goldDim = Color(hex: "B87D08")
    static let goldLight = Color(hex: "FFF3D6")
    static let textPrimary = Color(hex: "1C1C1E")
    static let textSecondary = Color(hex: "6B6B70")
    static let success = Color(hex: "2D8E40")
    static let deficit = Color(hex: "CC3333")
    static let onPrimaryAction = Color.white

    // Semantic colors
    static let warning = Color(hex: "E67E22")
    static let info = Color(hex: "1976D2")
    static let toastBackground = Color(hex: "1C1C1E")
}

enum ButterSpacing {
    static let cardPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
    static let buttonHeight: CGFloat = 50
    static let buttonCornerRadius: CGFloat = 14
    static let inputCornerRadius: CGFloat = 12
    static let sheetCornerRadius: CGFloat = 20
    static let horizontalPadding: CGFloat = 16
    static let cardGap: CGFloat = 10
    static let sectionGap: CGFloat = 16
    static let controlButtonSize: CGFloat = 56
    static let controlButtonLarge: CGFloat = 68
    static let minTouchTarget: CGFloat = 44
    static let infoBtnVisualSize: CGFloat = 18
    static let tabBarHeight: CGFloat = 49
}

enum ButterTypography {
    static let heroNumber = Font.system(size: 48, weight: .black, design: .rounded)
    static let heroNumberLarge = Font.system(size: 56, weight: .black, design: .rounded)
    static let screenTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let cardTitle = Font.system(size: 14, weight: .bold, design: .rounded)
    static let body = Font.system(.body, design: .rounded)
    static let secondaryLabel = Font.system(.caption, design: .rounded)
    static let statValue = Font.system(size: 18, weight: .heavy, design: .rounded)
    static let statLabel = Font.system(size: 10, weight: .semibold, design: .rounded)
    static let buttonText = Font.system(size: 17, weight: .bold, design: .rounded)
    static let tabBarLabel = Font.system(.caption2, design: .rounded, weight: .semibold)
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



extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
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
        "Butter is approximately 9,000 years old — the first batch was likely churned by accident in animal-skin bags on horseback.",
        "The ‘Tour de Beurre’ tower at Rouen Cathedral was built with donations from people paying to eat butter during Lent.",
        "Harvard’s first student protest was the Butter Rebellion of 1766, triggered by rancid butter in the dining hall.",
        "New Zealand has the highest per-capita butter consumption — about 13.6 pounds per person per year.",
        "American butter must contain at least 80% butterfat; European-style butter requires at least 82%.",
        "The yellow color of butter comes from beta-carotene in grass — grain-fed cows produce whiter butter.",
        "Clarified butter (ghee) has a smoke point of 485°F, compared to regular butter’s 350°F.",
        "The Iowa State Fair has displayed a life-sized butter cow every year since 1911.",
        "The world record for the largest butter sculpture — 4,077 pounds — was set in Dallas, Texas in 2013.",
        "Modern commercial butter machines beat cream at up to 2,800 RPM to churn it in seconds.",
        "Butter is classified as a water-in-fat emulsion — the reverse of cream, which is fat-in-water.",
        "The optimal temperature for churning butter is 50-59°F (10-15°C).",
        "One tablespoon of butter provides approximately 11% of the daily recommended vitamin A.",
        "Butter sculpture as banquet art is documented in Europe as early as 1536.",
        "The Vikings brought butter-preservation techniques to Normandy, founding France’s butter tradition.",
        "Tibetan butter sculptures made from yak butter have been a sacred art form for over 600 years.",
        "Whipped butter contains up to 50% more air than regular butter — don’t substitute 1:1 in baking.",
        "Salted butter was originally a preservation strategy, not a flavor preference.",
        "Butter contains butyrate, a fatty acid that fuels the cells lining your colon.",
        "Grass-fed butter has significantly higher omega-3 fatty acids than butter from grain-fed cows.",
        "Wisconsin’s ban on selling colored margarine wasn’t lifted until 1967.",
        "Butter is about 80% fat, 16-18% water, and 2-4% milk proteins — those proteins cause browning.",
        "The ‘butter run’ trend went viral in early 2026 — runners discovered that 6 miles of trail running churns cream into butter.",
        "Irish peat bogs have preserved butter for up to 3,500 years — and some archaeologists have tasted it.",
        "It takes roughly 6-10 km of running to churn cream into butter in a sealed bag.",
        "Trail running churns butter faster than road running — uneven terrain generates more agitation.",
        "Body heat during a run actually helps cream reach the ideal churning temperature.",
        "If cream gets above 68°F during churning, the fat won’t separate — you’ll get greasy cream, not butter.",
        "A cup of heavy cream yields about 80 grams of butter — a 40% conversion rate.",
        "The first known butter churners ran in Oregon in early 2026, going viral with millions of views.",
    ]

    static var random: String {
        trivia.randomElement() ?? trivia[0]
    }
}
