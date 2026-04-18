import SwiftUI

@main
struct FlaYerApp: App {
    @State private var appState = AppState()
    @State private var keyMonitor = KeyboardShortcutMonitor()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isInitialized {
                    if appState.settings.hasCompletedOnboarding {
                        ContentView()
                            .transition(.opacity)
                    } else {
                        OnboardingView()
                            .transition(.opacity)
                    }
                } else {
                    Color.black
                }
            }
            .environment(appState)
            .frame(minWidth: 900, minHeight: 650)
            .background(.black)
            .onAppear {
                appState.initialize()
                keyMonitor.attach(player: appState.player)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                appState.player.cleanupBeforeQuit()
            }
            .task {
                while !appState.isInitialized {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                if !appState.settings.musicFolders.isEmpty {
                    await appState.scanLibrary()
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandMenu(Lang.playback) {
                Button(Lang.playPause) {
                    appState.player.togglePlayPause()
                }

                Button(Lang.next) {
                    appState.player.next()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button(Lang.previous) {
                    appState.player.previous()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                Button(Lang.volumeUp) {
                    appState.player.setVolume(appState.player.volume + 0.05)
                }
                .keyboardShortcut(.upArrow, modifiers: .command)

                Button(Lang.volumeDown) {
                    appState.player.setVolume(appState.player.volume - 0.05)
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
            }
        }
    }
}
