import SwiftUI

struct PetView: View {
    @ObservedObject var viewModel: PetViewModel
    @ObservedObject var appearanceStore: PetAppearanceStore
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            bubble
            mascot
        }
        .frame(width: 184, height: 188)
        .padding(.vertical, 7)
        .padding(.horizontal, 5)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            viewModel.openCodex()
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                StatusChip(title: "AX", value: viewModel.isAccessibilityTrusted ? "On" : "Off", accent: viewModel.isAccessibilityTrusted ? .green : .orange)
                StatusChip(title: "Logs", value: viewModel.isLogMonitorActive ? "On" : "Off", accent: viewModel.isLogMonitorActive ? .blue : .orange)
                Spacer(minLength: 0)
            }

            Text(viewModel.bubbleText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.86))
                .lineLimit(1)

            if let systemResourceText = viewModel.systemResourceText {
                Text(systemResourceText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.52))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: 152, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(red: 1.0, green: 0.98, blue: 0.94).opacity(0.98))
                .shadow(color: .black.opacity(0.1), radius: 7, y: 4)
        )
        .overlay(alignment: .bottomLeading) {
            BubbleTail()
                .fill(Color(red: 1.0, green: 0.98, blue: 0.94).opacity(0.98))
                .frame(width: 10, height: 7)
                .offset(x: 14, y: 6)
        }
    }

    private var mascot: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            let idleOffset = CGFloat(sin(phase * 2.1)) * 2.2
            let tailRotation = Angle(degrees: sin(phase * 5.6) * (viewModel.isCelebrating ? 24 : 12))
            let bodySway = Angle(degrees: sin(phase * 1.6) * 2.2)
            let breathingScale = 1 + CGFloat(sin(phase * 2.6)) * 0.018
            let earTilt = Angle(degrees: sin(phase * 3.4) * 5.5)
            let earLift = CGFloat(cos(phase * 3.4)) * 1.6
            let faceLift = CGFloat(sin(phase * 2.2)) * 1.4
            let hoverBoost: CGFloat = isHovering ? 1 : 0
            let dozeLevel = viewModel.unreadThreadCount == 0 && !viewModel.isCelebrating
                ? eventEnvelope(phase, speed: 0.42, threshold: 0.8)
                : 0
            let playfulLevel = eventEnvelope(phase + 0.8, speed: 0.76, threshold: 0.86)
            let alertLevel = viewModel.unreadThreadCount > 0
                ? max(eventEnvelope(phase + 0.4, speed: 0.64, threshold: 0.82), hoverBoost * 0.7)
                : hoverBoost * 0.45
            let blinkHeight = blinkHeight(for: phase)
            let sparkleOpacity = viewModel.isCelebrating ? 1.0 : 0.0
            let palette = appearanceStore.paletteStyle
            let workingLevel: CGFloat = viewModel.isWorking && !viewModel.isCelebrating
                ? max(eventEnvelope(phase + 0.2, speed: 3.2, threshold: 0.18), 0.72)
                : 0
            let animatedTailRotation = Angle(
                degrees: tailRotation.degrees + Double((alertLevel + hoverBoost) * 8 - dozeLevel * 4 + workingLevel * 6)
            )
            let animatedBodySway = Angle(
                degrees: bodySway.degrees + Double(playfulLevel * 5 + hoverBoost * 2.5 - dozeLevel * 3.5 + workingLevel * 7)
            )
            let mascotYOffset = viewModel.isCelebrating
                ? -5
                : idleOffset - dozeLevel * 2.8 - playfulLevel * 1.8 - workingLevel * 5.6
            let mascotScale = viewModel.isCelebrating
                ? 0.84
                : 0.76 + hoverBoost * 0.02 + alertLevel * 0.015 - dozeLevel * 0.02 + workingLevel * 0.012

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.auraTop.opacity(0.96),
                                palette.auraBottom.opacity(0.76)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 112, height: 112)
                    .blur(radius: 0.2)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.42), lineWidth: 1)
                            .frame(width: 106, height: 106)
                    }

                if workingLevel > 0.2 {
                    WorkingHalo(phase: phase, color: palette.badge, opacity: workingLevel)
                        .frame(width: 130, height: 130)
                }

                Ellipse()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 62, height: 12)
                    .offset(y: 53)

                Circle()
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 20, height: 20)
                    .blur(radius: 1)
                    .offset(x: -26, y: -22)

                tailView(rotation: animatedTailRotation, palette: palette)

                mascotBody(
                    blinkHeight: blinkHeight,
                    palette: palette,
                    pawLift: playfulLevel * 4 + hoverBoost * 2 + workingLevel * 6,
                    dozeLevel: dozeLevel,
                    alertLevel: alertLevel,
                    workingLevel: workingLevel,
                    phase: phase
                )
                .rotationEffect(animatedBodySway)
                .scaleEffect(breathingScale + hoverBoost * 0.012 - dozeLevel * 0.01 + workingLevel * 0.01)
                .offset(y: faceLift - dozeLevel * 1.4 - workingLevel * 1.2)

                earStack(earTilt: earTilt, earLift: earLift, palette: palette)
                    .offset(y: -38)

                HeartAccent()
                    .fill(palette.cheek.opacity(0.92))
                    .frame(width: 10, height: 9)
                    .rotationEffect(.degrees(-10))
                    .offset(x: -24, y: -34 + CGFloat(sin(phase * 2.8)) * 1.8 - hoverBoost * 1.5)

                CounterBadge(count: viewModel.unreadThreadCount, fill: palette.badge)
                    .offset(x: 43, y: -39)
                    .scaleEffect(1 + alertLevel * 0.08 + hoverBoost * 0.04)

                if dozeLevel > 0.15 {
                    SleepAccent(opacity: dozeLevel)
                        .offset(x: 28, y: -30 - dozeLevel * 8)
                }

                if alertLevel > 0.2 && !viewModel.isCelebrating {
                    AlertAccent(opacity: alertLevel)
                        .offset(x: 0, y: -52 - alertLevel * 4)
                }

                if workingLevel > 0.2 {
                    WorkingAccent(phase: phase, opacity: workingLevel)
                        .offset(y: -52)
                }

                if workingLevel > 0.2 {
                    WorkingTrail(phase: phase, color: palette.badge, opacity: workingLevel)
                }

                ForEach(0..<6, id: \.self) { index in
                    SparkleView(index: index, phase: phase, sparkleColor: palette.sparkle)
                        .opacity(sparkleOpacity)
                }
            }
            .offset(y: mascotYOffset)
            .scaleEffect(mascotScale)
            .animation(.spring(response: 0.36, dampingFraction: 0.52), value: viewModel.isCelebrating)
            .animation(.easeInOut(duration: 0.18), value: isHovering)
        }
        .help("Click to open Codex")
    }

    private func blinkHeight(for phase: TimeInterval) -> CGFloat {
        if viewModel.isCelebrating {
            return appearanceStore.selectedExpression == .happy ? 4.5 : 5
        }

        let blinkPulse = (sin(phase * 1.9) + 1) / 2
        let hoverAdjustment: CGFloat = isHovering ? 1.2 : 0
        let sleepyAdjustment: CGFloat = viewModel.unreadThreadCount == 0 ? eventEnvelope(phase, speed: 0.42, threshold: 0.8) * 3.8 : 0
        switch appearanceStore.selectedExpression {
        case .calm:
            return blinkPulse > 0.987 ? 3.2 : max(5.5, 11 - hoverAdjustment - sleepyAdjustment)
        case .happy:
            return blinkPulse > 0.985 ? 2.3 : max(4.5, 8.5 - hoverAdjustment - sleepyAdjustment)
        case .cheeky:
            return blinkPulse > 0.985 ? 2.4 : max(5.2, 10 - hoverAdjustment - sleepyAdjustment)
        }
    }

    private func eventEnvelope(_ phase: TimeInterval, speed: Double, threshold: Double) -> CGFloat {
        let pulse = (sin(phase * speed) + 1) / 2
        guard pulse > threshold else {
            return 0
        }
        return CGFloat((pulse - threshold) / (1 - threshold))
    }

    @ViewBuilder
    private func mascotBody(
        blinkHeight: CGFloat,
        palette: PetPaletteStyle,
        pawLift: CGFloat,
        dozeLevel: CGFloat,
        alertLevel: CGFloat,
        workingLevel: CGFloat,
        phase: TimeInterval
    ) -> some View {
        switch appearanceStore.selectedCharacter {
        case .cat:
            catBody(blinkHeight: blinkHeight, palette: palette, pawLift: pawLift, dozeLevel: dozeLevel, workingLevel: workingLevel, phase: phase)
        case .bear:
            bearBody(blinkHeight: blinkHeight, palette: palette, pawLift: pawLift, dozeLevel: dozeLevel, workingLevel: workingLevel, phase: phase)
        case .fox:
            foxBody(blinkHeight: blinkHeight, palette: palette, pawLift: pawLift, alertLevel: alertLevel, workingLevel: workingLevel, phase: phase)
        }
    }

    @ViewBuilder
    private func bodyShell(palette: PetPaletteStyle) -> some View {
        switch appearanceStore.selectedCharacter {
        case .cat:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.bodyTop, palette.bodyBottom],
                        startPoint: .topLeading,
                        endPoint: .bottom
                    )
                )
                .frame(width: 80, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                )
        case .bear:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.bodyTop, palette.bodyBottom],
                        startPoint: .topLeading,
                        endPoint: .bottom
                    )
                )
                .frame(width: 82, height: 72)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                )
        case .fox:
            FoxBodyShape()
                .fill(
                    LinearGradient(
                        colors: [palette.bodyTop, palette.bodyBottom],
                        startPoint: .topLeading,
                        endPoint: .bottom
                    )
                )
                .frame(width: 84, height: 72)
                .overlay(
                    FoxBodyShape()
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                        .frame(width: 84, height: 72)
                )
        }
    }

    private var foreheadHighlight: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.14))
            .frame(width: 54, height: 18)
            .offset(y: -20.5)
    }

    @ViewBuilder
    private func earStack(earTilt: Angle, earLift: CGFloat, palette: PetPaletteStyle) -> some View {
        switch appearanceStore.selectedCharacter {
        case .cat:
            HStack(spacing: 42) {
                EarView(fill: palette.accent, innerFill: palette.earInner, character: .cat)
                    .rotationEffect(earTilt, anchor: .bottom)
                    .offset(y: earLift)
                EarView(fill: palette.accent, innerFill: palette.earInner, character: .cat)
                    .rotationEffect(.degrees(-earTilt.degrees), anchor: .bottom)
                    .offset(y: -earLift * 0.65)
            }
        case .bear:
            HStack(spacing: 44) {
                BearEarView(fill: palette.accent, innerFill: palette.earInner)
                    .rotationEffect(.degrees(earTilt.degrees * 0.4), anchor: .bottom)
                    .offset(y: earLift * 0.5)
                BearEarView(fill: palette.accent, innerFill: palette.earInner)
                    .rotationEffect(.degrees(-earTilt.degrees * 0.4), anchor: .bottom)
                    .offset(y: -earLift * 0.35)
            }
        case .fox:
            HStack(spacing: 42) {
                EarView(fill: palette.accent, innerFill: palette.earInner, character: .fox)
                    .rotationEffect(.degrees(earTilt.degrees * 1.2), anchor: .bottom)
                    .offset(y: earLift)
                EarView(fill: palette.accent, innerFill: palette.earInner, character: .fox)
                    .rotationEffect(.degrees(-earTilt.degrees * 1.2), anchor: .bottom)
                    .offset(y: -earLift * 0.7)
            }
        }
    }

    @ViewBuilder
    private func tailView(rotation: Angle, palette: PetPaletteStyle) -> some View {
        switch appearanceStore.selectedCharacter {
        case .cat:
            TailView()
                .fill(palette.accent)
                .frame(width: 28, height: 44)
                .rotationEffect(rotation, anchor: .bottom)
                .offset(x: 42, y: 6)
                .overlay {
                    TailView()
                        .stroke(Color.white.opacity(0.26), lineWidth: 1)
                        .frame(width: 26, height: 40)
                        .rotationEffect(rotation, anchor: .bottom)
                        .offset(x: 41, y: 5)
                }
        case .bear:
            Circle()
                .fill(palette.accent.opacity(0.92))
                .frame(width: 18, height: 18)
                .offset(x: 34, y: 24)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                        .frame(width: 16, height: 16)
                        .offset(x: 34, y: 24)
                }
        case .fox:
            FoxTailView()
                .fill(palette.accent)
                .frame(width: 30, height: 48)
                .rotationEffect(rotation, anchor: .bottom)
                .offset(x: 42, y: 8)
                .overlay {
                    FoxTailTipView()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 13, height: 16)
                        .rotationEffect(rotation, anchor: .bottom)
                        .offset(x: 52, y: 20)
                }
        }
    }

    @ViewBuilder
    private func faceView(blinkHeight: CGFloat, palette: PetPaletteStyle) -> some View {
        let isCheeky = appearanceStore.selectedExpression == .cheeky
        HStack(spacing: 20) {
            EyeView(
                expression: isCheeky ? .cheeky : appearanceStore.selectedExpression,
                isCelebrating: viewModel.isCelebrating,
                height: blinkHeight
            )
            EyeView(
                expression: appearanceStore.selectedExpression == .cheeky ? .calm : appearanceStore.selectedExpression,
                isCelebrating: viewModel.isCelebrating,
                height: appearanceStore.selectedExpression == .cheeky ? 9.5 : blinkHeight
            )
        }
        .offset(y: -8)

        HStack(spacing: 36) {
            Ellipse()
                .fill(palette.cheek.opacity(0.95))
                .frame(width: 11, height: 8)
            Ellipse()
                .fill(palette.cheek.opacity(0.95))
                .frame(width: 11, height: 8)
        }
        .offset(y: 2)
    }

    private func catBody(
        blinkHeight: CGFloat,
        palette: PetPaletteStyle,
        pawLift: CGFloat,
        dozeLevel: CGFloat,
        workingLevel: CGFloat,
        phase: TimeInterval
    ) -> some View {
        ZStack {
            bodyShell(palette: palette)
            foreheadHighlight
            faceView(blinkHeight: blinkHeight, palette: palette)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(red: 0.16, green: 0.18, blue: 0.24))
                .frame(width: 42, height: 26)
                .offset(y: 18)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        .frame(width: 34, height: 18)
                        .offset(y: 18)
                }
                .overlay {
                    if workingLevel > 0.2 {
                        WorkingScreenGlow(phase: phase, opacity: workingLevel)
                            .frame(width: 30, height: 12)
                            .offset(y: 18)
                    }
                }

            SmileView(expression: appearanceStore.selectedExpression)
                .stroke(Color.white.opacity(0.42), lineWidth: 1.6)
                .frame(width: 18, height: 8)
                .offset(y: 23)

            HStack(spacing: 0) {
                PawView(fill: palette.paw)
                PawView(fill: palette.paw)
                    .offset(y: -pawLift)
            }
            .offset(y: 42)

            if dozeLevel > 0.18 {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 26, height: 8)
                    .offset(y: 15)
            }
        }
    }

    private func bearBody(
        blinkHeight: CGFloat,
        palette: PetPaletteStyle,
        pawLift: CGFloat,
        dozeLevel: CGFloat,
        workingLevel: CGFloat,
        phase: TimeInterval
    ) -> some View {
        ZStack {
            bodyShell(palette: palette)

            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 48, height: 18)
                .offset(y: -20)

            HStack(spacing: 18) {
                EyeView(
                    expression: appearanceStore.selectedExpression == .cheeky ? .cheeky : .calm,
                    isCelebrating: viewModel.isCelebrating,
                    height: blinkHeight * 0.9
                )
                EyeView(
                    expression: appearanceStore.selectedExpression == .happy ? .happy : .calm,
                    isCelebrating: viewModel.isCelebrating,
                    height: blinkHeight * 0.9
                )
            }
            .offset(y: -9)

            HStack(spacing: 34) {
                Ellipse()
                    .fill(palette.cheek.opacity(0.92))
                    .frame(width: 10, height: 8)
                Ellipse()
                    .fill(palette.cheek.opacity(0.92))
                    .frame(width: 10, height: 8)
            }
            .offset(y: 1)

            BearMuzzleShape()
                .fill(Color(red: 0.99, green: 0.92, blue: 0.86))
                .frame(width: 38, height: 26)
                .offset(y: 16)

            Circle()
                .fill(Color(red: 0.16, green: 0.18, blue: 0.24))
                .frame(width: 10, height: 8)
                .offset(y: 11)

            SmileView(expression: appearanceStore.selectedExpression)
                .stroke(Color(red: 0.16, green: 0.18, blue: 0.24).opacity(0.44), lineWidth: 1.4)
                .frame(width: 14, height: 7)
                .offset(y: 20)

            HStack(spacing: 28) {
                BearArmView(fill: palette.bodyBottom.opacity(0.98))
                BearArmView(fill: palette.bodyBottom.opacity(0.98))
                    .offset(y: -pawLift * 0.7 - workingLevel * 5)
            }
            .offset(y: 12)

            if workingLevel > 0.2 {
                WorkingSparkBar(phase: phase, opacity: workingLevel)
                    .offset(y: 23)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(red: 0.14, green: 0.17, blue: 0.24).opacity(0.92))
                    .frame(width: 34, height: 16)
                    .offset(y: 28)
                    .overlay {
                        WorkingScreenGlow(phase: phase, opacity: workingLevel)
                            .frame(width: 24, height: 8)
                            .offset(y: 28)
                    }
            }

            HStack(spacing: 18) {
                PawView(fill: palette.paw)
                PawView(fill: palette.paw)
            }
            .offset(y: 41)

            if dozeLevel > 0.18 {
                BearSnoutNose()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 18, height: 6)
                    .offset(y: 20)
            }
        }
    }

    private func foxBody(
        blinkHeight: CGFloat,
        palette: PetPaletteStyle,
        pawLift: CGFloat,
        alertLevel: CGFloat,
        workingLevel: CGFloat,
        phase: TimeInterval
    ) -> some View {
        ZStack {
            bodyShell(palette: palette)

            FoxChestShape()
                .fill(Color.white.opacity(0.2))
                .frame(width: 34, height: 20)
                .offset(y: -19)

            HStack(spacing: 22) {
                EyeView(
                    expression: appearanceStore.selectedExpression == .happy ? .happy : .calm,
                    isCelebrating: viewModel.isCelebrating,
                    height: blinkHeight * 0.9
                )
                EyeView(
                    expression: appearanceStore.selectedExpression == .cheeky ? .cheeky : .calm,
                    isCelebrating: viewModel.isCelebrating,
                    height: appearanceStore.selectedExpression == .cheeky ? 8.5 : blinkHeight * 0.9
                )
            }
            .offset(y: -10)

            HStack(spacing: 34) {
                Ellipse()
                    .fill(palette.cheek.opacity(0.92))
                    .frame(width: 9, height: 7)
                Ellipse()
                    .fill(palette.cheek.opacity(0.92))
                    .frame(width: 9, height: 7)
            }
            .offset(y: 0)

            FoxMuzzleShape()
                .fill(Color(red: 0.15, green: 0.17, blue: 0.23))
                .frame(width: 32, height: 28)
                .offset(y: 17)
                .overlay {
                    FoxMuzzleShape()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        .frame(width: 26, height: 22)
                        .offset(y: 17)
                }
                .overlay {
                    if workingLevel > 0.2 {
                        WorkingScreenGlow(phase: phase + 0.3, opacity: workingLevel)
                            .frame(width: 22, height: 10)
                            .offset(y: 17)
                    }
                }

            SmileView(expression: appearanceStore.selectedExpression)
                .stroke(Color.white.opacity(0.42), lineWidth: 1.5)
                .frame(width: 14, height: 7)
                .offset(y: 23)

            HStack(spacing: 22) {
                FoxLegView(fill: palette.paw)
                FoxLegView(fill: palette.paw)
                    .offset(y: -pawLift * 0.5 - alertLevel * 0.8)
            }
            .offset(y: 41)
        }
    }
}

