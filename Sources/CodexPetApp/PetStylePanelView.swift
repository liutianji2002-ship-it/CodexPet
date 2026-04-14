import SwiftUI

struct PetStylePanelView: View {
    @ObservedObject var appearanceStore: PetAppearanceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pet Style")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                Text("Mix a mascot, palette, and expression.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.45))
            }

            StyleSection(title: "Mascot") {
                ForEach(PetCharacter.allCases) { character in
                    SelectablePill(
                        title: character.title,
                        subtitle: character.subtitle,
                        isSelected: appearanceStore.selectedCharacter == character
                    ) {
                        appearanceStore.selectedCharacter = character
                    }
                }
            }

            StyleSection(title: "Palette") {
                HStack(spacing: 8) {
                    ForEach(PetPalette.allCases) { palette in
                        PaletteChip(
                            title: palette.title,
                            style: palette.previewStyle,
                            isSelected: appearanceStore.selectedPalette == palette
                        ) {
                            appearanceStore.selectedPalette = palette
                        }
                    }
                }
            }

            StyleSection(title: "Expression") {
                HStack(spacing: 8) {
                    ForEach(PetExpression.allCases) { expression in
                        CompactPill(
                            title: expression.title,
                            isSelected: appearanceStore.selectedExpression == expression
                        ) {
                            appearanceStore.selectedExpression = expression
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 338, height: 296)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.99, green: 0.98, blue: 0.96))
        )
    }
}

private struct StyleSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.6))
            content
        }
    }
}

private struct SelectablePill: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.48))
            }
            .foregroundStyle(Color.black.opacity(0.82))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.66))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isSelected ? Color.black.opacity(0.18) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PaletteChip: View {
    let title: String
    let style: PetPaletteStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [style.auraTop, style.auraBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(
                            LinearGradient(colors: [style.bodyTop, style.bodyBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 20, height: 20)
                }

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.72))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.64))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? style.accent.opacity(0.55) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CompactPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.72))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.white : Color.white.opacity(0.64))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? Color.black.opacity(0.18) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private extension PetPalette {
    var previewStyle: PetPaletteStyle {
        PetAppearanceStore.paletteStyle(for: self)
    }
}
