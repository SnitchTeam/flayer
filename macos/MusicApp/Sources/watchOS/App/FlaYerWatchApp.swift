import SwiftUI

@main
struct FlaYerWatchApp: App {
    @State private var session = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(session)
        }
    }
}

struct WatchContentView: View {
    @Environment(WatchSessionManager.self) var session

    var body: some View {
        TabView {
            NowPlayingView()
            LibraryView()
        }
        .tabViewStyle(.verticalPage)
    }
}