private struct EyeView: View {
    let expression: PetExpression
    let isCelebrating: Bool
    let height: CGFloat

    var body: some View {
        Group {
            switch expression {
            case .happy:
                HappyEyeShape()
                    .stroke(Color.black.opacity(0.86), lineWidth: 2.2)
                    .frame(width: 9, height: 5)
            case .cheeky:
                WinkEyeShape()
                    .stroke(Color.black.opacity(0.86), lineWidth: 2.1)
                    .frame(width: 8, height: 6)
            case .calm:
                ZStack(alignment: .topTrailing) {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.84))
                        .frame(width: 8, height: height)

                    if !isCelebrating {
                        Circle()
                            .fill(Color.white.opacity(0.95))
                            .frame(width: 2.5, height: 2.5)
                            .offset(x: -1.5, y: 1.5)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.12), value: height)
    }
}

private struct PawView: View {
    let fill: Color

    var body: some View {
        Capsule(style: .continuous)
            .fill(fill)
            .frame(width: 17, height: 11)
            .padding(.horizontal, 4)
    }
}

private struct BearArmView: View {
    let fill: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(fill)
            .frame(width: 12, height: 26)
    }
}

private struct FoxLegView: View {
    let fill: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fill)
            .frame(width: 12, height: 15)
            .overlay(alignment: .bottom) {
                Capsule(style: .continuous)
                    .fill(fill.opacity(0.92))
                    .frame(width: 14, height: 8)
                    .offset(y: 3)
            }
    }
}

