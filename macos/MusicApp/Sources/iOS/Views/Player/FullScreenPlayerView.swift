import SwiftUI
import AVFoundation

struct FullScreenPlayerView: View {
    @Environment(AppState.self) private var appState
    var namespace: Namespace.ID
    var onDismiss: () -> Void

    @State private var isFavorite = false
    @State private var showPlaylistPicker = false
    @State private var dragOffset: CGFloat = 0
    @State private var averageColor: Color = .clear
    @State private var outputIcon: String = "speaker.fill"
    @State private var outputName: String = "iPhone"

    var body: some View {
        let player = appState.player
        if let track = player.currentTrack {
            ZStack {
                // Tinted background from artwork color
                averageColor.opacity(0.15)

                // Frosted glass
                Rectangle()
                    .fill(.ultraThinMaterial)

                // Dark overlay for readability
                Color.black.opacity(0.3)

                VStack(spacing: 0) {
                    // Drag indicator
                    Capsule()
                        .fill(.white.opacity(0.25))
                        .frame(width: 36, height: 4)
                        .padding(.top, 10)

                    // Dismiss button
                    HStack {
                        Button(action: onDismiss) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.dismiss)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()

                    // Cover art
                    CoverArtView(path: track.coverArtPath, size: 280)
                        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
                        .matchedGeometryEffect(id: "playerCover", in: namespace)
                        .frame(maxWidth: .infinity)

                    Spacer().frame(height: 28)

                    // Track info
                    VStack(spacing: 5) {
                        MarqueeText(text: track.title, font: .system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)

                        Button {
                            if let artistId = track.artistId,
                               let artist = appState.db.getArtist(id: artistId) {
                                onDismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    appState.modalArtist = artist
                                }
                            }
                        } label: {
                            Text(track.artist)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)

                        Button {
                            if let albumId = track.albumId,
                               let album = appState.db.getAlbum(id: albumId) {
                                onDismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    appState.modalAlbum = album
                                }
                            }
                        } label: {
                            Text(track.album)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.35))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)

                    Spacer().frame(height: 24)

                    // Progress bar
                    VStack(spacing: 6) {
                        ProgressBarView(
                            progress: player.duration > 0 ? player.position / player.duration : 0,
                            onSeek: { ratio in
                                player.seek(to: ratio * player.duration)
                            }
                        )
                        .frame(height: 14)

                        HStack {
                            Text(player.position.formattedDuration)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.35))
                            Spacer()
                            Text(player.duration.formattedDuration)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 22)

                    // Transport controls
                    HStack(spacing: 28) {
                        Button(action: { player.toggleShuffle() }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 15))
                                .foregroundStyle(player.shuffle ? .white : .white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.shuffle)

                        Button(action: { player.previous() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.previous)

                        Button(action: { player.togglePlayPause() }) {
                            Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.playPause)

                        Button(action: { player.next() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.next)

                        Button(action: { player.stop() }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.stop)
                    }
                    .frame(maxWidth: .infinity)

                    Spacer().frame(height: 16)

                    // Audio info (EQ + output)
                    HStack(spacing: 8) {
                        Button(action: toggleEQ) {
                            Text("EQ")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(appState.settings.eqEnabled ? .white : .white.opacity(0.3))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(appState.settings.eqEnabled ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(appState.settings.eqEnabled ? Color.white.opacity(0.2) : .clear, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)

                        if appState.settings.eqEnabled, let preset = HeadphonePresetDatabase.find(id: appState.settings.eqPresetId) {
                            Text(preset.name)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.25))
                                .lineLimit(1)
                        }

                        Spacer()

                        HStack(spacing: 5) {
                            Image(systemName: outputIcon)
                                .font(.system(size: 10))
                            Text(outputName)
                                .font(.system(size: 10))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 12)

                    // Bottom actions
                    HStack(spacing: 20) {
                        Button(action: { toggleFavorite(track) }) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 18))
                                .foregroundStyle(isFavorite ? .pink : .white.opacity(0.35))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isFavorite ? Lang.removeFavorite : Lang.addFavorite)

