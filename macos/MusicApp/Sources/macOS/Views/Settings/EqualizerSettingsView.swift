import SwiftUI

struct EqualizerSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showPicker = false

    private var selectedPreset: HeadphonePreset? {
        HeadphonePresetDatabase.find(id: appState.settings.eqPresetId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Lang.equalizer)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            // Enable toggle + headphone
            VStack(spacing: 0) {
                // Toggle
                Button {
                    appState.settings.eqEnabled.toggle()
                    appState.player.setEQEnabled(appState.settings.eqEnabled)
                    appState.saveSettings()
                } label: {
                    HStack {
                        Text(Lang.equalizer)
                            .font(.caption)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(appState.settings.eqEnabled ? Lang.active : Lang.inactive)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().background(Color.white.opacity(0.05))

                // Headphone selection
                Button { showPicker = true } label: {
                    HStack {
                        Text(Lang.headphone)
                            .font(.caption)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(selectedPreset?.name ?? Lang.none)
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .glassCard()

            // EQ Curve
            if let preset = selectedPreset {
                EQCurveView(
                    bands: preset.bands,
                    preamp: preset.preamp,
                    enabled: appState.settings.eqEnabled
                )
                .glassCard()

                // Band parameters
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(Lang.parameters)
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Spacer()
                        Text("\(Lang.preamp): \(String(format: "%+.1f", preset.preamp)) dB")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.gray.opacity(0.6))
                    }

                    VStack(spacing: 0) {
                        ForEach(preset.bands) { band in
                            HStack(spacing: 0) {
                                Text(band.type.rawValue)
                                    .frame(width: 32, alignment: .leading)
                                    .foregroundStyle(bandColor(band.type))
                                Text(formatFrequency(band.frequency))
                                    .frame(width: 64, alignment: .trailing)
                                    .foregroundStyle(.white)
                                Text(String(format: "%+.1f dB", band.gain))
                                    .frame(width: 64, alignment: .trailing)
                                    .foregroundStyle(band.gain >= 0 ? .cyan.opacity(0.8) : .orange.opacity(0.8))
                                Spacer()
                                Text(String(format: "Q %.2f", band.q))
                                    .foregroundStyle(.gray.opacity(0.5))
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)

                            if band.id != preset.bands.last?.id {
                                Divider().background(Color.white.opacity(0.03))
                            }
                        }
                    }
                    .glassCard()
                }
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "headphones")
                        .font(.system(size: 24))
                        .foregroundStyle(.gray.opacity(0.3))
                    Text(Lang.selectHeadphone)
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .glassCard()
            }
        }
        .sheet(isPresented: $showPicker) {
            HeadphonePickerView { preset in
                appState.settings.eqPresetId = preset.id
                appState.player.applyEQPreset(preset)
                if appState.settings.eqEnabled {
                    appState.player.setEQEnabled(true)
                }
                appState.saveSettings()
            }
        }
    }

    private func bandColor(_ type: EQBand.FilterType) -> Color {
        switch type {
        case .peak: return .white.opacity(0.6)
        case .lowShelf: return .cyan.opacity(0.7)
        case .highShelf: return .purple.opacity(0.7)
        }
    }

    private func formatFrequency(_ freq: Double) -> String {
        if freq >= 1000 {
            let khz = freq / 1000
            if khz == khz.rounded() {
                return "\(Int(khz)) kHz"
            }
            return String(format: "%.1f kHz", khz)
        }
        return "\(Int(freq)) Hz"
    }
}

// MARK: - EQ Curve Visualization

struct EQCurveView: View {
    let bands: [EQBand]
    let preamp: Double
    let enabled: Bool

