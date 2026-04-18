import SwiftUI

struct NotConnectedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(Lang.notConnected)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(Lang.openIPhone)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