private struct SleepAccent: View {
    let opacity: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: -2) {
            Text("z")
                .font(.system(size: 10, weight: .bold))
            Text("z")
                .font(.system(size: 8, weight: .semibold))
                .offset(x: 8)
        }
        .foregroundStyle(Color.black.opacity(0.42))
        .opacity(opacity)
    }
}

private struct AlertAccent: View {
    let opacity: CGFloat

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.46))
            .opacity(opacity)
    }
}

private struct WorkingAccent: View {
    let phase: TimeInterval
    let opacity: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.black.opacity(0.58))
                    .frame(width: 5, height: 5)
                    .scaleEffect(0.78 + CGFloat((sin(phase * 7 + Double(index) * 0.9) + 1) / 2) * 0.9)
            }
        }
        .opacity(opacity)
    }
}

private struct WorkingHalo: View {
    let phase: TimeInterval
    let color: Color
    let opacity: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18 * opacity), lineWidth: 10)
                .scaleEffect(0.9 + CGFloat((sin(phase * 3.8) + 1) / 2) * 0.08)

            Circle()
                .trim(from: 0.08, to: 0.68)
                .stroke(
                    AngularGradient(
                        colors: [
                            color.opacity(0.15),
                            color.opacity(0.9),
                            color.opacity(0.15)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(phase * 110))
        }
        .opacity(opacity)
    }
}