    private let freqMin = 20.0
    private let freqMax = 20000.0
    private let dbMin = -15.0
    private let dbMax = 15.0
    private let gridFreqs: [Double] = [50, 100, 200, 500, 1000, 2000, 5000, 10000]
    private let gridDBs: [Double] = [-12, -6, 0, 6, 12]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    // Grid
                    Canvas { ctx, _ in
                        for freq in gridFreqs {
                            let x = freqToX(freq, width: w)
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: h))
                            ctx.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 0.5)
                        }
                        for db in gridDBs {
                            let y = dbToY(db, height: h)
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: w, y: y))
                            ctx.stroke(
                                path,
                                with: .color(.white.opacity(db == 0 ? 0.12 : 0.05)),
                                lineWidth: db == 0 ? 1 : 0.5
                            )
                        }
                    }

                    if enabled {
                        // Fill
                        responseFill(width: w, height: h)
                            .fill(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.1), .purple.opacity(0.1)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        // Curve
                        responseCurve(width: w, height: h)
                            .stroke(
                                LinearGradient(
                                    colors: [.cyan, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2
                            )

                        // Band dots
                        ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                            let resp = computeResponse(at: band.frequency)
                            let x = freqToX(band.frequency, width: w)
                            let y = dbToY(resp, height: h)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 5, height: 5)
                                .position(x: x, y: y)
                        }
                    }

                    // dB labels
                    ForEach(gridDBs, id: \.self) { db in
                        let y = dbToY(db, height: h)
                        Text(db == 0 ? "0" : String(format: "%+.0f", db))
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(.gray.opacity(0.35))
                            .position(x: 14, y: y)
                    }
                }
            }
            .frame(height: 160)
            .clipped()

            // Frequency labels
            GeometryReader { geo in
                let w = geo.size.width
                let labels: [(Double, String)] = [
                    (50, "50"), (200, "200"), (1000, "1k"), (5000, "5k"), (10000, "10k"),
                ]
                ForEach(labels, id: \.0) { freq, label in
                    Text(label)
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.35))
                        .position(x: freqToX(freq, width: w), y: 8)
                }
            }
            .frame(height: 16)
        }
    }

    private func freqToX(_ freq: Double, width: Double) -> Double {
        let logMin = log10(freqMin)
        let logMax = log10(freqMax)
        return (log10(freq) - logMin) / (logMax - logMin) * width
    }

    private func dbToY(_ db: Double, height: Double) -> Double {
        let clamped = max(dbMin, min(dbMax, db))
        return height * (1.0 - (clamped - dbMin) / (dbMax - dbMin))
    }

    private func responseCurve(width: Double, height: Double) -> Path {
        Path { path in
            let steps = 300
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let logFreq = log10(freqMin) + t * (log10(freqMax) - log10(freqMin))
                let freq = pow(10, logFreq)
                let db = computeResponse(at: freq)
                let x = t * width
                let y = dbToY(db, height: height)
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
    }

    private func responseFill(width: Double, height: Double) -> Path {
        let zeroY = dbToY(0, height: height)
        var path = responseCurve(width: width, height: height)
        // Close path along the 0 dB line
        path.addLine(to: CGPoint(x: width, y: zeroY))
        path.addLine(to: CGPoint(x: 0, y: zeroY))
        path.closeSubpath()
        return path
    }

    private func computeResponse(at frequency: Double) -> Double {
        var total = preamp
        for band in bands {
            switch band.type {
            case .peak:
                let x = band.q * (frequency / band.frequency - band.frequency / frequency)
                total += band.gain / (1.0 + x * x)
            case .lowShelf:
                let ratio = pow(frequency / band.frequency, 2.0)
                total += band.gain / (1.0 + ratio)
            case .highShelf:
                let ratio = pow(band.frequency / frequency, 2.0)
                total += band.gain / (1.0 + ratio)
            }
        }
        return total
    }
}

// MARK: - Headphone Picker

struct HeadphonePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (HeadphonePreset) -> Void

    @State private var searchText = ""

    private var filtered: [HeadphonePreset] {
        if searchText.isEmpty { return HeadphonePresetDatabase.all }
        let q = searchText.lowercased()
        return HeadphonePresetDatabase.all.filter {
            $0.name.lowercased().contains(q) || $0.brand.lowercased().contains(q)
        }
    }

    private var groupedByBrand: [(brand: String, presets: [HeadphonePreset])] {
        var groups: [String: [HeadphonePreset]] = [:]
        for preset in filtered {
            groups[preset.brand, default: []].append(preset)
        }
        return groups.keys.sorted().map { (brand: $0, presets: groups[$0]!) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(Lang.chooseHeadphone)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                        .padding(6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                TextField(Lang.searchHeadphone, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .padding(8)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedByBrand, id: \.brand) { group in
                        Text(group.brand)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)

                        ForEach(group.presets) { preset in
                            Button {
                                onSelect(preset)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(preset.name)
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                        HStack(spacing: 6) {
                                            Text(preset.type.displayName)
                                                .font(.caption2)
                                                .foregroundStyle(.gray.opacity(0.6))
                                            Text("·")
                                                .foregroundStyle(.gray.opacity(0.3))
                                            Text(Lang.bandsCount(preset.bands.count))
                                                .font(.caption2)
                                                .foregroundStyle(.gray.opacity(0.4))
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .frame(width: 380, height: 460)
        .background(.black.opacity(0.95))
    }
}