                        Button(action: { showPlaylistPicker = true }) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Lang.addToPlaylist)

                        Spacer()

                        FormatBadge(format: track.format)

                        Text(trackBitrate(track))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 16)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            // Rubber-band: diminishing offset
                            let raw = value.translation.height
                            dragOffset = 400 * (1 - exp(-raw / 400))
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 || value.predictedEndTranslation.height > 300 {
                            onDismiss()
                        }
                        withAnimation(.spring(duration: 0.4, bounce: 0.15)) { dragOffset = 0 }
                    }
            )
            .onAppear {
                checkFavorite(track)
                extractColor(from: track.coverArtPath)
                updateAudioOutput()
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
                updateAudioOutput()
            }
            .onChange(of: player.currentTrack) { _, newTrack in
                if let t = newTrack {
                    checkFavorite(t)
                    extractColor(from: t.coverArtPath)
                }
            }
            .sheet(isPresented: $showPlaylistPicker) {
                PlaylistPickerView(track: track)
            }
        }
    }

    private func extractColor(from path: String?) {
        guard let path, let image = UIImage(contentsOfFile: path),
              let cgImage = image.cgImage else {
            averageColor = .gray
            return
        }
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        defer { UIGraphicsEndImageContext() }
        UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
        guard let ctx = UIGraphicsGetCurrentContext(),
              let data = ctx.makeImage()?.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            averageColor = .gray
            return
        }
        let r = Double(ptr[0]) / 255.0
        let g = Double(ptr[1]) / 255.0
        let b = Double(ptr[2]) / 255.0
        averageColor = Color(red: r, green: g, blue: b)
    }

    private func checkFavorite(_ track: Track) {
        guard let trackId = track.id,
              let favId = appState.db.getOrCreateFavorites().id else { return }
        isFavorite = appState.db.isTrackInPlaylist(playlistId: favId, trackId: trackId)
    }

    private func toggleFavorite(_ track: Track) {
        guard let trackId = track.id,
              let favId = appState.db.getOrCreateFavorites().id else { return }
        if isFavorite {
            appState.db.removeTrackFromPlaylist(playlistId: favId, trackId: trackId)
        } else {
            appState.db.addTrackToPlaylist(playlistId: favId, trackId: trackId)
        }
        isFavorite.toggle()
    }

    private func toggleEQ() {
        appState.settings.eqEnabled.toggle()
        appState.player.setEQEnabled(appState.settings.eqEnabled)
        appState.saveSettings()
    }

    private func updateAudioOutput() {
        let route = AVAudioSession.sharedInstance().currentRoute
        guard let output = route.outputs.first else {
            outputIcon = "speaker.fill"
            outputName = "iPhone"
            return
        }
        switch output.portType {
        case .builtInSpeaker:
            outputIcon = "speaker.fill"
            outputName = "iPhone"
        case .headphones:
            outputIcon = "headphones"
            outputName = output.portName
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            outputIcon = "headphones"
            outputName = output.portName
        case .usbAudio:
            outputIcon = "hifispeaker"
            outputName = output.portName
        case .airPlay:
            outputIcon = "airplayaudio"
            outputName = output.portName
        case .lineOut:
            outputIcon = "hifispeaker"
            outputName = output.portName
        case .carAudio:
            outputIcon = "car.fill"
            outputName = output.portName
        default:
            outputIcon = "speaker.wave.2"
            outputName = output.portName
        }
    }

    private func trackBitrate(_ track: Track) -> String {
        guard track.duration > 0 else { return "" }
        let kbps = Int(Double(track.fileSize) * 8.0 / track.duration / 1000.0)
        if kbps >= 1000 {
            return String(format: "%.1f Mbps", Double(kbps) / 1000.0)
        }
        return "\(kbps) kbps"
    }
}
