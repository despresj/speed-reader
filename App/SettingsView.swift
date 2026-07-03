import SwiftUI

/// A quiet gear pinned to the top-left corner that opens the Settings sheet. Shared
/// across the entry and reading surfaces so settings live in one predictable spot.
/// Same surface/hairline family as the other secondary controls.
struct SettingsGear: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.readingMuted)
                .frame(width: 40, height: 40)
                .background(Color.readingSurface.opacity(0.6), in: Circle())
                .overlay(Circle().stroke(Color.readingBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Set-once reading preferences: which hand drives the rail, the speed a fresh read
/// opens at, and whether reading begins hands-free. Same calm ink-and-paper
/// surface as the rest of Skim. Everything here is a *default for new reads* — a
/// loaded read's live speed and hand still move freely; these just set the start.
struct SettingsView: View {
    let viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAI = false

    /// The default starting band, derived from the persisted default WPM.
    private var band: SpeedBand { SpeedBand(wpm: viewModel.defaultWpm) }

    var body: some View {
        ZStack {
            ReadingCanvas()

            VStack(spacing: 0) {
                header
                Divider().overlay(Color.readingBorder)

                ScrollView {
                    VStack(spacing: 26) {
                        handRow
                        speedRow
                        cruiseRow
                        themeRow
                        aiRow
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 22)
                    .padding(.bottom, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
                .sheet(isPresented: $showingAI) {
                    if let service = viewModel.comprehension {
                        AIFeaturesView(service: service, settings: service.settingsForUI)
                    }
                }
            }
        }
        // Keyed on the theme so the sheet's own canvas and rows repaint in the
        // instant a swatch is tapped — the sheet itself lives outside ContentView's
        // theme boundary precisely so it *stays up* through the swap.
        .id(viewModel.theme)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground { ReadingCanvas().id(viewModel.theme) }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Color.readingForeground)
            Spacer()
            Button("Done") { dismiss() }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.readingAccent)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    // MARK: Reading hand

    private var handRow: some View {
        SettingRow(title: "Reading hand",
                   subtitle: "Mirrors the rail, word, and speed dial to your thumb.") {
            HStack(spacing: 4) {
                handSegment(title: "Left", isLeft: true)
                handSegment(title: "Right", isLeft: false)
            }
            .padding(3)
            .background(Color.readingSurface, in: Capsule())
            .overlay(Capsule().stroke(Color.readingBorder, lineWidth: 1))
        }
    }

    private func handSegment(title: String, isLeft: Bool) -> some View {
        let selected = viewModel.isLeftHanded == isLeft
        return Button {
            viewModel.isLeftHanded = isLeft
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Color.readingOnAccent : Color.readingMuted)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background { if selected { Capsule().fill(Color.readingAccent) } }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selected)
    }

    // MARK: Default speed

    private var speedRow: some View {
        SettingRow(title: "Default speed",
                   subtitle: "Where a freshly opened read starts. Slide to change it live.") {
            HStack(spacing: 14) {
                stepButton(systemName: "minus", enabled: band.wpm > SpeedBand.minWPM) {
                    viewModel.defaultWpm = band.slower().wpm
                }

                VStack(spacing: 1) {
                    Text(band.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.readingForeground)
                    Text("\(band.wpm) wpm")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.readingMuted)
                }
                .frame(width: 74)

                stepButton(systemName: "plus", enabled: band.wpm < SpeedBand.maxWPM) {
                    viewModel.defaultWpm = band.faster().wpm
                }
            }
        }
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? Color.readingAccent : Color.readingMuted.opacity(0.4))
                .frame(width: 34, height: 34)
                .background(Color.readingSurface, in: Circle())
                .overlay(Circle().stroke(Color.readingBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: Start in cruise

    private var cruiseRow: some View {
        SettingRow(title: "Start in cruise control",
                   subtitle: "Begin streaming hands-free the moment a read opens.") {
            Toggle("", isOn: Binding(
                get: { viewModel.startInCruise },
                set: { viewModel.startInCruise = $0 }
            ))
            .labelsHidden()
            .tint(Color.readingAccent)
        }
    }

    // MARK: Theme

    /// Five tappable swatches — each a disc of its theme's background with the
    /// theme's accent "thread" at its center, the selected one ringed in its own
    /// accent. Applying is instant and app-wide (the surface behind this sheet
    /// repaints live), so there's no preview/confirm step to add weight.
    private var themeRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Theme")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.readingForeground)
                Text("The surface's ink and thread — \(viewModel.theme.displayName).")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.readingMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 16) {
                ForEach(SkimTheme.allCases) { theme in
                    themeSwatch(theme)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func themeSwatch(_ theme: SkimTheme) -> some View {
        let selected = viewModel.theme == theme
        let palette = theme.palette
        let disc = Color(uiColor: ThemePalette.uiColor(palette.background))
        let thread = Color(uiColor: ThemePalette.uiColor(palette.accent))
        return Button {
            viewModel.theme = theme
        } label: {
            ZStack {
                Circle().fill(disc)
                Circle().fill(thread).frame(width: 13, height: 13)
            }
            .frame(width: 36, height: 36)
            .overlay(
                Circle().stroke(selected ? thread : Color.readingBorder,
                                lineWidth: selected ? 2 : 1)
            )
            // A forgiving hit target around the small disc.
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName) theme")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: AI features

    private var aiRow: some View {
        // Pure navigation row — make the whole row the hit target, not the tiny
        // chevron. The other rows keep their own controls; this one just drills in.
        Button { showingAI = true } label: {
            SettingRow(title: "AI features",
                       subtitle: "Optional comprehension checks with your own OpenAI key.") {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.readingMuted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One labelled settings row: a title + quiet subtitle on the left, the control on
/// the right, vertically centered.
private struct SettingRow<Control: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.readingForeground)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.readingMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            control
        }
    }
}
