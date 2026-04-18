import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App icon
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: .white.opacity(0.06), radius: 24)
                    .padding(.bottom, 16)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Text("FlaYer")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 6)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Text(Lang.onboardingSubtitle)
                    .font(.callout)
                    .foregroundStyle(.gray)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Spacer()

                // Feature cards
                VStack(spacing: 12) {
                    featureRow(
                        icon: "folder.fill",
                        color: .blue,
                        title: Lang.onboardingLocalFiles,
                        subtitle: Lang.onboardingLocalFilesDesc
                    )
                    featureRow(
                        icon: "music.note.list",
                        color: .orange,
                        title: Lang.onboardingMetadata,
                        subtitle: Lang.onboardingMetadataDesc
                    )
                    featureRow(
                        icon: "slider.horizontal.3",
                        color: .purple,
                        title: Lang.equalizer,
                        subtitle: Lang.onboardingEQDesc
                    )
                }
                .frame(maxWidth: 400)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)

                Spacer()

                // Continue button
                Button {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        appState.settings.hasCompletedOnboarding = true
                    }
                    appState.saveSettings()
                } label: {
                    Text(Lang.onboardingContinue)
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: 260)
                        .padding(.vertical, 12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