private struct WorkingTrail: View {
    let phase: TimeInterval
    let color: Color
    let opacity: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color.opacity(0.85))
                    .frame(width: 5, height: 5)
                    .offset(
                        x: CGFloat(cos(phase * 2.6 + Double(index) * 2.1)) * 58,
                        y: CGFloat(sin(phase * 2.6 + Double(index) * 2.1)) * 18 - 6
                    )
            }
        }
        .opacity(opacity * 0.9)
    }
}

private struct WorkingScreenGlow: View {
    let phase: TimeInterval
    let opacity: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(red: 0.42, green: 0.95, blue: 0.66).opacity(0.72))
                .frame(width: 18 + CGFloat(sin(phase * 9)) * 4, height: 2.5)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.6))
                .frame(width: 12 + CGFloat(cos(phase * 8)) * 3, height: 2)
        }
        .opacity(opacity)
    }
}

private struct WorkingSparkBar: View {
    let phase: TimeInterval
    let opacity: CGFloat

    var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.68))
                .frame(width: 12 + CGFloat(sin(phase * 7.2)) * 4, height: 3)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(red: 0.40, green: 0.95, blue: 0.65).opacity(0.7))
                .frame(width: 8 + CGFloat(cos(phase * 7.8)) * 3, height: 3)
        }
        .opacity(opacity)
    }
}

