import SwiftUI

@main
struct FlaYerApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let error = appState.initError {
                    InitErrorView(message: error) {
                        appState.initialize()
                    } onReset: {
                        appState.resetDatabaseAndRetry()
                    }
                } else if appState.isInitialized {
                    if appState.settings.hasCompletedOnboarding {
                        ContentView()
                            .transition(.opacity)
                    } else {
                        OnboardingView()
                            .transition(.opacity)
                    }
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
            .environment(appState)
            .preferredColorScheme(.dark)
            .onAppear {
                appState.initialize()
            }
            .task {
                while !appState.isInitialized {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                let _ = appState.restoreBookmarkedFolders()
                if !appState.settings.musicFolders.isEmpty {
                    await appState.scanLibrary()
                }
            }
            .task {
                // Poll widget commands every 0.5s
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if appState.isInitialized {
                        appState.checkWidgetCommands()
                        appState.watchService?.syncNowPlaying()
                    }
                }
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active && appState.isInitialized {
                    appState.checkWidgetCommands()
                }
            }
        }
    }
}

private struct InitErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onReset: () -> Void
    @State private var confirmingReset = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
                Text("FlaYer couldn't start")
                    .font(.title2).bold()
                    .foregroundStyle(.white)
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .textSelection(.enabled)
                    .padding(.horizontal, 24)
                VStack(spacing: 12) {
                    Button(action: onRetry) {
                        Text("Try Again")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.15))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Button(role: .destructive) {
                        confirmingReset = true
                    } label: {
                        Text("Reset Library Database")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.red.opacity(0.25))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
        }
        .confirmationDialog(
            "Reset the library database? Your music files are safe but you'll need to rescan folders.",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive, action: onReset)
            Button("Cancel", role: .cancel) {}
        }
    }
}
