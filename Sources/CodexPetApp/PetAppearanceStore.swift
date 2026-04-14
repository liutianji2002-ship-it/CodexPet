import SwiftUI

enum PetCharacter: String, CaseIterable, Identifiable {
    case cat
    case bear
    case fox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cat:
            return "Cat"
        case .bear:
            return "Bear"
        case .fox:
            return "Fox"
        }
    }

    var subtitle: String {
        switch self {
        case .cat:
            return "Classic buddy"
        case .bear:
            return "Round and soft"
        case .fox:
            return "Sharp and lively"
        }
    }
}

enum PetPalette: String, CaseIterable, Identifiable {
    case tangerine
    case mint
    case sky

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tangerine:
            return "Tangerine"
        case .mint:
            return "Mint"
        case .sky:
            return "Sky"
        }
    }
}

enum PetExpression: String, CaseIterable, Identifiable {
    case calm
    case happy
    case cheeky

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm:
            return "Calm"
        case .happy:
            return "Happy"
        case .cheeky:
            return "Cheeky"
        }
    }
}

struct PetPaletteStyle: Equatable {
    let auraTop: Color
    let auraBottom: Color
    let bodyTop: Color
    let bodyBottom: Color
    let accent: Color
    let accentSoft: Color
    let earInner: Color
    let paw: Color
    let cheek: Color
    let badge: Color
    let sparkle: Color
}

@MainActor
final class PetAppearanceStore: ObservableObject {
    @Published var selectedCharacter: PetCharacter {
        didSet { save() }
    }
    @Published var selectedPalette: PetPalette {
        didSet { save() }
    }
    @Published var selectedExpression: PetExpression {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let characterKey = "CodexPet.selectedCharacter"
    private let paletteKey = "CodexPet.selectedPalette"
    private let expressionKey = "CodexPet.selectedExpression"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedCharacter = PetCharacter(rawValue: defaults.string(forKey: characterKey) ?? "") ?? .cat
        selectedPalette = PetPalette(rawValue: defaults.string(forKey: paletteKey) ?? "") ?? .tangerine
        selectedExpression = PetExpression(rawValue: defaults.string(forKey: expressionKey) ?? "") ?? .happy
    }

    var paletteStyle: PetPaletteStyle {
        Self.paletteStyle(for: selectedPalette)
    }

    nonisolated static func paletteStyle(for palette: PetPalette) -> PetPaletteStyle {
        switch palette {
        case .tangerine:
            return PetPaletteStyle(
                auraTop: Color(red: 1.00, green: 0.96, blue: 0.88),
                auraBottom: Color(red: 0.98, green: 0.84, blue: 0.68),
                bodyTop: Color(red: 1.00, green: 0.79, blue: 0.38),
                bodyBottom: Color(red: 0.98, green: 0.60, blue: 0.22),
                accent: Color(red: 0.97, green: 0.61, blue: 0.25),
                accentSoft: Color(red: 1.00, green: 0.83, blue: 0.82),
                earInner: Color(red: 1.00, green: 0.83, blue: 0.82),
                paw: Color(red: 1.00, green: 0.84, blue: 0.79),
                cheek: Color(red: 1.00, green: 0.75, blue: 0.76),
                badge: Color(red: 0.95, green: 0.31, blue: 0.25),
                sparkle: Color(red: 1.00, green: 0.87, blue: 0.38)
            )
        case .mint:
            return PetPaletteStyle(
                auraTop: Color(red: 0.91, green: 0.99, blue: 0.94),
                auraBottom: Color(red: 0.72, green: 0.92, blue: 0.80),
                bodyTop: Color(red: 0.57, green: 0.88, blue: 0.72),
                bodyBottom: Color(red: 0.32, green: 0.74, blue: 0.58),
                accent: Color(red: 0.25, green: 0.67, blue: 0.50),
                accentSoft: Color(red: 0.88, green: 0.97, blue: 0.90),
                earInner: Color(red: 0.88, green: 0.97, blue: 0.90),
                paw: Color(red: 0.88, green: 0.97, blue: 0.90),
                cheek: Color(red: 1.00, green: 0.79, blue: 0.82),
                badge: Color(red: 0.18, green: 0.63, blue: 0.47),
                sparkle: Color(red: 0.80, green: 0.96, blue: 0.87)
            )
        case .sky:
            return PetPaletteStyle(
                auraTop: Color(red: 0.92, green: 0.97, blue: 1.00),
                auraBottom: Color(red: 0.72, green: 0.84, blue: 0.98),
                bodyTop: Color(red: 0.51, green: 0.73, blue: 0.98),
                bodyBottom: Color(red: 0.30, green: 0.56, blue: 0.92),
                accent: Color(red: 0.24, green: 0.47, blue: 0.84),
                accentSoft: Color(red: 0.86, green: 0.91, blue: 1.00),
                earInner: Color(red: 0.86, green: 0.91, blue: 1.00),
                paw: Color(red: 0.91, green: 0.91, blue: 0.99),
                cheek: Color(red: 0.99, green: 0.78, blue: 0.83),
                badge: Color(red: 0.23, green: 0.47, blue: 0.88),
                sparkle: Color(red: 0.84, green: 0.92, blue: 1.00)
            )
        }
    }

    private func save() {
        defaults.set(selectedCharacter.rawValue, forKey: characterKey)
        defaults.set(selectedPalette.rawValue, forKey: paletteKey)
        defaults.set(selectedExpression.rawValue, forKey: expressionKey)
    }
}