private struct EarView: View {
    let fill: Color
    let innerFill: Color
    let character: PetCharacter

    var body: some View {
        Triangle()
            .fill(fill)
            .frame(width: character == .fox ? 21 : 19, height: character == .fox ? 26 : 23)
            .overlay(alignment: .bottom) {
                Triangle()
                    .fill(innerFill)
                    .frame(width: character == .fox ? 11 : 10, height: character == .fox ? 14 : 11)
                    .offset(y: -2)
            }
    }
}

private struct BearEarView: View {
    let fill: Color
    let innerFill: Color

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: 18, height: 18)
            .overlay {
                Circle()
                    .fill(innerFill)
                    .frame(width: 9, height: 9)
                    .offset(y: 1)
            }
    }
}

private struct CounterBadge: View {
    let count: Int
    let fill: Color

    var body: some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(fill)
            )
    }
}

private struct StatusChip: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(accent)
                .frame(width: 4, height: 4)
            Text(title)
                .font(.system(size: 8, weight: .bold))
            Text(value)
                .font(.system(size: 8, weight: .semibold))
        }
        .foregroundStyle(Color.black.opacity(0.65))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule(style: .continuous)
                .fill(accent.opacity(0.16))
        )
    }
}

private struct SparkleView: View {
    let index: Int
    let phase: TimeInterval
    let sparkleColor: Color

    var body: some View {
        let angle = Double(index) / 6.0 * Double.pi * 2
        let radius = 62 + sin(phase * 4 + Double(index)) * 8
        let x = cos(angle) * radius
        let y = sin(angle) * radius - 18

        return Circle()
            .fill(index.isMultiple(of: 2) ? Color.white : sparkleColor)
            .frame(width: 8, height: 8)
            .offset(x: x, y: y)
            .blur(radius: 0.2)
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + 3, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TailView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2),
            control1: CGPoint(x: rect.minX + rect.width * 0.55, y: rect.maxY * 0.72),
            control2: CGPoint(x: rect.maxX, y: rect.midY)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.54, y: rect.maxY),
            control1: CGPoint(x: rect.maxX - 2, y: rect.maxY * 0.55),
            control2: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.maxY - 2)
        )
        path.closeSubpath()
        return path
    }
}

private struct FoxTailView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY * 0.5),
            control1: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.height * 0.78),
            control2: CGPoint(x: rect.maxX, y: rect.height * 0.58)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.52, y: rect.maxY),
            control1: CGPoint(x: rect.maxX - 1, y: rect.height * 0.72),
            control2: CGPoint(x: rect.width * 0.84, y: rect.maxY - 2)
        )
        path.closeSubpath()
        return path
    }
}

private struct FoxTailTipView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2),
            control1: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY * 0.52),
            control2: CGPoint(x: rect.maxX * 0.96, y: rect.midY)
        )
        path.addLine(to: CGPoint(x: rect.maxX * 0.42, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct FoxBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + 6))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY + 6),
            control: CGPoint(x: rect.midX, y: rect.minY - 6)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - 7, y: rect.maxY - 10),
            control1: CGPoint(x: rect.maxX + 1, y: rect.midY - 4),
            control2: CGPoint(x: rect.maxX, y: rect.maxY - 18)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX - 18, y: rect.maxY + 2)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 7, y: rect.maxY - 10),
            control: CGPoint(x: rect.minX + 18, y: rect.maxY + 2)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + 6),
            control1: CGPoint(x: rect.minX, y: rect.maxY - 18),
            control2: CGPoint(x: rect.minX - 1, y: rect.midY - 4)
        )
        path.closeSubpath()
        return path
    }
}

private struct BearMuzzleShape: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: rect.height * 0.45, style: .continuous).path(in: rect)
    }
}

private struct BearSnoutNose: Shape {
    func path(in rect: CGRect) -> Path {
        Capsule(style: .continuous).path(in: rect)
    }
}

private struct FoxMuzzleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.38),
            control: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + 2)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX - 1, y: rect.maxY - rect.height * 0.18)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.38),
            control: CGPoint(x: rect.minX + 1, y: rect.maxY - rect.height * 0.18)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + 2)
        )
        path.closeSubpath()
        return path
    }
}

private struct FoxChestShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2),
            control: CGPoint(x: rect.maxX - 2, y: rect.maxY * 0.65)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.2),
            control: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.minX + 2, y: rect.maxY * 0.65)
        )
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct SmileView: Shape {
    let expression: PetExpression

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch expression {
        case .calm:
            path.move(to: CGPoint(x: rect.minX + 2, y: rect.midY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - 2, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.maxY - 1)
            )
        case .happy:
            path.move(to: CGPoint(x: rect.minX + 1, y: rect.midY - 1))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - 1, y: rect.midY - 1),
                control: CGPoint(x: rect.midX, y: rect.maxY + 3)
            )
        case .cheeky:
            path.move(to: CGPoint(x: rect.minX + 1, y: rect.midY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - 3, y: rect.midY - 1),
                control: CGPoint(x: rect.midX - 1, y: rect.maxY + 1)
            )
        }
        return path
    }
}

private struct HappyEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 0.5, y: rect.maxY - 1))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 0.5, y: rect.maxY - 1),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return path
    }
}

private struct WinkEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 0.5, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - 0.5, y: rect.midY - 1))
        return path
    }
}

private struct HeartAccent: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.18)
        path.move(to: top)
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.maxY * 0.7)
        )
        path.addCurve(
            to: top,
            control1: CGPoint(x: rect.minX, y: rect.maxY * 0.7),
            control2: CGPoint(x: rect.minX, y: rect.minY)
        )
        return path
    }
}
